import AppKit
import ApplicationServices

/// Moves and resizes windows through Accessibility, off the main thread and in order, as
/// tiling window managers do: size, then position, then size again (so a window that
/// couldn't grow before it moved gets its full size), with the app's enhanced user
/// interface mode switched off meanwhile, since it makes some apps (Chrome, Electron
/// apps) animate or ignore frame changes.
///
/// With an animation, every window glides together in small steps; a window whose app
/// is slow to answer skips straight to its final frame rather than holding up the rest.
final class WindowTiler: @unchecked Sendable {
	private let queue = DispatchQueue(label: "Cycle.tile", qos: .userInteractive)

	/// Places each window, then reports where each actually ended up, on main.
	func place(
		_ placements: [(window: SwitcherWindow, frame: CGRect)],
		animation: WindowAnimation? = nil,
		completion: @escaping @MainActor ([CGWindowID: CGRect]) -> Void
	) {
		queue.async {
			let moves = placements.compactMap { Move(window: $0.window, target: $0.frame) }
			if let animation, !moves.isEmpty { Self.animate(moves, animation) }
			var results: [CGWindowID: CGRect] = [:]
			for move in moves {
				if let frame = move.finish() { results[move.window.id] = frame }
			}
			DispatchQueue.main.async { MainActor.assumeIsolated { completion(results) } }
		}
	}

	/// Whether a window can be tiled at all.
	static func canTile(_ window: SwitcherWindow) -> Bool {
		!window.isWindowless && window.axElement != nil && !window.isOnOtherSpace
	}

	private static func animate(_ moves: [Move], _ animation: WindowAnimation) {
		let interval = animation.duration / Double(animation.steps)
		var moving = moves.filter { $0.start != nil && $0.start != $0.target }
		for step in 1..<animation.steps {
			let began = Date()
			let progress = animation.progress(atStep: step)
			moving = moving.filter { move in
				let stepBegan = Date()
				move.set(move.frame(at: progress))
				// Too slow to keep up: it jumps to the end in `finish` instead.
				return Date().timeIntervalSince(stepBegan) < interval * 1.5
			}
			if moving.isEmpty { break }
			let left = interval - Date().timeIntervalSince(began)
			if left > 0 { Thread.sleep(forTimeInterval: left) }
		}
	}
}

/// One window on its way to a frame.
private final class Move {
	let window: SwitcherWindow
	let target: CGRect
	let start: CGRect?
	private let element: AXUIElement
	private let app: AXUIElement
	private let enhanced: Bool

	init?(window: SwitcherWindow, target: CGRect) {
		guard let element = window.axElement else { return nil }
		AXUIElementSetMessagingTimeout(element, 0.25)
		// A full-screen window has its own Space; leave it there.
		if element.attribute("AXFullScreen") ?? false { return nil }
		self.window = window
		self.target = target
		self.element = element
		if window.isAppHidden { window.app?.unhide() }
		if window.isMinimized {
			AXUIElementSetAttributeValue(
				element, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
		}
		app = AXUIElementCreateApplication(window.pid)
		AXUIElementSetMessagingTimeout(app, 0.25)
		enhanced = app.attribute("AXEnhancedUserInterface") ?? false
		if enhanced {
			AXUIElementSetAttributeValue(
				app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
		}
		if let origin = element.pointAttribute(kAXPositionAttribute),
			let size = element.sizeAttribute(kAXSizeAttribute)
		{
			start = CGRect(origin: origin, size: size)
		} else {
			start = nil
		}
	}

	func frame(at progress: Double) -> CGRect {
		guard let start else { return target }
		let p = CGFloat(progress)
		return CGRect(
			x: start.minX + (target.minX - start.minX) * p,
			y: start.minY + (target.minY - start.minY) * p,
			width: start.width + (target.width - start.width) * p,
			height: start.height + (target.height - start.height) * p)
	}

	func set(_ frame: CGRect) {
		Self.set(element, position: frame.origin)
		Self.set(element, size: frame.size)
	}

	/// The final frame, firmly, then where the window actually is.
	func finish() -> CGRect? {
		defer {
			if enhanced {
				AXUIElementSetAttributeValue(
					app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
			}
		}
		Self.set(element, size: target.size)
		Self.set(element, position: target.origin)
		Self.set(element, size: target.size)
		guard let origin = element.pointAttribute(kAXPositionAttribute),
			let size = element.sizeAttribute(kAXSizeAttribute)
		else { return target }
		return CGRect(origin: origin, size: size)
	}

	private static func set(_ ax: AXUIElement, size: CGSize) {
		var size = size
		guard let value = AXValueCreate(.cgSize, &size) else { return }
		AXUIElementSetAttributeValue(ax, kAXSizeAttribute as CFString, value)
	}

	private static func set(_ ax: AXUIElement, position: CGPoint) {
		var position = position
		guard let value = AXValueCreate(.cgPoint, &position) else { return }
		AXUIElementSetAttributeValue(ax, kAXPositionAttribute as CFString, value)
	}
}
