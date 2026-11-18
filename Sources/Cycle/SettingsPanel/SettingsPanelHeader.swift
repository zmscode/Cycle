import SwiftUI

/// Cycle's icon and name with the active shortcut, and a Quit button.
struct SettingsPanelHeader: View {
	let modifier: InitializerModifier
	let onQuit: () -> Void

	var body: some View {
		HStack(spacing: 10) {
			Image(nsImage: NSApp.applicationIconImage)
				.resizable()
				.frame(width: 24, height: 24)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: 0) {
				Text("Cycle").font(.headline)
				Text("Switch windows with \(modifier.symbol)Tab")
					.font(.caption)
					.foregroundStyle(.secondary)
			}
			Spacer()
			Button("Quit Cycle", systemImage: "power", action: onQuit)
				.buttonStyle(RoundIconButtonStyle(isOn: false, diameter: 28))
				.help("Quit Cycle")
		}
		.padding(.horizontal, Theme.Panel.padding)
		// The switcher's header height, so the two rows line up side by side.
		.frame(height: Theme.Panel.searchHeight)
	}
}
