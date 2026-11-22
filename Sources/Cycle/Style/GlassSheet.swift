import SwiftUI

/// Cycle's top-level surface: dark-tinted Liquid Glass with a top-lit rim, always in the
/// dark appearance. The switcher and the settings panel are both drawn on it, so they
/// read as one app. With Reduce Transparency on it's an opaque window background instead,
/// and with Increase Contrast its rim is solid.
struct GlassSheet: ViewModifier {
	var cornerRadius: CGFloat = Theme.Panel.radius

	@Environment(\.accessibilityReduceTransparency) private var reduceTransparency

	func body(content: Content) -> some View {
		let shape = RoundedRectangle(cornerRadius: cornerRadius)
		Group {
			if reduceTransparency {
				content.background(Color(nsColor: .windowBackgroundColor), in: shape)
			} else {
				// A light dark tint keeps text legible over bright wallpapers.
				content.glassEffect(
					.regular.tint(.black.opacity(0.22)).interactive(false), in: shape)
			}
		}
		.overlay {
			SpecularBorder(cornerRadius: cornerRadius)
		}
		.environment(\.colorScheme, .dark)
	}
}

extension View {
	func glassSheet(cornerRadius: CGFloat = Theme.Panel.radius) -> some View {
		modifier(GlassSheet(cornerRadius: cornerRadius))
	}
}
