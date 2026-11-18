import SwiftUI

/// One layout option: a round control with the layout's symbol, and its name below.
struct LayoutChoice: View {
	let style: SwitcherStyle
	let isSelected: Bool
	let onSelect: (SwitcherStyle) -> Void

	var body: some View {
		VStack(spacing: 4) {
			Button(style.title, systemImage: style.systemImage, action: choose)
				.buttonStyle(RoundIconButtonStyle(isOn: isSelected, diameter: ControlTileMetrics.layoutCircle))
				.symbolEffect(.bounce, value: isSelected)
			Text(style.shortTitle)
				.font(.caption)
				.bold(isSelected)
				.foregroundStyle(isSelected ? .primary : .secondary)
		}
		.sensoryFeedback(.selection, trigger: isSelected)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
	}

	private func choose() {
		onSelect(style)
	}
}
