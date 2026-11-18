import AppKit
import SwiftUI

// Drag-to-grant, modelled on Rex's `RexPermissions` (DraggableAppIcon, SystemSettingsWindow,
// SystemSettingsSidecar, DropGuide). System Settings' privacy lists accept a dropped .app
// bundle: dropping Cycle.app on the Accessibility or Screen Recording list adds it and
// switches it on, which is quicker than the + button and its file picker.

/// The System Settings window, read from the window server.
struct SystemSettingsWindow {
	let windowNumber: CGWindowID
	/// In AppKit (bottom-left origin) screen coordinates.
	let frame: CGRect

	static func find() -> SystemSettingsWindow? {
		guard let settings = NSRunningApplication.runningApplications(
			withBundleIdentifier: "com.apple.systempreferences"
		).first else { return nil }
		let info = (CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
			as? [[String: Any]]) ?? []
		let primaryHeight = NSScreen.screens.first?.frame.height ?? 0
		let candidates = info.compactMap { entry -> SystemSettingsWindow? in
			guard entry[kCGWindowOwnerPID as String] as? pid_t == settings.processIdentifier,
				entry[kCGWindowLayer as String] as? Int == 0,
				let id = entry[kCGWindowNumber as String] as? CGWindowID,
				let dict = entry[kCGWindowBounds as String] as? NSDictionary,
				let cg = CGRect(dictionaryRepresentation: dict as CFDictionary),
				cg.width > 300, cg.height > 300
			else { return nil }
			let frame = CGRect(x: cg.minX, y: primaryHeight - cg.maxY, width: cg.width, height: cg.height)
			return SystemSettingsWindow(windowNumber: id, frame: frame)
		}
		// Front-to-back order: the first is the one the user sees.
		return candidates.first
	}
}

/// Keeps the permissions window docked beside System Settings while both are open
/// (Rex's `SystemSettingsSidecar`).
@MainActor
final class SettingsSidecar {
	private weak var follower: NSWindow?
	private var timer: Timer?
	private var lastSettingsFrame: CGRect?

	func follow(with window: NSWindow) {
		follower = window
		guard timer == nil else { return }
		timer = Timer.scheduledTimer(withTimeInterval: 0.15, repeats: true) { [weak self] _ in
			MainActor.assumeIsolated { self?.tick() }
		}
	}

	func stop() {
		timer?.invalidate()
		timer = nil
		lastSettingsFrame = nil
	}

	private func tick() {
		guard let follower, follower.isVisible else { return stop() }
		// Leave the window alone while the user drags it, or while a drag is in flight.
		guard NSEvent.pressedMouseButtons == 0,
			let settings = SystemSettingsWindow.find()
		else { return }
		guard settings.frame != lastSettingsFrame else { return }
		lastSettingsFrame = settings.frame

		let gap: CGFloat = 14
		let size = follower.frame.size
		let screen = NSScreen.screens.first { $0.frame.intersects(settings.frame) } ?? NSScreen.main
		let visible = screen?.visibleFrame ?? .infinite
		var origin = CGPoint(x: settings.frame.maxX + gap, y: settings.frame.maxY - size.height)
		if origin.x + size.width > visible.maxX {
			origin.x = settings.frame.minX - gap - size.width
		}
		origin.x = min(max(origin.x, visible.minX), visible.maxX - size.width)
		origin.y = min(max(origin.y, visible.minY), visible.maxY - size.height)
		follower.setFrame(CGRect(origin: origin, size: size), display: true, animate: true)
	}
}

/// While the icon is being dragged: dims every screen except the System Settings window,
/// rims that window, and captions it (Rex's `DropGuide` + `SpotlightPanel`). The panels
/// ignore the mouse, so the drop lands on Settings underneath.
@MainActor
final class DropGuide {
	private var panels: [NSPanel] = []

