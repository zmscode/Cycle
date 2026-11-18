import SwiftUI

/// Draws a button as a traffic-light dot: the label's icon only, shown when `showsGlyph`.
struct TrafficLightButtonStyle: ButtonStyle {
	let color: Color
	let showsGlyph: Bool

	func makeBody(configuration: Configuration) -> some View {
		configuration.label
			.labelStyle(.iconOnly)
			.font(.system(size: 7).bold())
			.foregroundStyle(.black.opacity(0.6))
			.opacity(showsGlyph ? 1 : 0)
			.frame(width: Theme.Controls.diameter, height: Theme.Controls.diameter)
			.background(color, in: .circle)
			.overlay {
				Circle().strokeBorder(.black.opacity(0.18), lineWidth: 0.5)
			}
			.brightness(configuration.isPressed ? -0.15 : 0)
			// A little larger than the dot, so it's easier to hit.
			.padding(2)
			.contentShape(.circle)
	}
}
