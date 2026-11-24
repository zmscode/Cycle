import SwiftUI

/// The window's picture, filling the frame and keeping the top (title bar, toolbar) in
/// view. Apps with no window, or no capture yet, show their icon instead.
struct WindowThumbnail: View {
	let window: SwitcherWindow
	let image: NSImage?
	let size: CGSize
	let isSelected: Bool

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Card.thumbRadius) }
	private var isDimmed: Bool { window.isMinimized || window.isAppHidden }

	var body: some View {
		ZStack {
			shape.fill(.white.opacity(0.06))
			if let image, !window.isWindowless {
				Image(nsImage: image)
					.resizable()
					.interpolation(.high)
					.aspectRatio(contentMode: .fill)
					.frame(width: size.width, height: size.height, alignment: .top)
					.saturation(isDimmed ? 0.3 : 1)
					.opacity(isDimmed ? 0.55 : 1)
					.accessibilityHidden(true)
			} else if let icon = window.icon {
				Image(nsImage: icon)
					.resizable()
					.aspectRatio(contentMode: .fit)
					// Larger with previews off, where the icon is the whole picture.
					.frame(width: min(size.height * (Settings.showPreviews ? 0.55 : 0.72), 84))
					.opacity(isDimmed ? 0.55 : 1)
					.accessibilityHidden(true)
			}
		}
		.frame(width: size.width, height: size.height)
		.clipShape(shape)
		.overlay {
			shape.strokeBorder(
				isSelected ? Theme.Colors.selection : .white.opacity(0.1),
				lineWidth: isSelected ? 3 : 1)
		}
		.overlay(alignment: .bottomLeading) {
			WindowStateBadge(window: window)
				.padding(8)
		}
		.shadow(color: .black.opacity(isSelected ? 0.35 : 0.2), radius: isSelected ? 8 : 4, y: 3)
	}
}
