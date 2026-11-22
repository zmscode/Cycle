import SwiftUI

/// The last tile in the presets grid: make a new preset.
struct NewPresetTile: View {
	let action: () -> Void

	@State private var isHovered = false

	var body: some View {
		Button(action: action) {
			VStack(spacing: 4) {
				RoundedRectangle(cornerRadius: 8)
					.strokeBorder(
						isHovered ? Theme.Colors.mark : .white.opacity(0.3),
						style: StrokeStyle(lineWidth: 1.2, dash: [4, 3])
					)
					.frame(width: 54, height: 37)
					.overlay {
						Image(systemName: "plus")
							.font(.body.weight(.semibold))
							.foregroundStyle(isHovered ? Theme.Colors.mark : .secondary)
					}
				Text("New")
					.font(.caption2)
					.foregroundStyle(isHovered ? .primary : .secondary)
			}
			.contentShape(Rectangle())
		}
		.buttonStyle(.plain)
		.onHover { isHovered = $0 }
		.help("Make a new preset")
		.accessibilityLabel("New preset")
	}
}
