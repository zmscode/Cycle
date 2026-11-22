import CoreGraphics

/// A window being dragged from the switcher toward the tiling board.
struct WindowDrag {
	/// The window picked up.
	let windowID: CGWindowID
	/// Every window being dragged: the one picked up, plus the other marked windows, in
	/// the order they fill a preset.
	let windowIDs: [CGWindowID]
	let display: CGDirectDisplayID
	var board: TilingBoard
	/// The pointer, in the overlay's coordinates (top-left of the screen).
	var pointer: CGPoint
	var target: TileTarget?
}
