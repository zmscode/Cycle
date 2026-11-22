import SwiftUI

/// A glass edge: bright along the top where light catches it, fading toward the bottom.
/// Used as an overlay on glass surfaces instead of a flat stroke. With Increase Contrast
/// it's an even, solid edge.
struct SpecularBorder: View {
	let cornerRadius: CGFloat
	var intensity: Double = 1

	@Environment(\.colorSchemeContrast) private var contrast

	var body: some View {
		let increased = contrast == .increased
		RoundedRectangle(cornerRadius: cornerRadius)
			.strokeBorder(
				LinearGradient(
					colors: increased
						? [.white.opacity(0.7 * intensity), .white.opacity(0.55 * intensity)]
						: [.white.opacity(0.34 * intensity), .white.opacity(0.06 * intensity)],
					startPoint: .top, endPoint: .bottom),
				lineWidth: increased ? 1.5 : 1
			)
			.allowsHitTesting(false)
	}
}
