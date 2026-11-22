import SwiftUI

/// The note at the foot of the switcher after a tiling change: what happened (the preset
/// used, any tiled window left out), and an Undo button naming what it reverses. It stays
/// while the pointer is on it.
struct TilingNotice: View {
	let note: TilingNote
	let onUndo: () -> Void
	let onHover: (Bool) -> Void

	@Environment(\.colorSchemeContrast) private var contrast

	var body: some View {
		HStack(spacing: 10) {
			Label(note.text, systemImage: "rectangle.split.3x1")
				.font(.callout.weight(.medium))
			if let undo = note.undoLabel {
				Button(action: onUndo) {
					Label("Undo \(undo)", systemImage: "arrow.uturn.backward")
						.font(.callout.weight(.semibold))
						.padding(.horizontal, 10)
						.frame(minHeight: 24)
						.background(.white.opacity(contrast == .increased ? 0.3 : 0.14), in: .capsule)
						.contentShape(.capsule)
				}
				.buttonStyle(.plain)
				.help("Undo \(undo)")
			}
		}
		.padding(.leading, 14)
		.padding(.trailing, note.undoLabel == nil ? 14 : 6)
		.padding(.vertical, 6)
		.background(.black.opacity(contrast == .increased ? 0.85 : 0.6), in: .capsule)
		.overlay {
			Capsule().strokeBorder(.white.opacity(contrast == .increased ? 0.5 : 0.15))
		}
		.onHover(perform: onHover)
		.environment(\.colorScheme, .dark)
		.accessibilityElement(children: .contain)
	}
}
