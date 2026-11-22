import SwiftUI

/// Close, minimize and full screen as traffic lights, then quit after a hairline, in a
/// card's header row beside the window's icon and name. Dimmed until the card is selected
/// or under the pointer; glyphs show while the pointer is on the controls themselves.
struct WindowControls: View {
	let isActive: Bool
	let onAction: (CardAction) -> Void
	@State private var isHovering = false

	var body: some View {
		// The buttons' own padding spaces the dots; no extra gap, so their targets touch.
		HStack(spacing: 0) {
			ForEach(CardAction.trafficLights, id: \.self) { action in
				TrafficLightButton(action: action, showsGlyph: isHovering, onAction: onAction)
			}
			Divider()
				.frame(height: Theme.Controls.diameter)
			TrafficLightButton(action: .quit, showsGlyph: isHovering, onAction: onAction)
		}
		.fixedSize()
		.opacity(isActive || isHovering ? 1 : 0.45)
		.animation(.smooth(duration: 0.15), value: isActive)
		.onHover { isHovering = $0 }
	}
}
