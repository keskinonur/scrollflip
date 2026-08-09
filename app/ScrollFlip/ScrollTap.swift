import CoreGraphics
import Foundation

private func scrollTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard let refcon else { return Unmanaged.passUnretained(event) }
    let tap = Unmanaged<ScrollTap>.fromOpaque(refcon).takeUnretainedValue()

    if type == .scrollWheel,
       tap.shouldFlip,
       event.getIntegerValueField(.scrollWheelEventIsContinuous) == 0 {
        for field in [
            CGEventField.scrollWheelEventDeltaAxis1,
            .scrollWheelEventDeltaAxis2,
            .scrollWheelEventPointDeltaAxis1,
            .scrollWheelEventPointDeltaAxis2,
            .scrollWheelEventFixedPtDeltaAxis1,
            .scrollWheelEventFixedPtDeltaAxis2,
        ] {
            event.setIntegerValueField(
                field,
                value: -event.getIntegerValueField(field)
            )
        }
    } else if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        tap.enable()
    }

    return Unmanaged.passUnretained(event)
}

final class ScrollTap {
    private var port: CFMachPort?
    private var source: CFRunLoopSource?
    var shouldFlip = false

    var isActive: Bool {
        guard let port else { return false }
        return CGEvent.tapIsEnabled(tap: port)
    }

    @discardableResult
    func start() -> Bool {
        if let port {
            CGEvent.tapEnable(tap: port, enable: true)
            return true
        }

        let mask = CGEventMask(1 << CGEventType.scrollWheel.rawValue)
        let context = Unmanaged.passUnretained(self).toOpaque()
        guard let port = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: scrollTapCallback,
            userInfo: context
        ) else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, port, 0)
        self.port = port
        self.source = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: port, enable: true)
        return true
    }

    func enable() {
        guard let port else { return }
        CGEvent.tapEnable(tap: port, enable: true)
    }

    func stop() {
        if let source {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        if let port {
            CGEvent.tapEnable(tap: port, enable: false)
            CFMachPortInvalidate(port)
        }
        source = nil
        port = nil
    }

    deinit {
        stop()
    }
}
