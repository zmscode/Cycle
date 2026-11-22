import SwiftUI

/// The overlay's content: the tiling board, and the dragged window under the pointer.
struct TilingOverlayView: View {
	let state: SwitcherState

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
				.position(drag.pointer)
			}
		}
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		.environment(\.colorScheme, .dark)
	}
}
