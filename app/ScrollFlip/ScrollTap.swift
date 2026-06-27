import CoreGraphics
import Foundation

// The C callback cannot capture context, so the ScrollTap instance is passed
// through refcon and recovered here.
private func scrollTapCallback(proxy: CGEventTapProxy, type: CGEventType,
        event: CGEvent, refcon: UnsafeMutableRawPointer?) -> Unmanaged<CGEvent>? {
    guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<ScrollTap>.fromOpaque(refcon).takeUnretainedValue()

    if type == .scrollWheel, tap.flip,
       event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 {
        for f in [CGEventField.scrollWheelEventDeltaAxis1,
                  .scrollWheelEventDeltaAxis2,
                  .scrollWheelEventPointDeltaAxis1,
                  .scrollWheelEventPointDeltaAxis2] {
            event.setIntegerValueField(f, value: -event.getIntegerValueField(f))
        }
    } else if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        tap.enable()   // re-arm if the OS disables us
    }
    return Unmanaged.passUnretained(event)
}

final class ScrollTap {
    private var port: CFMachPort?
    var flip = false

    var isActive: Bool { port != nil }

    // Returns false when the tap cannot be created, which means Accessibility
    // permission has not been granted yet.
    @discardableResult
    func start() -> Bool {
        if port != nil { return true }
        let mask = (1 << CGEventType.scrollWheel.rawValue)
        let info = Unmanaged.passUnretained(self).toOpaque()
        guard let p = CGEvent.tapCreate(tap: .cgSessionEventTap, place: .headInsertEventTap,
                options: .defaultTap, eventsOfInterest: CGEventMask(mask),
                callback: scrollTapCallback, userInfo: info) else {
            return false
        }
        port = p
        let src = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, p, 0)
        CFRunLoopAddSource(CFRunLoopGetCurrent(), src, .commonModes)
        CGEvent.tapEnable(tap: p, enable: true)
        return true
    }

    func enable() {
        if let p = port { CGEvent.tapEnable(tap: p, enable: true) }
    }
}
