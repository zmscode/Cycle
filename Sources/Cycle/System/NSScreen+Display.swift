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

extension NSScreen {
	/// A stable name for the display (its UUID), the same across restarts and however the
	/// displays are arranged.
	var displayUUID: String? {
		guard let displayID,
			let uuid = CGDisplayCreateUUIDFromDisplayID(displayID)?.takeRetainedValue()
		else { return nil }
		return CFUUIDCreateString(nil, uuid) as String
	}

	/// The screen showing the display named `uuid`, if it's connected.
	static func screen(uuid: String) -> NSScreen? {
		screens.first { $0.displayUUID == uuid }
	}
}
