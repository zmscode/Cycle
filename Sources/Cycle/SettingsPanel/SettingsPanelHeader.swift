import SwiftUI

/// The settings title, a button that opens `cycle.config` and a Quit button, in a row the height of the switcher's search bar
/// so the two line up side by side.
struct SettingsPanelHeader: View {
	let onOpenConfig: () -> Void
	let onQuit: () -> Void

	var body: some View {
		HStack {
			Text("Settings")
				.font(.headline)
			Spacer()
			Button("Open cycle.config", systemImage: "doc.text", action: onOpenConfig)
				.buttonStyle(RoundIconButtonStyle(isOn: false, diameter: 28))
				.help("Open cycle.config")
			Button("Quit Cycle", systemImage: "power", action: onQuit)
				.buttonStyle(RoundIconButtonStyle(isOn: false, diameter: 28))
				.help("Quit Cycle")
		}
		.padding(.horizontal, Theme.Panel.padding)
		.frame(height: Theme.Panel.searchHeight)
	}
}
