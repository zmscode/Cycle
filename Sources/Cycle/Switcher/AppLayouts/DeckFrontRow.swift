import SwiftUI

/// The front window's controls and title on a deck card, with where it sits in the stack
/// ("2 of 3") when there's more than one.
struct DeckFrontRow: View {
	let window: SwitcherWindow
	let position: Int
	let count: Int
	let isActive: Bool
	let isSelected: Bool
	let onAction: (CardAction) -> Void

	var body: some View {
		HStack(spacing: 6) {
			if !window.isWindowless {
				WindowControls(isActive: isActive, onAction: onAction)
			}
			Text(window.isWindowless ? "Open App" : window.displayTitle)
				.font(.caption)
				.bold(isSelected)
				.foregroundStyle(isSelected ? .primary : .secondary)
				.lineLimit(1)
				.truncationMode(.tail)
			Spacer(minLength: 4)
			if count > 1 {
				Text("\(position) of \(count)")
					.font(.caption2.monospacedDigit())
					.foregroundStyle(.tertiary)
			}
		}
		.padding(.horizontal, Theme.Card.inset)
		.frame(height: Theme.Group.labelHeight)
	}
}
