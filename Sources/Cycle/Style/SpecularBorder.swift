import SwiftUI

/// A glass edge: bright along the top where light catches it, fading toward the bottom.
/// Used as an overlay on glass surfaces instead of a flat stroke.
struct SpecularBorder: View {
	let cornerRadius: CGFloat
	var intensity: Double = 1

	var body: some View {
		RoundedRectangle(cornerRadius: cornerRadius)
			.strokeBorder(
				LinearGradient(
					colors: [.white.opacity(0.34 * intensity), .white.opacity(0.06 * intensity)],
					startPoint: .top, endPoint: .bottom),
				lineWidth: 1
			)
			.allowsHitTesting(false)
	}
}
