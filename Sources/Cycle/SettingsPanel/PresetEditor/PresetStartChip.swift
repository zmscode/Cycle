import SwiftUI

/// A starting point in the editor: a built-in preset's picture, or the screen's own layout.
struct PresetStartChip: View {
	let title: String
	let preset: TilingPreset
	let action: () -> Void

	@State private var isHovered = false

	var body: some View {
		Button(action: action) {
			VStack(spacing: 3) {
				PresetThumbnail(preset: preset, mainShare: Settings.tilingMainShare)
					.frame(width: 34, height: 21)
					.padding(3)
					.background(
						RoundedRectangle(cornerRadius: 6)
							.fill(.white.opacity(isHovered ? 0.14 : 0.06)))
				Text(title)
					.font(.system(size: 9, weight: .medium))
					.foregroundStyle(isHovered ? .primary : .secondary)
					.lineLimit(1)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.onHover { isHovered = $0 }
		.help("Start from \(title)")
		.accessibilityLabel("Start from \(title)")
	}
}
