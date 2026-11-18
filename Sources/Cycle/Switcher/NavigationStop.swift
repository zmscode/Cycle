import CoreGraphics

/// Where a window sits for arrow-key movement: its index in the session's list and the
/// horizontal centre of its card within its row.
struct NavigationStop: Equatable {
	let index: Int
	let x: CGFloat
}
