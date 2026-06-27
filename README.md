# scrollflip

Reverse scroll direction for a wheel mouse while keeping natural scrolling on the trackpad, on macOS.

## Why

macOS has one scroll direction setting for every pointing device. The "Natural scrolling" checkbox in the Trackpad pane and the one in the Mouse pane write the same value, so you cannot set natural scrolling for the trackpad and reversed scrolling for a mouse at the same time. scrollflip gives you both without changing any system setting.

## How it works

scrollflip installs a scroll event tap. A trackpad and a Magic Mouse send continuous, pixel based scroll events. A wheel mouse sends line based events. scrollflip inverts only the line based events, so the mouse reverses and the trackpad is left alone.

It runs as a per user LaunchAgent and reads a one word mode file once a second:

- `auto`: reverse the mouse only when the laptop lid is closed (docked or clamshell)
- `on`: always reverse the mouse
- `off`: do nothing

Keep the system "Natural scrolling" setting turned on. scrollflip handles the mouse.

## Requirements

- macOS 12 or later
- Swift toolchain (Xcode, or the Command Line Tools: `xcode-select --install`)

## Build

```
swiftc -O scrollflip.swift -o scrollflip -framework CoreGraphics -framework IOKit
```

## Install

```
./scrollflip install
```

This writes `~/Library/LaunchAgents/scrollflip.plist` and loads it. The agent starts at login.

## Grant Accessibility

A scroll event tap needs Accessibility permission.

1. Open System Settings, then Privacy & Security, then Accessibility
2. Click the plus button
3. Press Command Shift G, type the full path to the built `scrollflip` binary, and add it
4. Turn the switch on

Check that it is running:

```
./scrollflip status
```

`flipping=yes` with an empty `~/.scrollflip/scrollflip.log` means the tap is active.

The Accessibility grant is tied to the exact binary. If you rebuild scrollflip, remove the old entry in the Accessibility list and add the new binary again.

## Use

```
scrollflip auto      reverse the mouse only when the lid is closed
scrollflip on        always reverse the mouse
scrollflip off       stop reversing
scrollflip cycle     auto, then on, then off, then back to auto
scrollflip status    show mode, lid state, and current behavior
```

### Shell alias

Add this to `~/.zshrc` so you can run it from any terminal. Point it at the path where your binary lives.

```
alias scrollflip="$HOME/.scrollflip/scrollflip"
```

### Menu bar toggle

Use the Shortcuts app to get a menu bar control and a keyboard shortcut.

1. Open Shortcuts and create a new shortcut named Scroll Flip
2. Add the action Run Shell Script and set it to `$HOME/.scrollflip/scrollflip cycle`
3. Add the action Show Notification and pass it the result of the script
4. Open the shortcut details, turn on Pin in Menu Bar, and add a keyboard shortcut if you want one

Some macOS versions offer to generate a shortcut from a written description. In practice the generator skips the Run Shell Script action, so the manual steps above are the reliable way to build this one.

## Uninstall

```
./scrollflip uninstall
```

This unloads and removes the LaunchAgent. The mode file stays in `~/.scrollflip`. Delete that folder to remove everything.

## Notes

- Only wheel mice are reversed. If you use a mouse with a high resolution or free spinning wheel and a driver that sends continuous scroll events, scrollflip treats it like a trackpad and leaves it alone.
- scrollflip never changes the system scroll setting. It only edits scroll events in flight.

## License

MIT
