import SwiftUI

/// The gear at the top left of the switcher, opening Cycle's settings beneath it.
struct SettingsButton: View {
	let isOpen: Bool
	let onToggle: () -> Void

	var body: some View {
		Button("Settings", systemImage: "gearshape.fill", action: onToggle)
			.buttonStyle(RoundIconButtonStyle(isOn: isOpen, diameter: 28))
			.help("Cycle Settings")
			.accessibilityAddTraits(isOpen ? .isSelected : [])
	}
}
