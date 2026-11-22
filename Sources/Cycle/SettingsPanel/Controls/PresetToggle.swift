import SwiftUI

/// A preset in settings: its picture, name and keyboard shortcut; click to show or hide it
/// on the board.
struct PresetToggle: View {
	let preset: TilingPreset
	let mainShare: Double
	/// "⌘1"… while it's shown (empty past the ninth), nil while hidden.
	let shortcut: String?
	let onToggle: (TilingPreset) -> Void
	/// Custom presets can be edited (a pencil on hover).
	var onEdit: (() -> Void)?

	@State private var isHovered = false

	private var isOn: Bool { shortcut != nil }
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
					.overlay(alignment: .topTrailing) {
						if let shortcut, !shortcut.isEmpty {
							Text(shortcut)
								.font(.system(size: 8, weight: .semibold).monospacedDigit())
								.padding(.horizontal, 3)
								.padding(.vertical, 1)
								.background(.black.opacity(0.6), in: .capsule)
								.padding(2)
						}
					}
				Text(preset.title)
					.font(.caption2)
					.foregroundStyle(isOn ? .primary : .secondary)
					.lineLimit(1)
					.minimumScaleFactor(0.8)
			}
		}
		.buttonStyle(.plain)
		.overlay(alignment: .topLeading) {
			if let onEdit, isHovered {
				Button(action: onEdit) {
					Image(systemName: "pencil")
						.font(.system(size: 8, weight: .bold))
						.foregroundStyle(.white)
						.frame(width: 16, height: 16)
						.background(Theme.Colors.mark, in: Circle())
				}
				.buttonStyle(.plain)
				.offset(x: -2, y: -2)
				.help("Edit \(preset.title)")
				.accessibilityLabel("Edit \(preset.title)")
				.transition(.scale.combined(with: .opacity))
			}
		}
		.onHover { hovering in withAnimation(.snappy(duration: 0.15)) { isHovered = hovering } }
		.sensoryFeedback(.selection, trigger: isOn)
		.accessibilityLabel(preset.title)
		.accessibilityValue(isOn ? "Shown" + (shortcut.map { $0.isEmpty ? "" : ", \($0)" } ?? "") : "Hidden")
		.accessibilityAddTraits(isOn ? .isSelected : [])
	}

	private func toggle() {
		onToggle(preset)
	}
}
