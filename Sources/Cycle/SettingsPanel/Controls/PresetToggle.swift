import SwiftUI

/// A preset in settings: its picture, name and keyboard shortcut; click to show or hide it
/// on the board.
struct PresetToggle: View {
	let preset: TilingPreset
	let mainShare: Double
	/// "⌘1"… while it's shown (empty past the ninth), nil while hidden.
	let shortcut: String?
	let onToggle: (TilingPreset) -> Void
	/// Custom presets can be edited (a pencil on hover); built-ins can be adjusted, which
	/// opens a custom copy in the editor (sliders on hover).
	var onEdit: (() -> Void)?

	private var editIcon: String { preset.isCustom ? "pencil" : "slider.horizontal.3" }
	private var editLabel: String {
		preset.isCustom ? "Edit \(preset.title)" : "Adjust \(preset.title)…"
	}

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
								.font(.system(size: 10, weight: .semibold).monospacedDigit())
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
					Image(systemName: editIcon)
						.font(.system(size: 10, weight: .bold))
						.foregroundStyle(.white)
						.frame(width: 18, height: 18)
						.background(Theme.Colors.mark, in: Circle())
						// The 20 pt minimum target, around the smaller circle.
						.frame(width: 22, height: 22)
						.contentShape(Circle())
				}
				.buttonStyle(.plain)
				.offset(x: -5, y: -5)
				.help(editLabel)
				.accessibilityLabel(editLabel)
				.transition(.scale.combined(with: .opacity))
			}
		}
		.onHover { hovering in withAnimation(.snappy(duration: 0.15)) { isHovered = hovering } }
		// The hover button's actions, also from a right-click and VoiceOver.
		.contextMenu {
			Button(isOn ? "Hide from Board" : "Show on Board", action: toggle)
			if let onEdit {
				Button(preset.isCustom ? "Edit…" : "Adjust…", action: onEdit)
			}
		}
		.accessibilityActions {
			if let onEdit {
				Button(editLabel, action: onEdit)
			}
		}
		.sensoryFeedback(.selection, trigger: isOn)
		.accessibilityLabel(preset.title)
		.accessibilityValue(
			isOn ? "Shown" + (shortcut.map { $0.isEmpty ? "" : ", \($0)" } ?? "") : "Hidden"
		)
		.accessibilityAddTraits(isOn ? .isSelected : [])
	}

	private func toggle() {
		onToggle(preset)
	}
}
