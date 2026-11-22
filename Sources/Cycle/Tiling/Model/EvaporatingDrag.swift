import CoreGraphics

/// Windows let go somewhere they can't land: drawn where they were dropped for a moment,
/// growing and fading, so it's plain nothing was tiled.
struct EvaporatingDrag: Equatable {
	let windowIDs: [CGWindowID]
	/// Where they were let go, in the overlay's coordinates.
	let point: CGPoint
	let serial: Int
}
