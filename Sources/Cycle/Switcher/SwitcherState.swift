import AppKit
import Observation

/// What the panel shows during a session; the controller writes it, the views read it.
@Observable
final class SwitcherState {
	/// The session's full list; `windows` is it filtered by the search query.
	var allWindows: [SwitcherWindow] = []
	var windows: [SwitcherWindow] = []
	var selectedID: CGWindowID? {
		didSet {
			if let window = selected { lastInApp[WindowGroup.groupKey(window)] = window.id }
		}
	}
	/// The window last selected in each app, so moving back to an app returns to it.
	var lastInApp: [String: CGWindowID] = [:]
	/// Deck layout: the app whose stack is fanned out into tiles.
	var fannedAppID: String?
	var images: [CGWindowID: NSImage] = [:]
	/// Average colour of each thumbnail; the card is tinted with it.
	var tints: [CGWindowID: NSColor] = [:]
	/// The settings panel is open under the gear; it holds the session open, as search does.
	var isShowingSettings = false
	/// The session's windows most recent first, before any grouping, so the layout can
	/// change mid-session.
	var recentOrder: [SwitcherWindow] = []
	var searchQuery = ""

	var selected: SwitcherWindow? { windows.first { $0.id == selectedID } }
}
