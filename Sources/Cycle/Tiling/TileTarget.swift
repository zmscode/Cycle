import CoreGraphics
import RiftCore

/// Where a dragged window would land on the tiling board.
enum TileTarget: Equatable {
	/// The board is empty: the window fills the screen.
	case fill
	/// Beside a tiled window (an edge zone, splitting it) or in its place (`.center`).
	case pane(CGWindowID, RiftDropZone)
	/// Along the full edge of the whole layout.
	case edge(RiftEdge)
	/// A slot of a preset: the screen is laid out that way.
	case preset(TilingPreset, slot: Int)
}
