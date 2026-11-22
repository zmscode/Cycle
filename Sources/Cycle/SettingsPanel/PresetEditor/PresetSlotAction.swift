import SwiftUI

/// A round button on a hovered slot: split it, or remove it.
struct PresetSlotAction: View {
	let title: String
	let systemImage: String
	let action: () -> Void

	@State private var isHovered = false

	var body: some View {
		Button(action: action) {
			Image(systemName: systemImage)
				.font(.system(size: 9, weight: .bold))
				.foregroundStyle(.white)
				.frame(width: 20, height: 20)
				.background(
					Circle().fill(isHovered ? Theme.Colors.mark : .white.opacity(0.18))
				)
				.contentShape(Circle())
		}
		.buttonStyle(.plain)
		.onHover { isHovered = $0 }
		.help(title)
		.accessibilityLabel(title)
	}
}
