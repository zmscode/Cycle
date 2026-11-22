import SwiftUI

/// A preset in settings: its picture and name; click to show or hide it on the board.
struct PresetToggle: View {
	let preset: TilingPreset
	let mainShare: Double
	let isOn: Bool
	let onToggle: (TilingPreset) -> Void

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 8) }

	var body: some View {
		Button(action: toggle) {
			VStack(spacing: 4) {
				PresetThumbnail(preset: preset, mainShare: mainShare, isEnabled: isOn)
					.frame(width: 46, height: 29)
					.padding(4)
					.background {
						shape.fill(
							isOn ? Theme.Colors.selection.opacity(0.35) : .white.opacity(0.05))
					}
					.overlay {
						shape.strokeBorder(isOn ? Theme.Colors.selection : .white.opacity(0.12))
					}
				Text(preset.title)
					.font(.caption2)
					.foregroundStyle(isOn ? .primary : .secondary)
					.lineLimit(1)
					.minimumScaleFactor(0.8)
			}
		}
		.buttonStyle(.plain)
		.sensoryFeedback(.selection, trigger: isOn)
		.accessibilityLabel(preset.title)
		.accessibilityValue(isOn ? "Shown" : "Hidden")
		.accessibilityAddTraits(isOn ? .isSelected : [])
	}

	private func toggle() {
		onToggle(preset)
	}
}
