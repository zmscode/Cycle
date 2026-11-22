import CoreGraphics

/// A tiled window as Cycle remembers it, so it can be found again after its app (or
/// Cycle) restarts: by its window id while that's still valid, else its app and title.
struct RememberedWindow: Codable, Hashable, Sendable {
	/// The id it had when tiled. Only means anything until the window closes.
	let windowID: CGWindowID
	let bundleID: String
	let title: String

	init(windowID: CGWindowID, bundleID: String, title: String) {
		self.windowID = windowID
		self.bundleID = bundleID
		self.title = title
	}

	/// An app with no bundle id can still be tiled; it just can't be found again later.
	init(_ window: SwitcherWindow) {
		self.init(windowID: window.id, bundleID: window.bundleID ?? "", title: window.title)
	}
}
