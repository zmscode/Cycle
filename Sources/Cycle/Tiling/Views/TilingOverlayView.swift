import SwiftUI

/// The overlay's content: the tiling board, and the dragged window under the pointer.
struct TilingOverlayView: View {
	let state: SwitcherState

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		ZStack(alignment: .topLeading) {
			if let drag = state.drag {
				TilingBoardCard(drag: drag, state: state)
				DraggedWindowStack(
					windows: drag.windowIDs.compactMap { id in
						state.windows.first { $0.id == id }
					},
					images: state.images, isOverTarget: drag.target != nil
				)
				// Over a target it shrinks and moves off to the lower right, so the slot
				// under the pointer stays in sight.
				.position(ghostCentre(for: drag))
				.animation(reduceMotion ? nil : Theme.Motion.fade, value: drag.target == nil)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.environment(\.colorScheme, .dark)
	}

	/// Centred on the pointer while carried; aside, its top-left corner just below and
	/// right of the pointer.
	private func ghostCentre(for drag: WindowDrag) -> CGPoint {
		guard drag.target != nil,
			let window = state.windows.first(where: { $0.id == drag.windowID })
		else { return drag.pointer }
		let size = DraggedWindowGhost.size(of: window, isOverTarget: true)
		let gap = Theme.Tiling.ghostAsideGap
		return CGPoint(
			x: drag.pointer.x + gap + size.width / 2, y: drag.pointer.y + gap + size.height / 2)
	}
}
