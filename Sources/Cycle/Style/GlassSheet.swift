import SwiftUI

/// Cycle's top-level surface: dark-tinted Liquid Glass with a top-lit rim, always in the
/// dark appearance. The switcher and the settings panel are both drawn on it, so they
/// read as one app.
struct GlassSheet: ViewModifier {
	var cornerRadius: CGFloat = Theme.Panel.radius

	func body(content: Content) -> some View {
		content
			// A light dark tint keeps text legible over bright wallpapers.
			.glassEffect(
				.regular.tint(.black.opacity(0.22)).interactive(false),
				in: RoundedRectangle(cornerRadius: cornerRadius))
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
