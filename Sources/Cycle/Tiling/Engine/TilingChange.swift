import RiftCore

/// One tiling change, as undo keeps it: the display's remembered layout from before.
struct TilingChange {
	let display: String
	let before: RiftLayout<RememberedSlot>?
	/// What changed, for the note undo shows ("Thirds", "Resize").
	let label: String
}
