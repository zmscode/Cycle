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
							isOn: settings.tilingPresets.contains(preset), onToggle: toggle)
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
		var enabled = Set(settings.tilingPresets)
		if enabled.contains(preset) { enabled.remove(preset) } else { enabled.insert(preset) }
		settings.tilingPresets = TilingPreset.allCases.filter(enabled.contains)
	}

	private func points(_ value: Double) -> String {
		value == 0 ? "None" : "\(Int(value)) pt"
	}

	private func percent(_ value: Double) -> String {
		value.formatted(.percent.precision(.fractionLength(0)))
	}
}
