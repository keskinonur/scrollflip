import AppKit
import AppIntents
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let tap = ScrollTap()
    private lazy var model = AppModel(tap: tap)
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupPopover()
        model.onStatusChange = { [weak self] in self?.refreshStatusItem() }
        model.start()
        ScrollFlipShortcuts.updateAppShortcutParameters()

        if !model.accessibilityGranted {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.showPopover()
            }
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        model.stop()
    }

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        guard let button = statusItem.button else { return }
        button.target = self
        button.action = #selector(togglePopover)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.toolTip = "ScrollFlip"
        refreshStatusItem()
    }

    private func setupPopover() {
        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = NSSize(width: 336, height: 300)
        popover.contentViewController = NSHostingController(
            rootView: ControlPanelView(model: model)
        )
    }

    @objc private func togglePopover() {
        popover.isShown ? popover.performClose(nil) : showPopover()
    }

    private func showPopover() {
        guard let button = statusItem.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
    }

    private func refreshStatusItem() {
        guard let button = statusItem?.button else { return }
        button.image = statusGlyph(
            active: model.accessibilityGranted && model.engineIsActive,
            flipping: model.isFlipping
        )
        button.setAccessibilityLabel("ScrollFlip")
        button.setAccessibilityValue(model.headline)
        button.toolTip = "ScrollFlip — \(model.headline)"
    }

    // A compact template glyph stays legible in every menu-bar appearance.
    // The chevrons become heavier only while wheel events are being reversed.
    private func statusGlyph(active: Bool, flipping: Bool) -> NSImage {
        let size: CGFloat = 18
        let image = NSImage(size: NSSize(width: size, height: size), flipped: false) { _ in
            NSColor.black.setStroke()

            let mouseWidth: CGFloat = 9.5
            let mouseHeight: CGFloat = 13
            let mouseX = (size - mouseWidth) / 2
            let mouseY = (size - mouseHeight) / 2
            let mouse = NSBezierPath(
                roundedRect: NSRect(
                    x: mouseX,
                    y: mouseY,
                    width: mouseWidth,
                    height: mouseHeight
                ),
                xRadius: mouseWidth / 2,
                yRadius: mouseWidth / 2
            )
            mouse.lineWidth = 1.35
            mouse.stroke()

            let centerX = size / 2
            let centerY = mouseY + mouseHeight * 0.64
            for direction in [CGFloat(1), CGFloat(-1)] {
                let chevron = NSBezierPath()
                chevron.move(to: NSPoint(x: centerX - 2, y: centerY + direction * 0.6))
                chevron.line(to: NSPoint(x: centerX, y: centerY + direction * 2.3))
                chevron.line(to: NSPoint(x: centerX + 2, y: centerY + direction * 0.6))
                chevron.lineWidth = flipping ? 1.7 : 1.15
                chevron.lineCapStyle = .round
                chevron.lineJoinStyle = .round
                chevron.stroke()
            }

            if !active {
                let slash = NSBezierPath()
                slash.move(to: NSPoint(x: mouseX - 1, y: mouseY - 1))
                slash.line(to: NSPoint(x: mouseX + mouseWidth + 1, y: mouseY + mouseHeight + 1))
                slash.lineWidth = 1.4
                slash.lineCapStyle = .round
                slash.stroke()
            }
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = model.headline
        return image
    }
}
