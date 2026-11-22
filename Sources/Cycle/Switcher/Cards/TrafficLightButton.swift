import SwiftUI

/// One window control. The label keeps its title for VoiceOver and tooltips; the style
/// draws it as a coloured dot with the glyph shown on hover.
struct TrafficLightButton: View {
	let action: CardAction
	let showsGlyph: Bool
	let onAction: (CardAction) -> Void

	var body: some View {
		Button(action.title, systemImage: action.systemImage, action: perform)
			.buttonStyle(TrafficLightButtonStyle(color: action.color, showsGlyph: showsGlyph))
			.help(action.title)
	}

	private func perform() {
		onAction(action)
	}
}
