import SwiftUI

/// Close, minimize and full screen as traffic lights, then quit after a hairline, on a
/// small glass capsule over the thumbnail. Glyphs show while the pointer is on it.
struct WindowControls: View {
	let onAction: (CardAction) -> Void
	@State private var isHovering = false

	var body: some View {
		HStack(spacing: Theme.Controls.spacing) {
			ForEach(CardAction.trafficLights, id: \.self) { action in
				TrafficLightButton(action: action, showsGlyph: isHovering, onAction: onAction)
			}
			Divider()
				.frame(height: Theme.Controls.diameter)
			TrafficLightButton(action: .quit, showsGlyph: isHovering, onAction: onAction)
		}
		.padding(.horizontal, 6)
		.padding(.vertical, 4)
		.glassEffect(.regular.interactive(false), in: .capsule)
		.environment(\.colorScheme, .dark)
		.onHover { isHovering = $0 }
	}
}
