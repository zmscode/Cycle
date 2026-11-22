/// The note at the foot of the switcher after a tiling change: what happened, and what
/// its Undo button would put back.
struct TilingNote: Equatable {
	let text: String
	/// The change Undo reverses ("Thirds"), or nil for no Undo button.
	let undoLabel: String?
	/// Tells notes with the same text apart, so each restarts its timer.
	let serial: Int
}
