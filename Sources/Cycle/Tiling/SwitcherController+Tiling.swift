import AppKit
import RiftCore

/// Drag-to-tile: hold a card (or press and move it) and the tiling board appears under the
/// switcher; drop the window on it to tile it. While a window is dragged the session stays
/// open even if the modifier is let go; dropping then switches to that window.
extension SwitcherController {
	/// Wires the drag tracker to this session. Called once.
	func setUpDragTracker() {
		dragTracker.pickUpCandidate = { [weak self] in
			guard let self, self.isActive, !self.state.isShowingSettings,
				let id = self.pointerWindowID,
				let window = self.state.windows.first(where: { $0.id == id }),
				WindowTiler.canTile(window)
			else { return nil }
			return id
		}
		dragTracker.isSwitcherWindow = { [weak self] window in
			self?.panelOwns(window) ?? false
		}
		dragTracker.onPress = { [weak self] in self?.ignoresNextClick = false }
		dragTracker.onRightClick = { [weak self] in self?.toggleMark() }
		dragTracker.onBegin = { [weak self] id in self?.beginDrag(id) }
		dragTracker.onMove = { [weak self] point in self?.moveDrag(to: point) }
		dragTracker.onEnd = { [weak self] in self?.endDrag() }
	}

	private func beginDrag(_ id: CGWindowID) {
		guard isActive, let frame = panelFrame, let screen = panelScreen,
			let display = screen.displayID
		else { return }
		let layout = tilingStore.layout(for: display, windows: state.recentOrder)
		let placement = tilingOverlay.show(
			on: screen, below: frame, presets: Settings.tilingPresets)
		let board = TilingBoard(
			layout: layout, visible: screen.visibleFrameTopLeft, placement: placement,
			displayScale: screen.backingScaleFactor)
		state.selectedID = id
		// A marked window brings the other marked windows with it.
		let ids = state.markedIDs.contains(id) ? draggableMarks(startingWith: id) : [id]
		state.drag = WindowDrag(
			windowID: id, windowIDs: ids, display: display, board: board,
			pointer: tilingOverlay.local(NSEvent.mouseLocation), target: nil)
	}

	private func moveDrag(to point: CGPoint) {
		guard var drag = state.drag else { return }
		drag.pointer = tilingOverlay.local(point)
		drag.target = drag.board.target(at: drag.pointer, dragging: drag.windowIDs)
		state.drag = drag
	}

	private func endDrag() {
		// The release also reaches the card as a click; this drag has handled it.
		ignoresNextClick = true
		guard let drag = state.drag else { return }
		cancelDrag()
		guard let target = drag.target,
			let layout = drag.board.dropping(drag.windowIDs, on: target)
		else { return releaseIfModifierUp() }
		if drag.windowIDs.count > 1 { state.markedIDs = [] }
		tile(layout, on: drag.board, display: drag.display, focusing: drag.windowID)
	}

	/// Right-click: marks the window under the pointer for tiling together, or unmarks it.
	private func toggleMark() {
		guard isActive, state.drag == nil, let id = pointerWindowID,
			let window = state.windows.first(where: { $0.id == id }), WindowTiler.canTile(window)
		else { return }
		if let index = state.markedIDs.firstIndex(of: id) {
			state.markedIDs.remove(at: index)
		} else {
			state.markedIDs.append(id)
		}
		NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
	}

	/// The marked windows still in the session: `id` first, then the rest in marking order.
	private func draggableMarks(startingWith id: CGWindowID) -> [CGWindowID] {
		let present = Set(state.windows.map(\.id))
		return [id] + state.markedIDs.filter { $0 != id && present.contains($0) }
	}

	/// Hides the board without tiling anything.
	func cancelDrag() {
		guard state.drag != nil else { return }
		state.drag = nil
		tilingOverlay.hide()
	}

	/// Saves and applies `layout`, moving every window in it to its frame.
	private func tile(
		_ layout: RiftLayout<CGWindowID>, on board: TilingBoard, display: CGDirectDisplayID,
		focusing id: CGWindowID
	) {
		var board = board
		board.layout = layout
		tilingStore.save(layout, for: display)
		let byID = Dictionary(
			state.recentOrder.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
		let placements = board.frames.compactMap { id, frame in
			byID[id].map { (window: $0, frame: frame) }
		}
		state.selectedID = id
		tiler.place(placements) { [weak self] placed in
			guard let self else { return }
			for (id, frame) in placed { self.tilingStore.recordPlacement(id, frame: frame) }
			self.windowsMoved(Array(placed.keys))
		}
		releaseIfModifierUp()
	}

	/// Re-places every tiled window when the gap or margin has changed.
	func retileIfSpacingChanged() {
		let spacing = (gap: Settings.tilingGap, margin: Settings.tilingMargin)
		guard spacing != tilingSpacing else { return }
		tilingSpacing = spacing
		retileWork?.cancel()
		let work = DispatchWorkItem { [weak self] in
			MainActor.assumeIsolated { self?.retileAll() }
		}
		retileWork = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
	}

	private func retileAll() {
		let byID = Dictionary(
			state.recentOrder.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
		var placements: [(window: SwitcherWindow, frame: CGRect)] = []
		for screen in NSScreen.screens {
			guard let display = screen.displayID,
				let layout = tilingStore.layout(for: display, windows: state.recentOrder)
			else { continue }
			let board = TilingBoard(
				layout: layout, visible: screen.visibleFrameTopLeft,
				placement: BoardPlacement(card: .zero, screen: .zero, chips: []),
				displayScale: screen.backingScaleFactor)
			placements += board.frames.compactMap { id, frame in
				byID[id].map { (window: $0, frame: frame) }
			}
		}
		guard !placements.isEmpty else { return }
		tiler.place(placements) { [weak self] placed in
			guard let self else { return }
			for (id, frame) in placed { self.tilingStore.recordPlacement(id, frame: frame) }
			self.windowsMoved(Array(placed.keys))
		}
	}

	/// Letting go of the modifier mid-drag doesn't end the session; once the drop is done it
	/// does, switching to the highlighted (just dropped) window.
	private func releaseIfModifierUp() {
		if switchesOnRelease, !modifierPhysicallyHeld { commit() }
	}
}

extension NSScreen {
	var displayID: CGDirectDisplayID? {
		deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? CGDirectDisplayID
	}

	/// The visible frame in window-server coordinates (top-left of the main screen, y down).
	var visibleFrameTopLeft: CGRect {
		let primaryHeight = NSScreen.screens.first?.frame.height ?? frame.height
		return CGRect(
			x: visibleFrame.minX, y: primaryHeight - visibleFrame.maxY,
			width: visibleFrame.width, height: visibleFrame.height)
	}
}
