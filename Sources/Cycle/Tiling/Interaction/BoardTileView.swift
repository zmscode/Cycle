import AppKit

/// The tiling board's hit layer: an invisible view over the board that lets its tiles be
/// picked up and dragged (to move them, or off the board to untile them) and right-clicked
/// for a menu. The board itself is drawn by the click-through overlay underneath. Points
/// are reported in AppKit screen coordinates.
final class BoardTileView: NSView {
	/// The tiled window under a point, if any.
	var tileAt: (CGPoint) -> CGWindowID? = { _ in nil }
	var onBegin: ((CGWindowID) -> Void)?
	var onMove: ((CGPoint) -> Void)?
	var onEnd: (() -> Void)?
	/// The menu for a right-clicked tile.
	var menuFor: ((CGWindowID) -> NSMenu?)?

	private var pressed: (id: CGWindowID, location: CGPoint)?
	private var isDragging = false

	override var isFlipped: Bool { true }
	override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }

	override func updateTrackingAreas() {
		super.updateTrackingAreas()
		trackingAreas.forEach(removeTrackingArea)
		addTrackingArea(
			NSTrackingArea(
				rect: bounds,
				options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
				owner: self))
	}

	override func mouseMoved(with event: NSEvent) {
		guard !isDragging else { return }
		(tileAt(NSEvent.mouseLocation) == nil ? NSCursor.arrow : .openHand).set()
	}

	override func mouseExited(with event: NSEvent) {
		if !isDragging { NSCursor.arrow.set() }
	}

	override func mouseDown(with event: NSEvent) {
		let location = NSEvent.mouseLocation
		pressed = tileAt(location).map { ($0, location) }
		isDragging = false
	}

	override func mouseDragged(with event: NSEvent) {
		let location = NSEvent.mouseLocation
		if isDragging {
			onMove?(location)
		} else if let pressed,
			hypot(location.x - pressed.location.x, location.y - pressed.location.y)
				> Theme.Tiling.dragThreshold
		{
			isDragging = true
			NSCursor.closedHand.set()
			onBegin?(pressed.id)
			onMove?(location)
		}
	}

	override func mouseUp(with event: NSEvent) {
		let wasDragging = isDragging
		pressed = nil
		isDragging = false
		if wasDragging {
			onEnd?()
			NSCursor.arrow.set()
		}
	}

	override func rightMouseDown(with event: NSEvent) {
		guard let id = tileAt(NSEvent.mouseLocation), let menu = menuFor?(id) else { return }
		NSMenu.popUpContextMenu(menu, with: event, for: self)
	}

	/// The faintest fill: a borderless window lets clicks through wherever it's fully
	/// transparent.
	override func draw(_ dirtyRect: NSRect) {
		NSColor.black.withAlphaComponent(0.01).setFill()
		dirtyRect.fill()
	}
}
