import CoreGraphics

/// One display in the board's header, while there's more than one: hovering it during a
/// drag switches the board to that display.
struct DisplayChip: Identifiable {
	/// The display's UUID.
	let display: String
	/// Its number, left to right as the displays are arranged.
	let number: Int
	/// The chip, in the overlay's coordinates.
	let rect: CGRect
	var id: String { display }
}
