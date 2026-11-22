import AppKit
import CoreGraphics

/// A session-level, head-inserted, active CGEventTap. Same shape as DockDoor's
/// `KeyMonitorHolder` (eventTap + runLoopSource + handler + isEnabled), whose tap is
/// created with `CGEventTapCreate(kCGSessionEventTap, kCGHeadInsertEventTap,
/// kCGEventTapOptionDefault, mask, …)` at 0x1003c7164. Being at the head of the session
/// stream lets it swallow ⌘Tab before the Dock's built-in switcher sees it.
final class KeyboardTap {
	/// Return true to consume the event.
	var handler: ((CGEventType, CGEvent) -> Bool)?

	private var tap: CFMachPort?
	private var source: CFRunLoopSource?

	var isRunning: Bool { tap.map { CGEvent.tapIsEnabled(tap: $0) } ?? false }

	@discardableResult
	func start() -> Bool {
		guard tap == nil else { return true }
		let mask: CGEventMask =
			(1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)
			| (1 << CGEventType.flagsChanged.rawValue)
			// Scrolling steps through windows while the switcher is open.
			| (1 << CGEventType.scrollWheel.rawValue)
			// A right-click outside the switcher undoes the last tiling change.
			| (1 << CGEventType.rightMouseDown.rawValue)
		let callback: CGEventTapCallBack = { _, type, event, refcon in
			guard let refcon else { return Unmanaged.passUnretained(event) }
			let me = Unmanaged<KeyboardTap>.fromOpaque(refcon).takeUnretainedValue()
			// The system disables slow or interrupted taps; turn it straight back on.
			if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
				if let tap = me.tap { CGEvent.tapEnable(tap: tap, enable: true) }
				return Unmanaged.passUnretained(event)
			}
			if me.handler?(type, event) == true { return nil }
			return Unmanaged.passUnretained(event)
		}
		guard
			let tap = CGEvent.tapCreate(
				tap: .cgSessionEventTap,
				place: .headInsertEventTap,
				options: .defaultTap,
				eventsOfInterest: mask,
				callback: callback,
				userInfo: Unmanaged.passUnretained(self).toOpaque()
			)
		else { return false }
		self.tap = tap
		source = CFMachPortCreateRunLoopSource(nil, tap, 0)
		CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
		CGEvent.tapEnable(tap: tap, enable: true)
		return true
	}

	func stop() {
		if let tap {
			CGEvent.tapEnable(tap: tap, enable: false)
			CFMachPortInvalidate(tap)
		}
		if let source { CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes) }
		tap = nil
		source = nil
	}
}
