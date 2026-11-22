import AppKit

/// Watches the mouse in the switcher panel for a card being picked up: held for a moment,
/// or pressed and moved. Once picked up it reports every movement and the release. The
/// events still reach the cards, so a quick click keeps switching windows; the controller
/// ignores the click that ends a drag.
@MainActor
final class DragTracker {
	/// The card under the pointer when the button went down, if it can be dragged.
	var pickUpCandidate: () -> CGWindowID? = { nil }
	/// Whether an event belongs to the switcher panel (not settings or the gear).
	var isSwitcherWindow: (NSWindow?) -> Bool = { _ in false }
	var onBegin: (CGWindowID) -> Void = { _ in }
	var onMove: (CGPoint) -> Void = { _ in }
	var onEnd: () -> Void = {}
	/// A right-click on the switcher panel.
	var onRightClick: (NSEvent) -> Void = { _ in }
	/// A new press: forget any click a previous drag left to be ignored.
	var onPress: () -> Void = {}

	private var monitor: Any?
	private var pressed: (id: CGWindowID, location: CGPoint)?
	private var holdWork: DispatchWorkItem?
	private(set) var isDragging = false

	func start() {
		guard monitor == nil else { return }
		monitor = NSEvent.addLocalMonitorForEvents(matching: [
			.leftMouseDown, .leftMouseDragged, .leftMouseUp, .rightMouseDown,
		]) { [weak self] event in
			MainActor.assumeIsolated { self?.handle(event) }
			return event
		}
	}

	func stop() {
		if let monitor { NSEvent.removeMonitor(monitor) }
		monitor = nil
		reset()
	}

	/// Drops the current press or drag without reporting its end.
	func reset() {
		holdWork?.cancel()
		holdWork = nil
		pressed = nil
		isDragging = false
	}

	private func handle(_ event: NSEvent) {
		let location = NSEvent.mouseLocation
		switch event.type {
		case .rightMouseDown:
			if !isDragging, isSwitcherWindow(event.window) { onRightClick(event) }
		case .leftMouseDown:
			reset()
			onPress()
			guard isSwitcherWindow(event.window), let id = pickUpCandidate() else { return }
			pressed = (id, location)
			let work = DispatchWorkItem { [weak self] in
				MainActor.assumeIsolated { self?.begin(at: location) }
			}
			holdWork = work
			DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Tiling.holdDelay, execute: work)
		case .leftMouseDragged:
			if isDragging {
				onMove(location)
			} else if let pressed,
				hypot(location.x - pressed.location.x, location.y - pressed.location.y)
					> Theme.Tiling.dragThreshold
			{
				begin(at: location)
			}
		case .leftMouseUp:
			let wasDragging = isDragging
			reset()
			if wasDragging { onEnd() }
		default:
			break
		}
	}

	private func begin(at location: CGPoint) {
		guard let pressed, !isDragging else { return }
		holdWork?.cancel()
		holdWork = nil
		isDragging = true
		onBegin(pressed.id)
		onMove(location)
	}
}
