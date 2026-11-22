import AppKit
import RiftCore

/// Divider drags: the windows on both sides follow the pointer live (each move waits for
/// the last to land rather than queueing), and letting go saves the layout.
extension TilingCoordinator {
	/// Starts dragging `splitID` on `display` from `pointer` (window-server coordinates).
	func beginResize(display: String, splitID: UUID, pointer: CGPoint) {
		guard resize == nil, let screen = NSScreen.screen(uuid: display),
			let layout = store.layout(for: display),
			let session = DividerResize(
				display: display, screen: screen, layout: layout, splitID: splitID,
				pointer: pointer)
		else { return }
		record(display, label: "Resize")
		resize = session
		loader.load(includeWindowless: false) { [weak self] snapshot in
			MainActor.assumeIsolated { self?.resize?.windows = snapshot.windows }
		}
	}

	func moveResize(to pointer: CGPoint) {
		guard var session = resize else { return }
		if session.move(to: pointer) {
			Haptics.aligned()
		}
		resize = session
		onLayoutChanged?(session.display, session.board.layout)
		showDividers(for: session.display, layout: session.board.layout)
		placeLive(session.board)
	}

	func endResize() {
		guard let session = resize else { return }
		resize = nil
		guard let layout = session.board.layout else { return }
		// Nothing moved: no change to undo.
		if layout == store.layout(for: session.display) { history.removeLast() }
		store.save(layout, for: session.display, windows: session.windows ?? [])
		onLayoutChanged?(session.display, store.layout(for: session.display))
		if let windows = session.windows {
			pendingLive = nil
			place(session.board, windows: windows, animated: false)
		} else {
			retileSoon([session.display])
		}
	}

	/// Double-click on a divider: back to an even split.
	func resetDivider(display: String, splitID: UUID) {
		guard let layout = store.layout(for: display),
			let even = layout.settingPosition(0.5, ofSplit: splitID), even != layout,
			let screen = NSScreen.screen(uuid: display)
		else { return }
		apply(
			even, on: TilingBoard.offscreen(on: screen, layout: even), screen: screen,
			windows: [], label: "Resize")
		retileSoon([display])
	}

	/// Places `board`'s windows straight away, without animation; while one placement is
	/// running the newest waits, and older ones are dropped.
	private func placeLive(_ board: TilingBoard) {
		guard let windows = resize?.windows else { return }
		guard !isPlacingLive else {
			pendingLive = board
			return
		}
		isPlacingLive = true
		let placements = Self.placements(for: board, windows: windows)
		tiler.place(placements, animation: nil) { [weak self] placed in
			guard let self else { return }
			for (id, frame) in placed { self.store.recordPlacement(id, frame: frame) }
			self.isPlacingLive = false
			if let next = self.pendingLive {
				self.pendingLive = nil
				self.placeLive(next)
			}
		}
	}
}
