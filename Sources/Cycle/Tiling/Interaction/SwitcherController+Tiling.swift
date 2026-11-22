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
		dragTracker.onRightClick = { [weak self] in
			guard let self, let id = self.pointerWindowID else { return }
			self.toggleMark(id)
		}
		dragTracker.onBegin = { [weak self] id in self?.beginDrag(id) }
		dragTracker.onMove = { [weak self] point in self?.moveDrag(to: point) }
		dragTracker.onEnd = { [weak self] in self?.endDrag() }
	}

	private func beginDrag(_ id: CGWindowID) {
		guard isActive, let frame = panelFrame, let screen = panelScreen else { return }
		let layout = tiling.layout(for: screen, windows: state.recentOrder)
		// The board may be showing already; the drag takes it over.
		let placement =
			state.board?.placement
			?? tilingOverlay.show(on: screen, below: frame, presets: Settings.tilingPresets)
		boardDividers.hideAll()
		let board = TilingBoard(
			layout: layout, visible: screen.visibleFrameTopLeft, placement: placement,
			displayScale: screen.backingScaleFactor)
		state.selectedID = id
		// A marked window brings the other marked windows with it.
		let ids = state.markedIDs.contains(id) ? draggableMarks() : [id]
		state.drag = WindowDrag(
			windowID: id, windowIDs: ids, screen: screen, board: board,
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
		let label: String = if case .preset(let preset, _) = target { preset.title } else { "Move" }
		tile(layout, on: drag.board, screen: drag.screen, focusing: drag.windowID, label: label)
	}

	/// Right-click or Space: marks a window for tiling together, or unmarks it.
	func toggleMark(_ id: CGWindowID) {
		guard isActive, state.drag == nil,
			let window = state.windows.first(where: { $0.id == id }), WindowTiler.canTile(window)
		else { return }
		if let index = state.markedIDs.firstIndex(of: id) {
			state.markedIDs.remove(at: index)
		} else {
			state.markedIDs.append(id)
		}
		NSHapticFeedbackManager.defaultPerformer.perform(.alignment, performanceTime: .now)
	}

	/// The modifier and a number: lays out the screen the switcher is on with the board's
	/// `index`th preset. The windows dragged, else the marked ones, else the highlighted one
	/// go in its slots, main slot first.
	func tileWithPreset(at index: Int) {
		let presets = Settings.tilingPresets
		guard isActive, presets.indices.contains(index), let screen = panelScreen else { return }
		let preset = presets[index]
		let ids: [CGWindowID]
		if let drag = state.drag {
			ids = drag.windowIDs
			dragTracker.reset()
			cancelDrag()
		} else if state.markedIDs.contains(where: canTile) {
			ids = draggableMarks().filter(canTile)
		} else if let id = state.selectedID, canTile(id) {
			ids = [id]
		} else {
			return
		}
		let board = TilingBoard.offscreen(
			on: screen, layout: tiling.layout(for: screen, windows: state.recentOrder))
		guard let slot = preset.slotOrder(mainShare: board.mainShare).first,
			let layout = board.filling(preset, with: ids)
				?? board.dropping(ids, on: .preset(preset, slot: slot))
		else { return }
		state.markedIDs = []
		showNotice(preset.title + leftOutNote(before: board.layout, after: layout))
		tile(layout, on: board, screen: screen, focusing: ids[0], label: preset.title)
	}

	/// " · Helium left untiled" for tiled windows `after` doesn't keep, else nothing.
	private func leftOutNote(
		before: RiftLayout<CGWindowID>?, after: RiftLayout<CGWindowID>
	) -> String {
		let kept = Set(after.paneIDs)
		let names = (before?.paneIDs ?? []).filter {
			!TilingSlot.isPlaceholder($0) && !kept.contains($0)
		}.compactMap { id in state.recentOrder.first { $0.id == id }?.appName }
		switch names.count {
		case 0: return ""
		case 1: return " · \(names[0]) left untiled"
		default: return " · \(names.count) windows left untiled"
		}
	}

	/// Shows `text` at the foot of the switcher for a moment.
	func showNotice(_ text: String) {
		trace("notice \(text)")
		state.tilingNotice = text
		let shown = text
		DispatchQueue.main.asyncAfter(deadline: .now() + 1.8) { [weak self] in
			guard let self, self.state.tilingNotice == shown else { return }
			self.state.tilingNotice = nil
		}
	}

	private func canTile(_ id: CGWindowID) -> Bool {
		state.windows.first { $0.id == id }.map(WindowTiler.canTile) ?? false
	}

	/// The marked windows still in the session, in the order they were marked: the order
	/// they fill a preset's slots (left to right) or sit side by side.
	private func draggableMarks() -> [CGWindowID] {
		let present = Set(state.windows.map(\.id))
		return state.markedIDs.filter(present.contains)
	}

	/// Puts the dragged window down without tiling anything. The board stays if the
	/// screen is tiled (it was showing before the drag).
	func cancelDrag() {
		guard state.drag != nil else { return }
		state.drag = nil
		if state.board == nil {
			tilingOverlay.hide()
		} else {
			showBoardDividers()
		}
	}

	/// Saves and applies `layout`, moving every window in it to its frame.
	private func tile(
		_ layout: RiftLayout<CGWindowID>, on board: TilingBoard, screen: NSScreen,
		focusing id: CGWindowID, label: String
	) {
		state.selectedID = id
		tiling.apply(layout, on: board, screen: screen, windows: state.recentOrder, label: label)
		releaseIfModifierUp()
	}

	/// Re-places every tiled window when the gap or margin has changed (after a short
	/// pause, while a slider is still moving).
	func retileIfSpacingChanged() {
		let spacing = (gap: Settings.tilingGap, margin: Settings.tilingMargin)
		guard spacing != tilingSpacing else { return }
		tilingSpacing = spacing
		retileWork?.cancel()
		let work = DispatchWorkItem { [weak self] in
			MainActor.assumeIsolated { self?.tiling.retileAll() }
		}
		retileWork = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: work)
	}

	/// Letting go of the modifier mid-drag doesn't end the session; once the drop is done it
	/// does, switching to the highlighted (just dropped) window.
	private func releaseIfModifierUp() {
		if switchesOnRelease, !modifierPhysicallyHeld { commit() }
	}
}
