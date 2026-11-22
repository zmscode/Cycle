import AppKit
import RiftCore

/// A divider being dragged: on the real screen (a grip between tiled windows) or on the
/// board. Pointer positions are in window-server coordinates on the real screen; the
/// board converts its own first.
struct DividerResize {
	let display: String
	let screen: NSScreen
	/// The layout as the drag goes, laid out on the real screen.
	var board: TilingBoard
	var drag: RiftDividerDrag
	/// The windows to move, once they've been read.
	var windows: [SwitcherWindow]?

	init?(
		display: String, screen: NSScreen, layout: RiftLayout<CGWindowID>, splitID: UUID,
		pointer: CGPoint
	) {
		let board = TilingBoard.offscreen(on: screen, layout: layout)
		guard let divider = board.geometry?.divider(splitID) else { return nil }
		self.display = display
		self.screen = screen
		self.board = board
		drag = RiftDividerDrag(hit: RiftDividerHit(dividers: [divider]), pointer: pointer)
	}

	/// Moves the divider to `pointer`. Returns true when it just snapped to the middle.
	mutating func move(to pointer: CGPoint) -> Bool {
		guard let layout = board.layout, let geometry = board.geometry else { return false }
		let result = drag.update(pointer: pointer, geometry: geometry, metrics: board.metrics)
		board.layout = layout.applying(result.updates)
		return result.didSnap
	}
}
