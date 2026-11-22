/// How a window is drawn on the tiling board.
enum BoardTileRole {
	/// Tiled and staying put (or being moved aside by the drop).
	case resting
	/// Picked up, shown faintly in its old place while no drop is lined up.
	case lifted
	/// Where a dragged window will land, numbered when several are dragged.
	case incoming(number: Int?)
}

extension BoardTileRole {
	var isResting: Bool {
		if case .resting = self { true } else { false }
	}
}
