import AppKit
import RiftCore

/// A divider grip: a rounded pill centred in the gap that grows and takes the accent colour
/// under the pointer, with a hairline the length of the divider while it's dragged. Shows
/// the resize cursor, and reports drags and double-clicks in window-server coordinates.
final class DividerHandleView: NSView {
	var axis: RiftAxis = .horizontal {
		didSet { needsDisplay = true }
	}
	var style: DividerHandleStyle = .screen
	var onBegin: ((CGPoint) -> Void)?
	var onMove: ((CGPoint) -> Void)?
	var onEnd: (() -> Void)?
	var onReset: (() -> Void)?

	private var isHovered = false {
		didSet { needsDisplay = true }
	}
	private var isDragging = false {
		didSet { needsDisplay = true }
	}

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

	override func mouseEntered(with event: NSEvent) {
		isHovered = true
		cursor.set()
	}

	override func mouseMoved(with event: NSEvent) {
		cursor.set()
	}

	override func mouseExited(with event: NSEvent) {
		isHovered = false
		if !isDragging { NSCursor.arrow.set() }
	}

	override func mouseDown(with event: NSEvent) {
		if event.clickCount == 2 {
			onReset?()
			return
		}
		isDragging = true
		cursor.set()
		onBegin?(Self.pointer)
	}

	override func mouseDragged(with event: NSEvent) {
		guard isDragging else { return }
		cursor.set()
		onMove?(Self.pointer)
	}

	override func mouseUp(with event: NSEvent) {
		guard isDragging else { return }
		isDragging = false
		onEnd?()
		if !isHovered { NSCursor.arrow.set() }
	}

	private var cursor: NSCursor {
		axis == .horizontal ? .resizeLeftRight : .resizeUpDown
	}

	/// The pointer in window-server coordinates (top-left of the main screen, y down).
	private static var pointer: CGPoint {
		let location = NSEvent.mouseLocation
		let height = NSScreen.screens.first?.frame.height ?? 0
		return CGPoint(x: location.x, y: height - location.y)
	}

	override func draw(_ dirtyRect: NSRect) {
		// The faintest fill, so the whole grip takes clicks: a borderless window lets them
		// through wherever it's fully transparent.
		NSColor.black.withAlphaComponent(0.01).setFill()
		bounds.fill()
		let active = isHovered || isDragging
		let accent = NSColor(Theme.Colors.mark)
		let horizontal = axis == .horizontal
		let length = horizontal ? bounds.height : bounds.width
		let across = horizontal ? bounds.width : bounds.height

		if isDragging {
			// The divider's whole length, so the split being moved is plain.
			let line =
				horizontal
				? CGRect(x: bounds.midX - 0.5, y: 0, width: 1, height: bounds.height)
				: CGRect(x: 0, y: bounds.midY - 0.5, width: bounds.width, height: 1)
			accent.withAlphaComponent(0.55).setFill()
			line.fill()
		}

		let pillLength: CGFloat
		let pillThickness: CGFloat
		switch style {
		case .screen:
			pillLength = min(length * 0.4, active ? 96 : 56)
			pillThickness = min(across - 2, active ? 6 : 4)
		case .board:
			pillLength = min(length * 0.5, active ? 26 : 16)
			pillThickness = min(across - 1, active ? 4 : 3)
		}
		let pill =
			horizontal
			? CGRect(
				x: bounds.midX - pillThickness / 2, y: bounds.midY - pillLength / 2,
				width: pillThickness, height: pillLength)
			: CGRect(
				x: bounds.midX - pillLength / 2, y: bounds.midY - pillThickness / 2,
				width: pillLength, height: pillThickness)
		let path = NSBezierPath(
			roundedRect: pill, xRadius: pillThickness / 2, yRadius: pillThickness / 2)

		NSGraphicsContext.saveGraphicsState()
		let shadow = NSShadow()
		shadow.shadowColor = NSColor.black.withAlphaComponent(0.45)
		shadow.shadowBlurRadius = 3
		shadow.shadowOffset = .zero
		shadow.set()
		(active ? accent : NSColor.white.withAlphaComponent(0.7)).setFill()
		path.fill()
		NSGraphicsContext.restoreGraphicsState()
		NSColor.black.withAlphaComponent(0.25).setStroke()
		path.lineWidth = 0.5
		path.stroke()
	}
}
