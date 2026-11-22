import AppKit

extension NSScreen {
	var displayID: CGDirectDisplayID? {
		deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
	}

	/// The visible frame in window-server coordinates (top-left of the main screen, y down).
	var visibleFrameTopLeft: CGRect {
		let primaryHeight = NSScreen.screens.first?.frame.height ?? frame.height
		return CGRect(
			x: visibleFrame.minX, y: primaryHeight - visibleFrame.maxY,
			width: visibleFrame.width, height: visibleFrame.height)
	}
}
