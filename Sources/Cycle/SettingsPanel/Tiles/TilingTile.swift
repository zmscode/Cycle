import RiftCore
import SwiftUI

/// Drag-to-tile settings: which presets the board offers (Cycle's own and ones made in the
/// editor), the main window's share in the presets that have one, the gaps between tiled
/// windows and around the screen, and how long windows take to glide into place.
struct TilingTile: View {
	@Bindable var settings: MenuSettings
	/// The screen's tiled layout, for the editor to start from.
	let currentLayout: () -> RiftLayout<Int>?
	/// The tile changed height (the editor opened or closed): the panel fits itself to it.
	let onResize: () -> Void

	@State private var draft: PresetDraft?
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		ControlTile {
			Group {
				if draft != nil {
					PresetEditor(
						draft: Binding {
							draft ?? PresetDraft(startingWith: .pane(0), name: "")
						} set: { new in
							// The editor fades out after Save or Cancel, and its name field
							// writes its text back as it goes: that mustn't open a new draft.
							guard let current = draft, current.id == new.id else { return }
							draft = new
						},
						currentLayout: currentLayout(), onSave: save, onCancel: closeEditor,
						onDelete: delete,
						onEditingText: { settings.isEditingText = $0 }
					)
					.transition(.opacity.combined(with: .scale(scale: 0.97)))
				} else {
					options
						.transition(.opacity)
				}
			}
		}
		.onChange(of: draft == nil) { DispatchQueue.main.async(execute: onResize) }
	}

	private var options: some View {
		VStack(alignment: .leading, spacing: 10) {
			Text("Tiling").font(.callout.bold())
			LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 8) {
				ForEach(TilingPreset.all(customs: settings.tilingCustomPresets)) { preset in
					PresetToggle(
						preset: preset, mainShare: settings.tilingMainShare,
						shortcut: shortcut(for: preset), onToggle: toggle,
						onEdit: { edit(preset) })
				}
				NewPresetTile(action: newPreset)
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
			TilingSlider(
				title: "Animation", value: $settings.tilingAnimationDuration,
				range: 0.05...0.3, step: 0.01, format: seconds
			)
			.disabled(!settings.tilingAnimates || reduceMotion)
			.opacity(settings.tilingAnimates && !reduceMotion ? 1 : 0.45)
			if reduceMotion {
				Label(
					"Windows jump into place while Reduce Motion is on",
					systemImage: "figure.walk.motion"
				)
				.font(.caption2)
				.foregroundStyle(.secondary)
			}
		}
	}

	// MARK: Editing presets

	private func newPreset() {
		let number = settings.tilingCustomPresets.count + 1
		openEditor(
			PresetDraft(
				startingWith: BuiltinPreset.halves.layout(mainShare: 0.5), name: "Custom \(number)")
		)
	}

	private func edit(_ preset: TilingPreset) {
		if case .builtin(let builtin) = preset.shape {
			return openEditor(PresetDraft(adjusting: builtin, mainShare: settings.tilingMainShare))
		}
		guard let custom = settings.tilingCustomPresets.first(where: { $0.id == preset.id }) else {
			return
		}
		openEditor(PresetDraft(editing: custom))
	}

	private func openEditor(_ new: PresetDraft) {
		withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { draft = new }
	}

	private func closeEditor() {
		withAnimation(reduceMotion ? nil : .smooth(duration: 0.25)) { draft = nil }
	}

	/// Saves the draft; a new preset goes straight onto the board.
	private func save() {
		guard let draft else { return }
		let preset = draft.saved
		var customs = settings.tilingCustomPresets
		if let index = customs.firstIndex(where: { $0.id == preset.id }) {
			customs[index] = preset
		} else {
			customs.append(preset)
		}
		settings.tilingCustomPresets = customs
		var shown = settings.tilingPresets.map(\.id)
		if let original = draft.replacing, let index = shown.firstIndex(of: original) {
			// An adjusted built-in takes the original's place, and its ⌘ number.
			shown[index] = preset.id
		} else if draft.isNew {
			shown.append(preset.id)
		}
		settings.tilingPresets = shown.compactMap { TilingPreset.named($0, customs: customs) }
		closeEditor()
	}

	private func delete() {
		guard let draft else { return }
		settings.tilingCustomPresets.removeAll { $0.id == draft.id }
		settings.tilingPresets.removeAll { $0.id == draft.id }
		closeEditor()
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
		let all = TilingPreset.all(customs: settings.tilingCustomPresets)
		let canonical = all.filter(settings.tilingPresets.contains)
		if settings.tilingPresets == canonical {
			let shown = Set(presets)
			presets = all.filter(shown.contains)
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

	private func seconds(_ value: Double) -> String {
		value.formatted(.number.precision(.fractionLength(2))) + " s"
	}

	private func percent(_ value: Double) -> String {
		value.formatted(.percent.precision(.fractionLength(0)))
	}
}