	func show(target: SystemSettingsWindow) {
		hide()
		for screen in NSScreen.screens {
			let panel = NSPanel(
				contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
				backing: .buffered, defer: false)
			panel.level = .floating
			panel.isOpaque = false
			panel.backgroundColor = .clear
			panel.hasShadow = false
			panel.ignoresMouseEvents = true
			panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
			let hole = target.frame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
			let showsCaption = screen.frame.intersects(target.frame)
			panel.contentView = NSHostingView(
				rootView: SpotlightView(hole: hole, size: screen.frame.size, showsCaption: showsCaption))
			panel.alphaValue = 0
			panel.orderFrontRegardless()
			NSAnimationContext.runAnimationGroup { $0.duration = 0.18; panel.animator().alphaValue = 1 }
			panels.append(panel)
		}
	}

	func hide() {
		let old = panels
		panels = []
		NSAnimationContext.runAnimationGroup({ $0.duration = 0.18; old.forEach { $0.animator().alphaValue = 0 } }) {
			old.forEach { $0.orderOut(nil) }
		}
	}
}

private struct SpotlightView: View {
	/// The Settings window in this view's coordinates (bottom-left origin).
	let hole: CGRect
	let size: CGSize
	let showsCaption: Bool

	private var holeTopLeft: CGRect {
		CGRect(x: hole.minX, y: size.height - hole.maxY, width: hole.width, height: hole.height)
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
		ZStack(alignment: .topLeading) {
			Rectangle()
				.fill(.black.opacity(0.35))
				.reverseMask {
					shape.frame(width: holeTopLeft.width, height: holeTopLeft.height)
						.offset(x: holeTopLeft.minX, y: holeTopLeft.minY)
				}
			shape
				.strokeBorder(Color.accentColor, lineWidth: 4)
				.shadow(color: .accentColor.opacity(0.8), radius: 16)
				.frame(width: holeTopLeft.width, height: holeTopLeft.height)
				.offset(x: holeTopLeft.minX, y: holeTopLeft.minY)
			if showsCaption {
				Label("Drop Cycle into the list to allow it", systemImage: "arrow.down.app")
					.font(.system(size: 14, weight: .semibold))
					.padding(.horizontal, 16)
					.padding(.vertical, 10)
					.glassEffect(.regular, in: .capsule)
					.fixedSize()
					.frame(width: holeTopLeft.width)
					.offset(x: holeTopLeft.minX, y: max(holeTopLeft.minY - 54, 8))
			}
		}
		.frame(width: size.width, height: size.height, alignment: .topLeading)
		.ignoresSafeArea()
	}
}

private extension View {
	func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
		self.mask {
			Rectangle()
				.overlay(alignment: .topLeading) { mask().blendMode(.destinationOut) }
				.compositingGroup()
		}
	}
}

/// The app's icon as a drag source carrying Cycle.app's file URL (Rex's
/// `DraggableAppIcon`). Drag phases are reported so the window can show the drop guide.
struct DraggableAppIcon: NSViewRepresentable {
	let appURL: URL
	var size: CGFloat = 64
	let onDrag: (Phase) -> Void

	enum Phase { case began, ended(accepted: Bool) }

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
			icon.draw(in: NSRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side))
		}

		override func resetCursorRects() { addCursorRect(bounds, cursor: .openHand) }
		override func acceptsFirstMouse(for event: NSEvent?) -> Bool { true }
		override func mouseDown(with event: NSEvent) { mouseDownEvent = event }

		override func mouseDragged(with event: NSEvent) {
			guard let appURL, let down = mouseDownEvent else { return }
			let distance = hypot(event.locationInWindow.x - down.locationInWindow.x,
								 event.locationInWindow.y - down.locationInWindow.y)
			guard distance > 3 else { return }
			mouseDownEvent = nil
			let item = NSDraggingItem(pasteboardWriter: appURL as NSURL)
			let side = min(bounds.width, bounds.height)
			item.setDraggingFrame(
				NSRect(x: (bounds.width - side) / 2, y: (bounds.height - side) / 2, width: side, height: side),
				contents: icon)
			onDrag?(.began)
			let session = beginDraggingSession(with: [item], event: event, source: self)
			session.animatesToStartingPositionsOnCancelOrFail = true
		}

		func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
			context == .outsideApplication ? [.copy, .link, .generic] : []
		}

		func draggingSession(_ session: NSDraggingSession, endedAt screenPoint: NSPoint, operation: NSDragOperation) {
			onDrag?(.ended(accepted: operation != []))
		}
	}
}
