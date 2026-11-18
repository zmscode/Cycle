import SwiftUI

/// A button drawn as a `RoundIcon` from its label's icon, pressing in slightly on click.
struct RoundIconButtonStyle: ButtonStyle {
	let isOn: Bool
	var diameter: CGFloat = ControlTileMetrics.circle

	func makeBody(configuration: Configuration) -> some View {
		RoundIcon(isOn: isOn, diameter: diameter) {
			configuration.label
				.labelStyle(.iconOnly)
				.font(.body.bold())
		}
		.scaleEffect(configuration.isPressed ? 0.92 : 1)
		.animation(.smooth(duration: 0.12), value: configuration.isPressed)
		.contentShape(.circle)
	}
}
