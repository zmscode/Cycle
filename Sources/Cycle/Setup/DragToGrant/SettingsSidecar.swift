import AppKit

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
