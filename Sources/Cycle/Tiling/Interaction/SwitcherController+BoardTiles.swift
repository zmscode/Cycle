import AppKit

/// Tiles on the board can be picked up during a session: dropped on another tile they
/// swap, on an edge they move there, and off the board they leave the layout. A
/// right-click on a tile opens the tiling menu (see +Menus).
extension SwitcherController {
	/// Wires the board's hit layer. Called once.
	func setUpBoardTiles() {
		let tiles = boardTilePanel.tiles
		tiles.tileAt = { [weak self] point in self?.boardTile(at: point) }
		tiles.onBegin = { [weak self] id in self?.beginDrag(id, fromBoard: true) }
		tiles.onMove = { [weak self] point in self?.moveDrag(to: point) }
		tiles.onEnd = { [weak self] in self?.endDrag() }
		tiles.onRightClick = { [weak self] id, event in
			guard let self else { return }
			self.showMenu(for: id, onBoard: true, event: event, in: self.boardTilePanel.tiles)
		}
	}

	/// Puts the hit layer over the board while it shows (and keeps it there during a drag
	/// that began on it, which it's tracking).
	func showBoardTiles() {
		guard let board = state.board, !state.isShowingSettings else { return hideBoardTiles() }
		boardTilePanel.setFrame(tilingOverlay.global(board.rect).integral, display: true)
		boardTilePanel.orderFrontRegardless()
	}

	func hideBoardTiles() {
		guard state.drag?.fromBoard != true else { return }
		boardTilePanel.orderOut(nil)
	}

	/// Whether a point (AppKit screen coordinates) is on the board's card.
	func isOnBoard(_ point: CGPoint) -> Bool {
		guard let board = state.drag?.board ?? state.board else { return false }
		return tilingOverlay.global(board.placement.card).contains(point)
	}

	/// The tiled window drawn under `point` (AppKit screen coordinates).
	private func boardTile(at point: CGPoint) -> CGWindowID? {
		guard state.drag == nil, let board = state.board else { return nil }
		let local = tilingOverlay.local(point)
		return board.frames.first { board.toBoard($0.value).contains(local) }?.key
	}

	/// Takes a window out of its layout, leaving it where it is.
	func untile(_ id: CGWindowID) {
		tiling.untile(id)
		showNotice("\(name(of: id)) untiled")
	}
}
