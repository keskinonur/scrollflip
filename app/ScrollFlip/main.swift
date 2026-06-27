import AppKit

// Single instance guard via an exclusive file lock. Robust no matter how the
// app is started (launchd exec, Finder open, terminal). A second tap would
// invert the first and cancel out, so a duplicate just exits.
// The descriptor is intentionally never closed: the lock is held for the
// process lifetime. ponytail: flock is the correct primitive; the earlier
// NSRunningApplication check was wrong for bare-exec launches.
let stateDir = NSHomeDirectory() + "/.scrollflip"
try? FileManager.default.createDirectory(atPath: stateDir, withIntermediateDirectories: true)
let lockFD = open(stateDir + "/app.lock", O_CREAT | O_RDWR, 0o644)
if lockFD < 0 || flock(lockFD, LOCK_EX | LOCK_NB) != 0 { exit(0) }

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)   // no Dock icon, menu bar only
app.run()
