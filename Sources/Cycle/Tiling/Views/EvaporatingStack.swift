import SwiftUI

/// Dragged windows let go where they can't land: they grow a little and fade out where
/// they were dropped (just fade, with Reduce Motion on).
struct EvaporatingStack: View {
	let windows: [SwitcherWindow]
	let images: [CGWindowID: NSImage]

	@State private var isGone = false
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		DraggedWindowStack(windows: windows, images: images, isOverTarget: false)
			.scaleEffect(isGone && !reduceMotion ? 1.25 : 1)
			.opacity(isGone ? 0 : 1)
			.onAppear {
				withAnimation(.easeOut(duration: Theme.Tiling.evaporateDuration)) { isGone = true }
			}
	}
}
