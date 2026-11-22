import SwiftUI

/// A preset slot no window has been dropped in yet.
struct EmptySlot: View {
	var body: some View {
		RoundedRectangle(cornerRadius: Theme.Tiling.tileRadius)
			.strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
			.background {
				RoundedRectangle(cornerRadius: Theme.Tiling.tileRadius).fill(.white.opacity(0.04))
			}
	}
}
