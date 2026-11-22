import AppKit
import RiftCore

/// The tiling board during a session: whenever the switcher's screen has a tiled layout
/// the board shows under the switcher, with grips on its dividers to resize the windows.
/// Picking up a window uses the same board to drop it on. A right-click outside the
/// switcher undoes the last tiling change.
extension SwitcherController {
	/// Wires the board's grips and layout updates. Called once.
	func setUpBoard() {
		tiling.onLayoutChanged = { [weak self] display, layout in
			self?.layoutChanged(display, layout)
		}
		tiling.onUnfitChanged = { [weak self] unfit in self?.state.unfitIDs = unfit }
		boardDividers.onBegin = { [weak self] item, pointer in
			guard let self, let real = self.realPoint(fromBoard: pointer) else { return }
			self.tiling.beginResize(display: item.display, splitID: item.splitID, pointer: real)
		}
		boardDividers.onMove = { [weak self] pointer in
			guard let self, let real = self.realPoint(fromBoard: pointer) else { return }
			self.tiling.moveResize(to: real)
		}
		boardDividers.onEnd = { [weak self] in self?.tiling.endResize() }
		boardDividers.onReset = { [weak self] item in
			self?.tiling.resetDivider(display: item.display, splitID: item.splitID)
		}
	}

	/// Shows the board under the switcher if its screen has a tiled layout (or moves it,
	/// when the switcher has changed size), else hides it.
	func showBoard() {
		guard isActive, state.drag == nil, let frame = panelFrame, let screen = panelScreen,
			let layout = tiling.layout(for: screen, windows: state.recentOrder)
		else { return hideBoard() }
		let placement = tilingOverlay.show(
			on: screen, below: frame, presets: Settings.tilingPresets)
		state.board = TilingBoard(
			layout: layout, visible: screen.visibleFrameTopLeft, placement: placement,
			displayScale: screen.backingScaleFactor)
		state.unfitIDs = tiling.unfit
		showBoardTiles()
		showBoardDividers()
	}

	func hideBoard() {
		state.board = nil
		boardDividers.hideAll()
		hideBoardTiles()
		if state.drag == nil { tilingOverlay.hide() }
	}

	/// Grips on the board's dividers (not while a window is being dragged over it).
	func showBoardDividers() {
		guard state.drag == nil, let board = state.board, let screen = panelScreen,
			let display = screen.displayUUID
		else { return boardDividers.hideAll() }
		let items = (board.geometry?.dividers ?? []).map { divider in
			let line = board.toBoard(divider.line)
			let rect = Self.widened(line, axis: divider.axis, to: Theme.Tiling.boardGripThickness)
			return DividerHandleItem(
				display: display, splitID: divider.splitID, axis: divider.axis,
				frame: tilingOverlay.global(rect))
		}
		boardDividers.show(items)
	}

	/// A display's layout changed (a drop, a divider drag, a window closing, undo).
	private func layoutChanged(_ display: String, _ layout: RiftLayout<CGWindowID>?) {
		guard isActive, panelScreen?.displayUUID == display else { return }
		guard let layout else { return hideBoard() }
		guard var board = state.board else { return showBoard() }
		board.layout = layout
		state.board = board
		showBoardDividers()
	}

	/// A grip's pointer (window-server coordinates on the board) on the real screen.
	private func realPoint(fromBoard pointer: CGPoint) -> CGPoint? {
		guard let board = state.board else { return nil }
		return board.toScreen(tilingOverlay.local(windowServer: pointer))
	}

	/// `rect` grown across `axis` to at least `thickness`, keeping its centre.
	private static func widened(_ rect: CGRect, axis: RiftAxis, to thickness: CGFloat) -> CGRect {
		switch axis {
		case .horizontal:
			let grow = max(0, thickness - rect.width) / 2
			return rect.insetBy(dx: -grow, dy: 0)
		case .vertical:
			let grow = max(0, thickness - rect.height) / 2
			return rect.insetBy(dx: 0, dy: -grow)
		}
	}

	/// The tiled layout of the screen under the pointer, as preset slots numbered from 0
	/// (for the preset editor's "This Screen").
	func currentPresetLayout() -> RiftLayout<Int>? {
		guard let layout = tiling.layout(for: SwitcherPanel.screenUnderPointer(), windows: [])
		else { return nil }
		let ids = layout.paneIDs
		let number = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
		return layout.mapPanes { number[$0] ?? 0 }
	}

	// MARK: Undo

	/// A right-click during a session, at `point` (window-server coordinates). Outside
	/// Cycle's own panels it undoes the last tiling change and is swallowed (so the app
	/// underneath doesn't open a menu); returns whether it was.
	func rightClicked(at point: CGPoint) -> Bool {
		guard isActive else { return false }
		let height = NSScreen.screens.first?.frame.height ?? 0
		let appKit = CGPoint(x: point.x, y: height - point.y)
		if let frame = panelFrame, frame.contains(appKit) { return false }
		// The board's tiles have a menu of their own.
		if isOnBoard(appKit) { return false }
		if settingsPanel.isVisible, settingsPanel.frame?.contains(appKit) == true { return false }
		tiling.undo { [weak self] label in
			self?.showNotice(label.map { "Undid \($0)" } ?? "Nothing to undo")
		}
		return true
	}
}
