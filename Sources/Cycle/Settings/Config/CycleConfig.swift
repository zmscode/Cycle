import Foundation

/// Everything in `cycle.config`: the switcher's settings and tiling's. Hand-editable JSON;
/// a missing or unreadable value falls back to its default rather than failing the file.
struct CycleConfig: Codable, Equatable {
	var switcher = SwitcherConfig()
	var tiling = TilingConfig()

	init() {}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		switcher = container.value(.switcher, default: SwitcherConfig())
		tiling = container.value(.tiling, default: TilingConfig())
	}
}
