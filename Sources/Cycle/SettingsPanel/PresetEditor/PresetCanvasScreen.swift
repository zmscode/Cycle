import SwiftUI

/// The editor's little screen: a soft gradient wallpaper with a menu-bar sliver.
struct PresetCanvasScreen: View {
	static let menuBarHeight: CGFloat = 7

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 10, style: .continuous)
		shape
			.fill(
				LinearGradient(
					colors: [
						Color(red: 0.24, green: 0.25, blue: 0.52),
						Color(red: 0.12, green: 0.34, blue: 0.44),
						Color(red: 0.10, green: 0.18, blue: 0.30),
					],
					startPoint: .topLeading, endPoint: .bottomTrailing)
			)
			.opacity(0.75)
			.overlay(alignment: .top) {
				Rectangle()
					.fill(.white.opacity(0.10))
					.frame(height: Self.menuBarHeight)
			}
			.clipShape(shape)
			.overlay { shape.strokeBorder(.white.opacity(0.16)) }
			.shadow(color: .black.opacity(0.35), radius: 8, y: 3)
			.accessibilityHidden(true)
	}
}
