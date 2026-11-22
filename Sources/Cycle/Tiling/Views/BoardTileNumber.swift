import SwiftUI

/// A dragged window's number on its tile in the board's preview: small enough for the
/// board's little tiles, unlike the switcher's mark badge.
struct BoardTileNumber: View {
	let number: Int

	var body: some View {
		Text(number, format: .number)
			.font(.system(size: 10, weight: .bold).monospacedDigit())
			.foregroundStyle(.white)
			.frame(minWidth: 16, minHeight: 16)
			.background(Theme.Colors.mark, in: Circle())
			.accessibilityHidden(true)
	}
}
