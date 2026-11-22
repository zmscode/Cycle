import AppKit
import ApplicationServices

/// Moves and resizes windows through Accessibility, off the main thread and in order, as
/// tiling window managers do: size, then position, then size again (so a window that
/// couldn't grow before it moved gets its full size), with the app's enhanced user
/// interface mode switched off meanwhile, since it makes some apps (Chrome, Electron
/// apps) animate or ignore frame changes.
final class WindowTiler: @unchecked Sendable {
	private let queue = DispatchQueue(label: "Cycle.tile", qos: .userInteractive)

	/// Places each window, then reports where each actually ended up, on main.
	func place(
		_ placements: [(window: SwitcherWindow, frame: CGRect)],
		completion: @escaping @MainActor ([CGWindowID: CGRect]) -> Void
	) {
		queue.async {
			var results: [CGWindowID: CGRect] = [:]
			for placement in placements {
				if let frame = Self.setFrame(placement.window, to: placement.frame) {
					results[placement.window.id] = frame
				}
			}
			DispatchQueue.main.async { MainActor.assumeIsolated { completion(results) } }
		}
	}

	/// Whether a window can be tiled at all.
	static func canTile(_ window: SwitcherWindow) -> Bool {
		!window.isWindowless && window.axElement != nil && !window.isOnOtherSpace
	}

	private static func setFrame(_ window: SwitcherWindow, to frame: CGRect) -> CGRect? {
		guard let ax = window.axElement else { return nil }
		AXUIElementSetMessagingTimeout(ax, 0.25)
		// A full-screen window has its own Space; leave it there.
		if ax.attribute("AXFullScreen") ?? false { return nil }
		if window.isAppHidden { window.app?.unhide() }
		if window.isMinimized {
			AXUIElementSetAttributeValue(ax, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
		}
		let app = AXUIElementCreateApplication(window.pid)
		AXUIElementSetMessagingTimeout(app, 0.25)
		let enhanced: Bool = app.attribute("AXEnhancedUserInterface") ?? false
		if enhanced {
			AXUIElementSetAttributeValue(
				app, "AXEnhancedUserInterface" as CFString, kCFBooleanFalse)
		}
		defer {
			if enhanced {
				AXUIElementSetAttributeValue(
					app, "AXEnhancedUserInterface" as CFString, kCFBooleanTrue)
			}
		}
		set(ax, size: frame.size)
		set(ax, position: frame.origin)
		set(ax, size: frame.size)
		guard let origin = ax.pointAttribute(kAXPositionAttribute),
			let size = ax.sizeAttribute(kAXSizeAttribute)
		else { return frame }
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
