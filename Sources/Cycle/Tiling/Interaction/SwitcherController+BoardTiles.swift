import AppKit

/// Tiles on the board can be picked up during a session: dropped on another tile they
/// swap, on an edge they move there, and off the board they leave the layout. A
/// right-click on a tile offers "Remove from Layout" and "Close Window".
extension SwitcherController {
	/// Wires the board's hit layer. Called once.
	func setUpBoardTiles() {
		let tiles = boardTilePanel.tiles
		tiles.tileAt = { [weak self] point in self?.boardTile(at: point) }
		tiles.onBegin = { [weak self] id in self?.beginDrag(id, fromBoard: true) }
		tiles.onMove = { [weak self] point in self?.moveDrag(to: point) }
		tiles.onEnd = { [weak self] in self?.endDrag() }
		tiles.menuFor = { [weak self] id in self?.menu(forTile: id) }
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

	private func menu(forTile id: CGWindowID) -> NSMenu? {
		let window = state.recentOrder.first { $0.id == id }
		let menu = NSMenu()
		if let window {
			let title = NSMenuItem(title: window.appName, action: nil, keyEquivalent: "")
			title.isEnabled = false
			menu.addItem(title)
			menu.addItem(.separator())
		}
		menu.addItem(
			ClosureMenuItem("Remove from Layout", systemImage: "rectangle.badge.minus") {
				[weak self] in
				self?.untile(id)
			})
		if let window {
			menu.addItem(
				ClosureMenuItem("Close Window", systemImage: "xmark.rectangle") {
					WindowActions.close(window)
				})
		}
		return menu
	}

	/// Takes a window out of its layout, leaving it where it is.
	func untile(_ id: CGWindowID) {
		tiling.untile(id)
		let name = state.recentOrder.first { $0.id == id }?.appName ?? "Window"
		showNotice("\(name) untiled")
	}
}
