import SwiftUI

/// Drag-to-tile settings: which presets the board offers, the main window's share in the
/// presets that have one, and the gaps between tiled windows and around the screen.
struct TilingTile: View {
	@Bindable var settings: MenuSettings

	var body: some View {
		ControlTile {
			VStack(alignment: .leading, spacing: 10) {
				Text("Tiling").font(.callout.bold())
				LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
					ForEach(TilingPreset.allCases) { preset in
						PresetToggle(
							preset: preset, mainShare: settings.tilingMainShare,
							shortcut: shortcut(for: preset), onToggle: toggle)
					}
				}
				TilingSlider(
					title: "Gaps", value: $settings.tilingGap, range: 0...30,
					step: 1, format: points)
				TilingSlider(
					title: "Margins", value: $settings.tilingMargin, range: 0...40,
					step: 1, format: points)
				TilingSlider(
					title: "Main Window", value: $settings.tilingMainShare, range: 0.5...0.75,
					step: 0.05, format: percent)
			}
		}
	}

	private func toggle(_ preset: TilingPreset) {
		var presets = settings.tilingPresets
		if let index = presets.firstIndex(of: preset) {
			presets.remove(at: index)
		} else {
			presets.append(preset)
		}
		// The ⌘ numbers follow the grid's order, unless the order's been set by hand in
		// cycle.config: then a newly shown preset just goes on the end.
		let canonical = TilingPreset.allCases.filter(settings.tilingPresets.contains)
		if settings.tilingPresets == canonical {
			let shown = Set(presets)
			presets = TilingPreset.allCases.filter(shown.contains)
		}
		settings.tilingPresets = presets
	}

	/// "⌘1" for the first preset shown, and so on (only the first nine have one).
	private func shortcut(for preset: TilingPreset) -> String? {
		guard let index = settings.tilingPresets.firstIndex(of: preset) else { return nil }
		return index < 9 ? "\(settings.modifier.symbol)\(index + 1)" : ""
	}

	private func points(_ value: Double) -> String {
		value == 0 ? "None" : "\(Int(value)) pt"
	}

	private func percent(_ value: Double) -> String {
		value.formatted(.percent.precision(.fractionLength(0)))
	}
}
