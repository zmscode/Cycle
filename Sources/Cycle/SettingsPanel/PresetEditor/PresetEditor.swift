import RiftCore
import SwiftUI

/// Makes or changes a preset: its name, a canvas to split and resize its slots, starting
/// points (Cycle's own presets, or the screen's current layout), and Save / Cancel / Delete.
struct PresetEditor: View {
	@Binding var draft: PresetDraft
	/// The screen's tiled layout, to start from (nil when nothing's tiled).
	let currentLayout: RiftLayout<Int>?
	let onSave: () -> Void
	let onCancel: () -> Void
	let onDelete: () -> Void
	/// The name field took or gave up the keyboard.
	let onEditingText: (Bool) -> Void

	@FocusState private var nameFocused: Bool
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		VStack(alignment: .leading, spacing: 10) {
			header
			PresetCanvas(draft: $draft)
			startingPoints
			Text("Hover a slot to split or remove it. Drag a divider; double-click to even it.")
				.font(.caption2)
				.foregroundStyle(.secondary)
				.fixedSize(horizontal: false, vertical: true)
			buttons
		}
		.onChange(of: nameFocused) { _, focused in onEditingText(focused) }
		.onDisappear { onEditingText(false) }
	}

	private var header: some View {
		HStack(spacing: 8) {
			Image(systemName: "square.grid.3x2.fill")
				.foregroundStyle(Theme.Colors.mark)
			TextField("Preset name", text: $draft.name)
				.textFieldStyle(.plain)
				.font(.callout.weight(.semibold))
				.focused($nameFocused)
				.onSubmit { nameFocused = false }
				.padding(.horizontal, 10)
				.padding(.vertical, 5)
				.background(.black.opacity(0.25), in: .capsule)
				.overlay {
					Capsule().strokeBorder(nameFocused ? Theme.Colors.mark : .white.opacity(0.12))
				}
			Text("\(draft.slotCount) of \(PresetDraft.maximumSlots)")
				.font(.caption2.monospacedDigit())
				.foregroundStyle(.secondary)
				.fixedSize()
		}
	}

	private var startingPoints: some View {
		VStack(alignment: .leading, spacing: 4) {
			Text("Start from")
				.font(.caption2.weight(.semibold))
				.foregroundStyle(.secondary)
			ScrollView(.horizontal, showsIndicators: false) {
				HStack(spacing: 8) {
					if let currentLayout {
						PresetStartChip(
							title: "This Screen",
							preset: TilingPreset(id: "screen", title: "", shape: .custom(currentLayout))
						) { start(from: currentLayout) }
					}
					ForEach(BuiltinPreset.allCases) { preset in
						PresetStartChip(title: preset.title, preset: .builtin(preset)) {
							start(from: preset.layout(mainShare: Settings.tilingMainShare))
						}
					}
				}
			}
		}
	}

	private var buttons: some View {
		HStack(spacing: 6) {
			if !draft.isNew {
				Button("Delete", role: .destructive, action: onDelete)
					.buttonStyle(EditorButtonStyle(kind: .destructive))
			}
			Spacer()
			Button("Cancel", action: onCancel)
				.buttonStyle(EditorButtonStyle())
				.keyboardShortcut(.cancelAction)
			Button("Save", action: onSave)
				.buttonStyle(EditorButtonStyle(kind: .prominent))
				.keyboardShortcut(.defaultAction)
		}
	}

	private func start(from layout: RiftLayout<Int>) {
		withAnimation(reduceMotion ? nil : .spring(duration: 0.35, bounce: 0.15)) {
			draft.start(from: layout)
		}
	}
}
