import SwiftUI

/// The dragged windows under the pointer: the one picked up in front, up to two more
/// fanned out behind it, and a count when there are several.
struct DraggedWindowStack: View {
	let windows: [SwitcherWindow]
	let images: [CGWindowID: NSImage]
	let isOverTarget: Bool

	/// How far each window behind is fanned out.
	private var fan: CGSize {
		isOverTarget ? CGSize(width: 4, height: 3) : CGSize(width: 8, height: 6)
	}

	var body: some View {
		ZStack {
			ForEach(Array(windows.prefix(3).enumerated().reversed()), id: \.element.id) {
				index, window in
				DraggedWindowGhost(
					window: window, image: images[window.id], isOverTarget: isOverTarget
				)
				.rotationEffect(.degrees(Double(index) * 4))
				.offset(x: CGFloat(index) * fan.width, y: CGFloat(index) * -fan.height)
			}
		}
		.overlay(alignment: .topTrailing) {
			if windows.count > 1 {
				if isOverTarget {
					BoardTileNumber(number: windows.count).offset(x: 6, y: -6)
				} else {
					MarkBadge(number: windows.count).offset(x: 10, y: -10)
				}
			}
		}
		.allowsHitTesting(false)
		.accessibilityHidden(true)
	}
}
