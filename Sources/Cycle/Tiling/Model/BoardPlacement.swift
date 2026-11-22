import CoreGraphics

/// Where the tiling board's parts sit in the overlay (top-left of the screen, y down).
struct BoardPlacement {
	/// The glass card behind everything.
	var card: CGRect
	/// The small copy of the screen.
	var screen: CGRect
	/// The preset chips in a row under it.
	var chips: [PresetChip]
}
