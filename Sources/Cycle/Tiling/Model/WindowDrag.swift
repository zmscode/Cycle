import AppKit
import RiftCore

/// A window being dragged from the switcher toward the tiling board.
struct WindowDrag {
	/// The window picked up.
	let windowID: CGWindowID
	/// Every window being dragged: the one picked up, or all the marked windows in the
	/// order they were marked (the order they fill a preset, left to right).
	let windowIDs: [CGWindowID]
	/// The screen being tiled: the one the switcher is on.
	let screen: NSScreen
	var board: TilingBoard
	/// The pointer, in the overlay's coordinates (top-left of the screen).
	var pointer: CGPoint
	var target: TileTarget? {
		didSet {
			guard target != oldValue else { return }
			preview = target.flatMap { board.dropping(windowIDs, on: $0) }
		}
	}
	/// The layout the drop would make. Over a preset chip the board shows it in place of
	/// the current one; over the board itself the tiles stay put (they're what the pointer
	/// is aiming at) and only the dragged windows are drawn where they'd land.
	private(set) var preview: RiftLayout<CGWindowID>?

	/// Whether the board shows the whole preview layout (the pointer is on a preset chip,
	/// off the board, so nothing moves under it).
	var showsWholePreview: Bool {
		if case .preset? = target { preview != nil } else { false }
	}

	/// Tiled windows the drop would leave out (a preset with fewer slots than windows).
	var displaced: Int {
		guard let preview else { return 0 }
		let kept = Set(preview.paneIDs)
		return (board.layout?.paneIDs ?? []).filter {
			!TilingSlot.isPlaceholder($0) && !kept.contains($0)
		}.count
	}
}
