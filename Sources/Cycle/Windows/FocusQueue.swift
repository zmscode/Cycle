import Foundation

/// Runs window focusing off the main thread, in order, and only the newest request: when
/// ⌘Tab is pressed faster than apps respond, the stale switches are dropped rather than
/// replayed one after another.
final class FocusQueue: @unchecked Sendable {
	private let queue = DispatchQueue(label: "Cycle.focus", qos: .userInteractive)
	private let lock = NSLock()
	private var latest = 0

	func focus(_ window: SwitcherWindow, then followUp: (@Sendable (SwitcherWindow) -> Void)? = nil) {
		let token = lock.withLock {
			latest += 1
			return latest
		}
		queue.async { [self] in
			guard lock.withLock({ latest == token }) else { return }
			WindowActions.focus(window)
			followUp?(window)
		}
	}
}
