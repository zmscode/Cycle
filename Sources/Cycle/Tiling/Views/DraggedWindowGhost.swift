import SwiftUI

/// The dragged window, small, under the pointer. Over a drop target it shrinks (and the
/// overlay moves it aside) so the board under the pointer stays visible.
struct DraggedWindowGhost: View {
	let window: SwitcherWindow
	let image: NSImage?
	let isOverTarget: Bool

	/// The ghost's size for `window`: full while carried, small while aside over a target.
	static func size(of window: SwitcherWindow, isOverTarget: Bool) -> CGSize {
		let width =
			Theme.Tiling.ghostWidth * (isOverTarget ? Theme.Tiling.ghostAsideScale : 1)
		return CGSize(width: width, height: (width / SwitcherLayout.aspect(of: window)).rounded())
	}

	private var size: CGSize { Self.size(of: window, isOverTarget: isOverTarget) }

	var body: some View {
		WindowThumbnail(window: window, image: image, size: size, isSelected: true)
			.shadow(color: .black.opacity(0.35), radius: 12, y: 6)
			.opacity(isOverTarget ? 0.9 : 0.95)
			.animation(Theme.Motion.fade, value: isOverTarget)
			.allowsHitTesting(false)
			.accessibilityHidden(true)
	}
}
