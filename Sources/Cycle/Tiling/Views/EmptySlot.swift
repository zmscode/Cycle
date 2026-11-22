import SwiftUI

/// A preset slot no window has been dropped in yet.
struct EmptySlot: View {
	@Environment(\.colorSchemeContrast) private var contrast

	var body: some View {
		let increased = contrast == .increased
		RoundedRectangle(cornerRadius: Theme.Tiling.tileRadius)
			.strokeBorder(
				.white.opacity(increased ? 0.7 : 0.3),
				style: StrokeStyle(lineWidth: increased ? 1.5 : 1, dash: [4, 3])
			)
			.background {
				RoundedRectangle(cornerRadius: Theme.Tiling.tileRadius)
					.fill(.white.opacity(increased ? 0.1 : 0.04))
			}
			.accessibilityLabel("Empty slot")
	}
}
