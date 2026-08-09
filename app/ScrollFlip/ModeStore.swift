import Foundation
import IOKit
import AppIntents

enum ScrollFlipMode: String, CaseIterable, Identifiable, AppEnum {
    case auto
    case on
    case off

    var id: Self { self }

    var title: String {
        switch self {
        case .auto: "Auto"
        case .on: "On"
        case .off: "Off"
        }
    }

    var detail: String {
        switch self {
        case .auto: "When docked"
        case .on: "Always"
        case .off: "Never"
        }
    }

    var symbolName: String {
        switch self {
        case .auto: "laptopcomputer.and.arrow.down"
        case .on: "arrow.up.arrow.down"
        case .off: "pause.fill"
        }
    }
}

enum ModeStoreError: LocalizedError {
    case couldNotSave

    var errorDescription: String? {
        "ScrollFlip couldn’t save your mode. Check that ~/.scrollflip is writable."
    }
}

// Shared state for the app, CLI, and App Intents. The one-word file remains
// intentionally simple so every surface interoperates without a helper daemon.
enum ModeStore {
    static let directoryURL = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".scrollflip", isDirectory: true)
    static let modeURL = directoryURL.appendingPathComponent("mode")

    static func read() -> ScrollFlipMode {
        guard let value = try? String(contentsOf: modeURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines),
              let mode = ScrollFlipMode(rawValue: value) else {
            return .auto
        }
        return mode
    }

    static func write(_ mode: ScrollFlipMode) throws {
        do {
            try FileManager.default.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true
            )
            try mode.rawValue.write(to: modeURL, atomically: true, encoding: .utf8)
            NotificationCenter.default.post(name: .scrollFlipModeChanged, object: nil)
        } catch {
            throw ModeStoreError.couldNotSave
        }
    }

    @discardableResult
    static func cycle() throws -> ScrollFlipMode {
        let next: ScrollFlipMode = switch read() {
        case .auto: .on
        case .on: .off
        case .off: .auto
        }
        try write(next)
        return next
    }

    static func lidIsClosed() -> Bool {
        let service = IOServiceGetMatchingService(
            kIOMainPortDefault,
            IOServiceMatching("IOPMrootDomain")
        )
        guard service != 0 else { return false }
        defer { IOObjectRelease(service) }

        guard let value = IORegistryEntryCreateCFProperty(
            service,
            "AppleClamshellState" as CFString,
            kCFAllocatorDefault,
            0
        )?.takeRetainedValue(), CFGetTypeID(value) == CFBooleanGetTypeID() else {
            return false
        }
        return CFBooleanGetValue((value as! CFBoolean))
    }

    static func shouldFlip(mode: ScrollFlipMode, lidClosed: Bool) -> Bool {
        switch mode {
        case .auto: lidClosed
        case .on: true
        case .off: false
        }
    }
}

extension Notification.Name {
    static let scrollFlipModeChanged = Notification.Name("scrollFlipModeChanged")
}
