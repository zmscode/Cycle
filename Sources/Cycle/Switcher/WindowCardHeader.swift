import SwiftUI

/// A grid card's top row: the window controls, then the app icon with the window title
/// over the app name. Every card's header is the same height and sits at the same place,
/// so controls, icons and names line up across a row whatever size the previews are.
struct WindowCardHeader: View {
	let window: SwitcherWindow
	let isActive: Bool
	let isSelected: Bool
	let onAction: (CardAction) -> Void

	private var showsAppName: Bool {
		!window.isWindowless && !window.title.isEmpty && window.title != window.appName
	}

	var body: some View {
		HStack(spacing: 8) {
			if !window.isWindowless {
				WindowControls(isActive: isActive, onAction: onAction)
			}
			if let icon = window.icon {
				Image(nsImage: icon)
					.resizable()
					.frame(width: Theme.Card.iconSize, height: Theme.Card.iconSize)
					.accessibilityHidden(true)
			}
			VStack(alignment: .leading, spacing: 0) {
				Text(window.displayTitle)
					.font(.callout)
					.bold(isSelected)
					.foregroundStyle(isSelected ? .primary : .secondary)
				if showsAppName {
					Text(window.appName)
						.font(.caption)
						.foregroundStyle(.tertiary)
				}
			}
			.lineLimit(1)
			.truncationMode(.middle)
			Spacer(minLength: 0)
		}
	}
}
