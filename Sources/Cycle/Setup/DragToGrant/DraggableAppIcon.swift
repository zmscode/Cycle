import AppKit
import SwiftUI

// Drag-to-grant, modelled on Rex's `RexPermissions` (DraggableAppIcon, SystemSettingsWindow,
// SystemSettingsSidecar, DropGuide). System Settings' privacy lists accept a dropped .app
// bundle: dropping Cycle.app on the Accessibility or Screen Recording list adds it and

/// The app's icon as a drag source carrying Cycle.app's file URL (Rex's
/// `DraggableAppIcon`). Drag phases are reported so the window can show the drop guide.
struct DraggableAppIcon: NSViewRepresentable {
	let appURL: URL
	var size: CGFloat = 64
	let onDrag: (Phase) -> Void

	enum Phase {
		case began
		case ended(accepted: Bool)
	}

	func makeNSView(context: Context) -> DragSourceView {
		let view = DragSourceView()
		view.appURL = appURL
		view.iconSize = size
		view.onDrag = onDrag
		return view
	}

	func updateNSView(_ view: DragSourceView, context: Context) {
		view.appURL = appURL
		view.onDrag = onDrag
	}

	final class DragSourceView: NSView, NSDraggingSource {
		var appURL: URL?
		var iconSize: CGFloat = 64
		var onDrag: ((Phase) -> Void)?
		private var mouseDownEvent: NSEvent?

		private var icon: NSImage {
			appURL.map { NSWorkspace.shared.icon(forFile: $0.path) } ?? NSImage()
		}

		override var intrinsicContentSize: NSSize { NSSize(width: iconSize, height: iconSize) }

		override func draw(_ dirtyRect: NSRect) {
			let side = min(bounds.width, bounds.height)
			icon.draw(
				in: NSRect(
					x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side,
					height: side))
		}

		override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
		override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
		override func mouseDown(with event: NSEvent) { mouseDownEvent = event }

		override func mouseDragged(with event: NSEvent) {
			guard let appURL, let down = mouseDownEvent else { return }
			let distance = hypot(
				event.locationInWindow.x - down.locationInWindow.x,
				event.locationInWindow.y - down.locationInWindow.y)
			guard distance > 3 else { return }
			mouseDownEvent = nil
			let item = NSDraggingItem(pasteboardWriter: appURL as NSURL)
			let side = min(bounds.width, bounds.height)
			item.setDraggingFrame(
				NSRect(
					x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side,
					height: side),
				contents: icon)
			onDrag?(.began)
			let session = beginDraggingSession(with: [item], event: event, source: self)
			session.animatesToStartingPositionsOnCancelOrFail = true
		}

		func draggingSession(
			_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext
		) -> NSDragOperation {
			context == .outsideApplication ? [.copy, .link, .generic] : []
		}

		func draggingSession(
			_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation
		) {
			onDrag?(.ended(accepted: operation != []))
		}
	}
}
