import AppKit
import ApplicationServices
import AppIntents

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let tap = ScrollTap()
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        startTapOrPromptForAccessibility()

        Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            self?.tap.flip = ModeStore.shouldFlip()
            self?.refreshMenu()
        }
        NotificationCenter.default.addObserver(self, selector: #selector(modeChanged),
            name: .scrollFlipModeChanged, object: nil)

        // Make the Siri phrase and Shortcuts entry available right away.
        ScrollFlipShortcuts.updateAppShortcutParameters()
    }

    private func startTapOrPromptForAccessibility() {
        if tap.start() {
            tap.flip = ModeStore.shouldFlip()
            return
        }
        // Not trusted yet: ask the system to prompt, then retry until granted.
        // ponytail: literal key avoids the CFString import dance for one constant.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] t in
            guard let self = self else { t.invalidate(); return }
            if self.tap.start() {
                self.tap.flip = ModeStore.shouldFlip()
                self.refreshMenu()
                t.invalidate()
            }
        }
    }

    @objc private func modeChanged() {
        tap.flip = ModeStore.shouldFlip()
        refreshMenu()
    }

    // MARK: - Menu bar

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        let menu = NSMenu()
        menu.addItem(modeItem("Auto (only when lid closed)", "auto"))
        menu.addItem(modeItem("On (always reverse)", "on"))
        menu.addItem(modeItem("Off", "off"))
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Scroll Flip", action: #selector(quit), keyEquivalent: "q"))
        statusItem.menu = menu
        refreshMenu()
    }

    private func modeItem(_ title: String, _ mode: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: #selector(pickMode(_:)), keyEquivalent: "")
        item.representedObject = mode
        item.target = self
        return item
    }

    private func refreshMenu() {
        let current = ModeStore.read()
        statusItem?.menu?.items.forEach { item in
            if let mode = item.representedObject as? String {
                item.state = (mode == current) ? .on : .off
            }
        }
        statusItem?.button?.image = statusGlyph(active: tap.isActive, flipping: ModeStore.shouldFlip())
    }

    // Our own menu bar glyph: an outline mouse with the scroll-flip chevrons,
    // matching the app icon's motif. A template image so macOS tints it for the
    // light or dark menu bar. Chevrons thicken while flipping; a slash appears
    // when Accessibility is not granted.
    private func statusGlyph(active: Bool, flipping: Bool) -> NSImage {
        let s: CGFloat = 18
        let image = NSImage(size: NSSize(width: s, height: s), flipped: false) { _ in
            NSColor.black.setStroke()
            let mw: CGFloat = 9.5, mh: CGFloat = 13
            let mx = (s - mw) / 2, my = (s - mh) / 2
            let mouse = NSBezierPath(roundedRect: NSRect(x: mx, y: my, width: mw, height: mh),
                                     xRadius: mw / 2, yRadius: mw / 2)
            mouse.lineWidth = 1.4
            mouse.stroke()

            let cx = s / 2
            let yc = my + mh * 0.64
            let aw: CGFloat = 4, ah: CGFloat = 1.7, gap: CGFloat = 0.6
            for dir in [CGFloat(1), CGFloat(-1)] {            // up chevron, then down
                let p = NSBezierPath()
                p.move(to: NSPoint(x: cx - aw / 2, y: yc + dir * gap))
                p.line(to: NSPoint(x: cx, y: yc + dir * (gap + ah)))
                p.line(to: NSPoint(x: cx + aw / 2, y: yc + dir * gap))
                p.lineWidth = flipping ? 1.7 : 1.2
                p.lineCapStyle = .round
                p.lineJoinStyle = .round
                p.stroke()
            }

            if !active {                                      // Accessibility not granted
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: mx - 1, y: my - 1))
                slash.line(to: NSPoint(x: mx + mw + 1, y: my + mh + 1))
                slash.lineWidth = 1.4
                slash.lineCapStyle = .round
                slash.stroke()
            }
            return true
        }
        image.isTemplate = true
        return image
    }

    @objc private func pickMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? String { ModeStore.write(mode) }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
