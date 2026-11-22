import AppKit
import Observation

/// What the panel shows during a session; the controller writes it, the views read it.
@Observable
final class SwitcherState {
	/// The session's full list; `windows` is it filtered by the search query.
	var allWindows: [SwitcherWindow] = []
	var windows: [SwitcherWindow] = []
	var selectedID: CGWindowID?
	var images: [CGWindowID: NSImage] = [:]
	/// Average colour of each thumbnail; the card is tinted with it.
	var tints: [CGWindowID: NSColor] = [:]
	/// The settings panel is open under the gear; it holds the session open, as search does.
	var isShowingSettings = false
	/// The session's windows most recent first, before any grouping, so the layout can
	/// change mid-session.
	var recentOrder: [SwitcherWindow] = []
	var searchQuery = ""
	/// A window being dragged onto the tiling board.
	var drag: WindowDrag?
	/// Windows just let go where they couldn't land, fading out.
	var evaporating: EvaporatingDrag?
	/// The tiling board shown under the switcher while its screen is tiled (no drag).
	var board: TilingBoard?
	/// A note after a tiling change ("Thirds · Helium left untiled"), with Undo.
	var tilingNotice: TilingNote?
	/// The pointer is on the note: it stays until the pointer leaves.
	var isHoldingNotice = false
	/// Tiled windows bigger than their slot (an app's minimum size): outlined on the board.
	var unfitIDs: Set<CGWindowID> = []
	/// Windows right-clicked for tiling together, in the order they were marked.
	var markedIDs: [CGWindowID] = []

	/// A marked window's place in the order (from 1), or nil.
	func markNumber(_ id: CGWindowID) -> Int? {
		markedIDs.firstIndex(of: id).map { $0 + 1 }
	}

	var selected: SwitcherWindow? { windows.first { $0.id == selectedID } }
}
