import Foundation
import IOKit

// Shared state for the app and its App Intents. Mode is one word in
// ~/.scrollflip/mode, the same file the CLI uses, so both versions interoperate.
enum ModeStore {
    static let dir = NSHomeDirectory() + "/.scrollflip"
    static let path = dir + "/mode"

    static func read() -> String {
        let m = (try? String(contentsOfFile: path, encoding: .utf8))?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? "auto"
        return ["auto", "on", "off"].contains(m) ? m : "auto"
    }

    static func write(_ mode: String) {
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        try? mode.write(toFile: path, atomically: true, encoding: .utf8)
        NotificationCenter.default.post(name: .scrollFlipModeChanged, object: nil)
    }

    @discardableResult
    static func cycle() -> String {
        let next = ["auto": "on", "on": "off", "off": "auto"][read()] ?? "auto"
        write(next)
        return next
    }

    static func lidIsClosed() -> Bool {
        let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard svc != 0 else { return false }
        defer { IOObjectRelease(svc) }
        guard let cf = IORegistryEntryCreateCFProperty(svc, "AppleClamshellState" as CFString,
                kCFAllocatorDefault, 0)?.takeRetainedValue(),
              CFGetTypeID(cf) == CFBooleanGetTypeID() else { return false }
        return CFBooleanGetValue((cf as! CFBoolean))
    }

    static func shouldFlip() -> Bool {
        switch read() {
        case "on":  return true
        case "off": return false
        default:    return lidIsClosed()
        }
    }
}

extension Notification.Name {
    static let scrollFlipModeChanged = Notification.Name("scrollFlipModeChanged")
}
