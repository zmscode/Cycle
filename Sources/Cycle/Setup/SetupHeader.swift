import SwiftUI

/// Cycle's icon, the title, and how far through setup the user is.
struct SetupHeader: View {
	let completed: Int

	var body: some View {
		VStack(spacing: 10) {
			Image(nsImage: NSApp.applicationIconImage)
				.resizable()
				.frame(width: 72, height: 72)
				.accessibilityHidden(true)
			Text("Set up Cycle")
				.font(.title.bold())
			Text("Two permissions turn ⌘Tab into a window switcher with live previews.")
				.font(.body)
				.foregroundStyle(.secondary)
				.multilineTextAlignment(.center)
				.fixedSize(horizontal: false, vertical: true)
			Text("\(completed) of 2 done")
				.font(.callout.monospacedDigit())
				.foregroundStyle(.tertiary)
		}
		.frame(maxWidth: .infinity)
	}
}
