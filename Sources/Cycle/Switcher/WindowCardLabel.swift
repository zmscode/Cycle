import SwiftUI

/// The app icon and window title, centred under the thumbnail, with the app name below
/// when the title is the window's own.
struct WindowCardLabel: View {
	let window: SwitcherWindow
	let isSelected: Bool

	private var showsAppName: Bool {
		!window.isWindowless && !window.title.isEmpty && window.title != window.appName
	}

	var body: some View {
		VStack(spacing: 1) {
			HStack(spacing: 6) {
				if let icon = window.icon {
					Image(nsImage: icon)
						.resizable()
						.frame(width: Theme.Card.iconSize, height: Theme.Card.iconSize)
						.accessibilityHidden(true)
				}
				Text(window.displayTitle)
					.font(.callout)
					.bold(isSelected)
					.foregroundStyle(isSelected ? .primary : .secondary)
			}
			if showsAppName {
				Text(window.appName)
					.font(.caption)
					.foregroundStyle(.tertiary)
			}
		}
		.lineLimit(1)
		.truncationMode(.middle)
	}
}
