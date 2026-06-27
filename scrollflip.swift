import CoreGraphics
import IOKit
import Foundation

// scrollflip: keep natural scrolling on the trackpad, reverse it on a wheel mouse.
// macOS has a single global scroll-direction setting shared by every pointing
// device. This intercepts scroll events and inverts only the ones from a wheel
// mouse (non-continuous), leaving trackpad and Magic Mouse events untouched.
//
// Subcommands:
//   run                start the event tap (the LaunchAgent calls this)
//   auto | on | off    set mode (auto = flip only when the lid is closed)
//   cycle              auto -> on -> off -> auto
//   status             print mode, lid state, and whether it is flipping now
//   install            write the LaunchAgent and load it
//   uninstall          unload and remove the LaunchAgent

let home = NSHomeDirectory()
let modeDir = home + "/.scrollflip"
let modePath = modeDir + "/mode"
let label = "scrollflip"
let plistPath = home + "/Library/LaunchAgents/\(label).plist"
let logPath = modeDir + "/scrollflip.log"

// ---------- mode + lid ----------

func readMode() -> String {
    let m = (try? String(contentsOfFile: modePath, encoding: .utf8))?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? "auto"
    return m.isEmpty ? "auto" : m
}

func writeMode(_ m: String) {
    try? FileManager.default.createDirectory(atPath: modeDir, withIntermediateDirectories: true)
    try? m.write(toFile: modePath, atomically: true, encoding: .utf8)
}

func lidIsClosed() -> Bool {
    let svc = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
    guard svc != 0 else { return false }
    defer { IOObjectRelease(svc) }
    guard let cf = IORegistryEntryCreateCFProperty(svc, "AppleClamshellState" as CFString,
            kCFAllocatorDefault, 0)?.takeRetainedValue(),
          CFGetTypeID(cf) == CFBooleanGetTypeID() else { return false }
    return CFBooleanGetValue((cf as! CFBoolean))
}

func shouldFlip() -> Bool {
    switch readMode() {
    case "on":  return true
    case "off": return false
    default:    return lidIsClosed()   // auto
    }
}

// ---------- event tap ----------

var gFlip = false
var gTap: CFMachPort?

func cb(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent,
        refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    if type == .scrollWheel, gFlip,
       event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 {
        for f in [CGEventField.scrollWheelEventDeltaAxis1,
                  .scrollWheelEventDeltaAxis2,
                  .scrollWheelEventPointDeltaAxis1,
                  .scrollWheelEventPointDeltaAxis2] {
            event.setIntegerValueField(f, value: -event.getIntegerValueField(f))
        }
    } else if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let t = gTap { CGEvent.tapEnable(tap: t, enable: true) }
    }
    return Unmanaged.passUnretained(event)
}

func runDaemon() -> Never {
    let mask = (1 << CGEventType.scrollWheel.rawValue)
    guard let tap = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
            options: .defaultTap, eventsOfInterest: CGEventMask(mask),
            callback: cb, userInfo: nil) else {
        FileHandle.standardError.write("scrollflip: no event tap. Grant Accessibility permission.\n".data(using: .utf8)!)
        sleep(5)
        exit(1)
    }
    gTap = tap
    let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
    CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
    CGEvent.tapEnable(tap: tap, enable: true)

    gFlip = shouldFlip()
    let timer = Timer(timeInterval: 1.0, repeats: true) { _ in gFlip = shouldFlip() }
    RunLoop.current.add(timer, forMode: .common)

    CFRunLoopRun()
    exit(0)
}

// ---------- install / uninstall ----------

func binaryPath() -> String {
    if let p = Bundle.main.executablePath { return p }
    return (CommandLine.arguments[0] as NSString).resolvingSymlinksInPath
}

@discardableResult
func launchctl(_ args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: "/bin/launchctl")
    p.arguments = args
    try? p.run()
    p.waitUntilExit()
    return p.terminationStatus
}

func install() {
    let bin = binaryPath()
    let plist = """
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
    <dict>
        <key>Label</key>
        <string>\(label)</string>
        <key>ProgramArguments</key>
        <array>
            <string>\(bin)</string>
            <string>run</string>
        </array>
        <key>RunAtLoad</key>
        <true/>
        <key>KeepAlive</key>
        <true/>
        <key>StandardErrorPath</key>
        <string>\(logPath)</string>
    </dict>
    </plist>
    """
    try? FileManager.default.createDirectory(atPath: home + "/Library/LaunchAgents",
        withIntermediateDirectories: true)
    do {
        try plist.write(toFile: plistPath, atomically: true, encoding: .utf8)
    } catch {
        print("could not write \(plistPath): \(error)")
        exit(1)
    }
    let uid = getuid()
    launchctl(["bootout", "gui/\(uid)/\(label)"])           // ignore if not loaded
    let rc = launchctl(["bootstrap", "gui/\(uid)", plistPath])
    print("installed \(plistPath)")
    print(rc == 0 ? "loaded" : "bootstrap returned \(rc)")
    print("")
    print("Now grant Accessibility to this binary:")
    print("  \(bin)")
    print("System Settings > Privacy & Security > Accessibility > +")
    print("Then run: scrollflip status")
}

func uninstall() {
    let uid = getuid()
    launchctl(["bootout", "gui/\(uid)/\(label)"])
    try? FileManager.default.removeItem(atPath: plistPath)
    print("unloaded and removed \(plistPath)")
    print("mode file kept at \(modePath). Remove \(modeDir) to delete everything.")
}

// ---------- dispatch ----------

let cmd = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "status"
switch cmd {
case "run":
    runDaemon()
case "auto", "on", "off":
    writeMode(cmd)
    print(cmd)
case "cycle":
    let next = ["auto": "on", "on": "off", "off": "auto"][readMode()] ?? "auto"
    writeMode(next)
    print(next)
case "status":
    print("mode=\(readMode()) lid=\(lidIsClosed() ? "closed" : "open") flipping=\(shouldFlip() ? "yes" : "no")")
case "install":
    install()
case "uninstall":
    uninstall()
default:
    print("usage: scrollflip run|auto|on|off|cycle|status|install|uninstall")
}
