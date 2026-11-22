import AppKit

/// The System Settings window, read from the window server.
struct SystemSettingsWindow {
	let windowNumber: CGWindowID
	/// In AppKit (bottom-left origin) screen coordinates.
	let frame: CGRect

	static func find() -> SystemSettingsWindow? {
		guard
			let settings = NSRunningApplication.runningApplications(
				withBundleIdentifier: "com.apple.systempreferences"
			).first
		else { return nil }
		let info =
			(CGWindowListCopyWindowInfo(
				[.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
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
			let frame = CGRect(
				x: cg.minX, y: primaryHeight - cg.maxY, width: cg.width, height: cg.height)
			return SystemSettingsWindow(windowNumber: id, frame: frame)
		}
		// Front-to-back order: the first is the one the user sees.
		return candidates.first
	}
}
