import SwiftUI

/// A section inside a glass sheet: a faint top-lit fill with a softer rim. App groups in
/// the switcher and tiles in the settings panel both use it; `isHighlighted` brightens it
/// for the app being switched to, or a tile under the pointer.
struct InsetSurface: ViewModifier {
	let cornerRadius: CGFloat
	var isHighlighted = false

	@Environment(\.colorSchemeContrast) private var contrast

	func body(content: Content) -> some View {
		// Increase Contrast: brighter fills, so sections stand apart from the sheet.
		let boost = contrast == .increased ? 2.0 : 1.0
		content
			.background {
				RoundedRectangle(cornerRadius: cornerRadius)
					.fill(
						LinearGradient(
							colors: [
								.white.opacity((isHighlighted ? 0.12 : 0.07) * boost),
								.white.opacity((isHighlighted ? 0.06 : 0.03) * boost),
							],
							startPoint: .top, endPoint: .bottom))
			}
			.overlay {
				SpecularBorder(cornerRadius: cornerRadius, intensity: isHighlighted ? 1 : 0.6)
			}
			.animation(.smooth(duration: 0.15), value: isHighlighted)
	}
}

extension View {
	func insetSurface(cornerRadius: CGFloat, isHighlighted: Bool = false) -> some View {
		modifier(InsetSurface(cornerRadius: cornerRadius, isHighlighted: isHighlighted))
	}
}
