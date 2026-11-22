import SwiftUI

/// A short note at the foot of the switcher after tiling from the keyboard: the preset
/// used, and any tiled window it left out.
struct TilingNotice: View {
	let text: String

	var body: some View {
		Label(text, systemImage: "rectangle.split.3x1")
			.font(.callout.weight(.medium))
			.padding(.horizontal, 14)
			.padding(.vertical, 7)
			.background(.black.opacity(0.55), in: .capsule)
			.overlay { Capsule().strokeBorder(.white.opacity(0.15)) }
			.environment(\.colorScheme, .dark)
			.accessibilityAddTraits(.updatesFrequently)
	}
}
