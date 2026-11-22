import CoreGraphics

/// One preset on the board.
struct PresetChip: Identifiable {
	let preset: TilingPreset
	/// The chip's picture of the preset.
	let rect: CGRect
	var id: String { preset.id }
}
