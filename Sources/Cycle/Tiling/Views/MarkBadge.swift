import SwiftUI

/// The number on a window right-clicked for tiling: its place in the order the marked
/// windows fill a preset's slots.
struct MarkBadge: View {
	let number: Int

	var body: some View {
		Text(number, format: .number)
			.font(.caption.bold().monospacedDigit())
			.foregroundStyle(.white)
			.frame(minWidth: 22, minHeight: 22)
			.background(Theme.Colors.mark, in: Circle())
			.overlay { Circle().strokeBorder(.white.opacity(0.7), lineWidth: 1.5) }
			.shadow(color: .black.opacity(0.3), radius: 3, y: 1)
			.accessibilityLabel("Marked for tiling, \(number)")
	}
}

extension View {
	/// The mark badge in the top-right corner, when `number` is set.
	func markBadge(_ number: Int?) -> some View {
		overlay(alignment: .topTrailing) {
			if let number {
				MarkBadge(number: number)
					.offset(x: 6, y: -6)
					.transition(.scale.combined(with: .opacity))
			}
		}
		.animation(Theme.Motion.fade, value: number)
	}
}
