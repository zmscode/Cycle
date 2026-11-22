import SwiftUI

/// The dragged window, small, under the pointer. It fades a little over a drop target so
/// the highlight beneath it shows through.
struct DraggedWindowGhost: View {
	let window: SwitcherWindow
	let image: NSImage?
	let isOverTarget: Bool

	private var size: CGSize {
		let width = Theme.Tiling.ghostWidth
		return CGSize(width: width, height: (width / SwitcherLayout.aspect(of: window)).rounded())
	}

	var body: some View {
		WindowThumbnail(window: window, image: image, size: size, isSelected: true)
			.shadow(color: .black.opacity(0.35), radius: 12, y: 6)
			.opacity(isOverTarget ? 0.6 : 0.95)
			.scaleEffect(isOverTarget ? 0.85 : 1)
			.animation(Theme.Motion.fade, value: isOverTarget)
			.allowsHitTesting(false)
			.accessibilityHidden(true)
	}
}
