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
        let symbol = !tap.isActive ? "computermouse.fill" : (ModeStore.shouldFlip() ? "arrow.up.arrow.down.circle.fill" : "computermouse")
        statusItem?.button?.image = NSImage(systemSymbolName: symbol, accessibilityDescription: "Scroll Flip")
    }

    @objc private func pickMode(_ sender: NSMenuItem) {
        if let mode = sender.representedObject as? String { ModeStore.write(mode) }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
