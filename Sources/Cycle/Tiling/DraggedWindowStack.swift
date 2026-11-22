import SwiftUI

/// The dragged windows under the pointer: the one picked up in front, up to two more
/// fanned out behind it, and a count when there are several.
struct DraggedWindowStack: View {
	let windows: [SwitcherWindow]
	let images: [CGWindowID: NSImage]
	let isOverTarget: Bool

	var body: some View {
		ZStack {
			ForEach(Array(windows.prefix(3).enumerated().reversed()), id: \.element.id) {
				index, window in
				DraggedWindowGhost(
					window: window, image: images[window.id], isOverTarget: isOverTarget
				)
				.rotationEffect(.degrees(Double(index) * 4))
				.offset(x: CGFloat(index) * 8, y: CGFloat(index) * -6)
			}
		}
		.overlay(alignment: .topTrailing) {
			if windows.count > 1 {
				MarkBadge(number: windows.count)
					.offset(x: 10, y: -10)
			}
		}
		.allowsHitTesting(false)
		.accessibilityHidden(true)
	}
}
