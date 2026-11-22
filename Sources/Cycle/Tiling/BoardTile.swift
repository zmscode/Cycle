import SwiftUI

/// A window already tiled, drawn on the board in its place.
struct BoardTile: View {
	let window: SwitcherWindow?
	let image: NSImage?
	/// The window being dragged: shown faintly, since it's about to move.
	let isDragged: Bool

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Tiling.tileRadius) }

	var body: some View {
		ZStack {
			shape.fill(.white.opacity(0.08))
			if let image {
				Image(nsImage: image)
					.resizable()
					.interpolation(.medium)
					.aspectRatio(contentMode: .fill)
			} else if let icon = window?.icon {
				Image(nsImage: icon)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: 28)
			}
		}
		.clipShape(shape)
		.overlay { shape.strokeBorder(.white.opacity(0.18)) }
		.opacity(isDragged ? 0.35 : 0.85)
	}
}
