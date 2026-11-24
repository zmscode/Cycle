import SwiftUI

/// A grid card with previews off: the app's icon over the window's title and app name,
/// like the system's own switcher. The window controls sit in a row above the icon,
/// showing while the card is selected or under the pointer.
struct WindowIconCard: View {
	let window: SwitcherWindow
	let isSelected: Bool
	let isActive: Bool
	let markNumber: Int?
	let onAction: (CardAction) -> Void

	private var isDimmed: Bool { window.isMinimized || window.isAppHidden }

	private var showsAppName: Bool {
		!window.isWindowless && !window.title.isEmpty && window.title != window.appName
	}

	var body: some View {
		VStack(spacing: Theme.Card.labelGap) {
			HStack {
				if isActive, !window.isWindowless {
					WindowControls(isActive: true, onAction: onAction)
						.transition(.opacity)
				}
			}
			.frame(width: Theme.Card.iconCardWidth, height: Theme.Card.iconCardControls)
			.padding(.bottom, -Theme.Card.labelGap)
			icon
				.frame(width: Theme.Card.iconCardIcon, height: Theme.Card.iconCardIcon)
				.markBadge(markNumber)
			VStack(spacing: 1) {
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
			.multilineTextAlignment(.center)
			.frame(width: Theme.Card.iconCardWidth, height: Theme.Card.labelHeight, alignment: .top)
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
	}

	private var icon: some View {
		ZStack(alignment: .bottomTrailing) {
			if let image = window.icon {
				Image(nsImage: image)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.saturation(isDimmed ? 0.3 : 1)
					.opacity(isDimmed ? 0.55 : 1)
					.accessibilityHidden(true)
			}
			if let state {
				Image(systemName: state.symbol)
					.font(.system(size: 14, weight: .bold))
					.symbolRenderingMode(.palette)
					.foregroundStyle(.white, .black.opacity(0.65))
					.offset(x: 4, y: 4)
					.help(state.title)
					.accessibilityLabel(state.title)
			}
		}
	}

	/// Minimized, hidden or on another Space, as a small symbol on the icon.
	private var state: (title: String, symbol: String)? {
		if window.isMinimized { return ("Minimized", "minus.circle.fill") }
		if window.isAppHidden { return ("Hidden", "eye.slash.circle.fill") }
		if window.isOnOtherSpace { return ("Other Space", "square.on.square.circle.fill") }
		return nil
	}
}
