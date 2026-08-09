import AppKit
import ApplicationServices
import Combine

@MainActor
final class AppModel: ObservableObject {
    @Published private(set) var mode = ModeStore.read()
    @Published private(set) var lidIsClosed = ModeStore.lidIsClosed()
    @Published private(set) var accessibilityGranted = AXIsProcessTrusted()
    @Published private(set) var engineIsActive = false
    @Published var errorMessage: String?

    var onStatusChange: (() -> Void)?

    private let tap: ScrollTap
    private var timer: Timer?
    private var modeObserver: NSObjectProtocol?

    init(tap: ScrollTap) {
        self.tap = tap
        modeObserver = NotificationCenter.default.addObserver(
            forName: .scrollFlipModeChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    var isFlipping: Bool {
        engineIsActive && ModeStore.shouldFlip(mode: mode, lidClosed: lidIsClosed)
    }

    var headline: String {
        if !accessibilityGranted { return "Permission needed" }
        if !engineIsActive { return "Scroll engine unavailable" }
        switch mode {
        case .auto where lidIsClosed: return "Mouse wheel reversed"
        case .auto: return "Ready when docked"
        case .on: return "Mouse wheel reversed"
        case .off: return "Scroll reversal paused"
        }
    }

    var detail: String {
        if !accessibilityGranted {
            return "Allow Accessibility access so ScrollFlip can adjust wheel events."
        }
        if !engineIsActive {
            return "ScrollFlip couldn’t start its event tap. Try again or reopen the app."
        }
        switch mode {
        case .auto where lidIsClosed:
            return "Your Mac is docked. Trackpad gestures remain natural."
        case .auto:
            return "Your Mac’s lid is open. Trackpad and mouse remain natural."
        case .on:
            return "Wheel mice are reversed. Trackpad gestures remain natural."
        case .off:
            return "Scroll events pass through unchanged."
        }
    }

    func start() {
        requestAccessibilityIfNeeded()
        refresh()
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        tap.stop()
    }

    func setMode(_ newMode: ScrollFlipMode) {
        do {
            try ModeStore.write(newMode)
            mode = newMode
            errorMessage = nil
            refresh()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func retryAccessibility() {
        requestAccessibilityIfNeeded()
        refresh()
    }

    func openAccessibilitySettings() {
        guard let url = URL(
            string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        ) else { return }
        NSWorkspace.shared.open(url)
    }

    func openShortcuts() {
        let url = URL(fileURLWithPath: "/System/Applications/Shortcuts.app")
        let configuration = NSWorkspace.OpenConfiguration()
        NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }

    func dismissError() {
        errorMessage = nil
    }

    private func requestAccessibilityIfNeeded() {
        guard !AXIsProcessTrusted() else { return }
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    private func refresh() {
        let latestMode = ModeStore.read()
        let latestLidState = ModeStore.lidIsClosed()
        let trusted = AXIsProcessTrusted()

        mode = latestMode
        lidIsClosed = latestLidState
        accessibilityGranted = trusted

        if trusted {
            engineIsActive = tap.start()
        } else {
            tap.stop()
            engineIsActive = false
        }

        tap.shouldFlip = ModeStore.shouldFlip(mode: latestMode, lidClosed: latestLidState)
        onStatusChange?()
    }

    deinit {
        timer?.invalidate()
        if let modeObserver {
            NotificationCenter.default.removeObserver(modeObserver)
        }
    }
}
