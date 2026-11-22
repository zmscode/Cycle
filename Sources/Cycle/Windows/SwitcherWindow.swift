import AppKit
import ApplicationServices

/// One window the switcher can show. Mirrors the parts of DockDoor's `CapturedWindow` /
/// `WindowPreview` the switcher uses.
struct SwitcherWindow: Identifiable {
	let id: CGWindowID
	let pid: pid_t
	let appName: String
	let bundleID: String?
	let title: String
	let bounds: CGRect
	let axElement: AXUIElement?
	let isMinimized: Bool
	let isAppHidden: Bool
	/// True when it lives on a Space other than the visible one(s).
	let isOnOtherSpace: Bool
	/// Running apps with no windows get a placeholder entry (DockDoor's
	/// `windowSwitcherShowWindowlessApps`); its id is synthetic.
	let isWindowless: Bool
	/// A dialog or panel (an Open panel, an alert) rather than a document window.
	var isDialog = false

	var app: NSRunningApplication? { NSRunningApplication(processIdentifier: pid) }
	var icon: NSImage? { app?.icon }

	var displayTitle: String {
		if isWindowless { return appName }
		return title.isEmpty ? appName : title
	}
}
