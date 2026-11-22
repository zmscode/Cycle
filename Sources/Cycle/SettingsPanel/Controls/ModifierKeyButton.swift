import SwiftUI

/// One modifier choice drawn as its key symbol in a round control.
struct ModifierKeyButton: View {
	let key: InitializerModifier
	let isSelected: Bool
	let onSelect: (InitializerModifier) -> Void

	var body: some View {
		Button(action: choose) {
			RoundIcon(isOn: isSelected) {
				Text(key.symbol).font(.title3)
			}
		}
		.buttonStyle(.plain)
		.help(key.name)
		.accessibilityLabel(key.name)
		.accessibilityAddTraits(isSelected ? .isSelected : [])
		.sensoryFeedback(.selection, trigger: isSelected)
	}

	private func choose() {
		onSelect(key)
	}
}
