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
		dragTracker.onRightClick = { [weak self] event in
			guard let self, let id = self.pointerWindowID,
				let view = event.window?.contentView
			else { return }
			// Marking by default; the menu when that's turned on. Option swaps the two.
			let opensMenu = Settings.tilingRightClickMenu != event.modifierFlags.contains(.option)
			if opensMenu {
				self.showMenu(for: id, onBoard: false, event: event, in: view)
			} else {
				self.toggleMark(id)
			}
		}
		dragTracker.onBegin = { [weak self] id in self?.beginDrag(id, fromBoard: false) }
		dragTracker.onMove = { [weak self] point in self?.moveDrag(to: point) }
		dragTracker.onEnd = { [weak self] in self?.endDrag() }
	}

	/// Picks up `id`: a card from the switcher, or a tile from the board.
	func beginDrag(_ id: CGWindowID, fromBoard: Bool) {
		guard isActive, state.drag == nil, let frame = panelFrame, let screen = panelScreen
		else { return }
		let layout = tiling.layout(for: screen, windows: state.recentOrder)
		// The board may be showing already; the drag takes it over.
		let placement =
			state.board?.placement
			?? tilingOverlay.show(on: screen, below: frame, presets: Settings.tilingPresets)
		boardDividers.hideAll()
		let board = TilingBoard(
			layout: layout, visible: screen.visibleFrameTopLeft, placement: placement,
			displayScale: screen.backingScaleFactor)
		if state.windows.contains(where: { $0.id == id }) { state.selectedID = id }
		// A marked card brings the other marked windows with it.
		let ids = !fromBoard && state.markedIDs.contains(id) ? draggableMarks() : [id]
		var drag = WindowDrag(
			windowID: id, windowIDs: ids, screen: screen, board: board,
			pointer: tilingOverlay.local(NSEvent.mouseLocation), target: nil)
		drag.fromBoard = fromBoard
		state.drag = drag
	}

	func moveDrag(to point: CGPoint) {
		guard var drag = state.drag else { return }
		drag.pointer = tilingOverlay.local(point)
		drag.target = drag.board.target(at: drag.pointer, dragging: drag.windowIDs)
		dwell(on: &drag)
		state.drag = drag
		dragCursor(for: drag).set()
	}

	/// Resting on another display's chip in the board's header switches the board to that
	/// display after a moment; moving off it calls that off.
	private func dwell(on drag: inout WindowDrag) {
		let chip = drag.board.placement.displays.first {
			// At least the 20 pt minimum target, around the smaller chip.
			$0.rect.insetBy(dx: -4, dy: -4).contains(drag.pointer)
		}
		// On a display chip nothing is dropped, whatever's beneath it.
		if chip != nil { drag.target = nil }
		let hovered = chip?.display == drag.screen.displayUUID ? nil : chip?.display
		guard hovered != drag.hoveredDisplay else { return }
		drag.hoveredDisplay = hovered
		displayDwellWork?.cancel()
		displayDwellWork = nil
		guard let hovered else { return }
		let work = DispatchWorkItem { [weak self] in
			MainActor.assumeIsolated { self?.switchDrag(to: hovered) }
		}
		displayDwellWork = work
		DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Tiling.displayDwell, execute: work)
	}

	/// Points the board at another display: dropping then tiles there.
	private func switchDrag(to display: String) {
		displayDwellWork = nil
		guard var drag = state.drag, drag.hoveredDisplay == display, let frame = panelFrame,
			let screen = NSScreen.screen(uuid: display)
		else { return }
		let placement = tilingOverlay.placement(
			picturing: screen, below: frame, presets: Settings.tilingPresets)
		drag.screen = screen
		drag.hoveredDisplay = nil
		drag.board = TilingBoard(
			layout: tiling.layout(for: screen, windows: state.recentOrder),
			visible: screen.visibleFrameTopLeft, placement: placement,
			displayScale: screen.backingScaleFactor)
		drag.target = drag.board.target(at: drag.pointer, dragging: drag.windowIDs)
		drag.updatePreview()
		state.drag = drag
		Haptics.confirm()
	}

	func endDrag() {
		guard let drag = state.drag else { return }
		// The release also reaches the card as a click; this drag has handled it.
		if !drag.fromBoard { ignoresNextClick = true }
		let lands = drag.untiles || (drag.target != nil && drag.result != nil)
		cancelDrag(evaporating: !lands)
		if drag.untiles {
			untile(drag.windowID)
			return releaseIfModifierUp()
		}
		guard let target = drag.target, let layout = drag.result
		else { return releaseIfModifierUp() }
		if drag.windowIDs.count > 1 { state.markedIDs = [] }
		let label: String = if case .preset(let preset, _) = target { preset.title } else { "Move" }
		tile(layout, on: drag.board, screen: drag.screen, focusing: drag.windowID, label: label)
		showNotice(label == "Move" ? "Moved \(name(of: drag.windowID))" : label)
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
		Haptics.confirm()
	}

	/// The modifier and a number: lays out the screen the switcher is on with the board's
	/// `index`th preset. The windows dragged, else the marked ones, else the highlighted one
	/// go in its slots, main slot first.
	func tileWithPreset(at index: Int) {
		let presets = Settings.tilingPresets
		guard isActive, presets.indices.contains(index) else { return }
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
		tile(ids, with: preset)
	}

	/// Lays out the switcher's screen with `preset`, `ids` in its slots, main slot first
	/// (or in the empty slots, when the screen is already laid out that way).
	func tile(_ ids: [CGWindowID], with preset: TilingPreset) {
		guard isActive, let screen = panelScreen, !ids.isEmpty else { return }
		let board = TilingBoard.offscreen(
			on: screen, layout: tiling.layout(for: screen, windows: state.recentOrder))
		guard let slot = preset.slotOrder(mainShare: board.mainShare).first,
			let layout = board.filling(preset, with: ids)
				?? board.dropping(ids, on: .preset(preset, slot: slot))
		else { return }
		state.markedIDs = []
		tile(layout, on: board, screen: screen, focusing: ids[0], label: preset.title)
		showNotice(preset.title + leftOutNote(before: board.layout, after: layout))
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

	/// Shows `text` at the foot of the switcher, with an Undo button for the change just
	/// made (unless `offersUndo` is false), and has VoiceOver read it. It stays several
	/// seconds, longer with VoiceOver on, and as long as the pointer is on it.
	func showNotice(_ text: String, offersUndo: Bool = true) {
		trace("notice \(text)")
		guard isActive else { return }
		// Notes turned off: VoiceOver still hears what happened.
		guard Settings.tilingShowsNotes else {
			if NSWorkspace.shared.isVoiceOverEnabled { announce(text) }
			return
		}
		noticeSerial += 1
		let note = TilingNote(
			text: text, undoLabel: offersUndo ? tiling.undoLabel : nil, serial: noticeSerial)
		state.tilingNotice = note
		state.isHoldingNotice = false
		announce(text)
		let seconds: TimeInterval = NSWorkspace.shared.isVoiceOverEnabled ? 12 : 6
		dismissNotice(note, after: seconds)
	}

	private func announce(_ text: String) {
		NSAccessibility.post(
			element: NSApp as Any, notification: .announcementRequested,
			userInfo: [
				.announcement: text,
				.priority: NSAccessibilityPriorityLevel.high.rawValue,
			])
	}

	private func dismissNotice(_ note: TilingNote, after seconds: TimeInterval) {
		DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in
			guard let self, self.state.tilingNotice == note else { return }
			// Still being read or reached for: check again shortly.
			if self.state.isHoldingNotice { return self.dismissNotice(note, after: 1) }
			self.state.tilingNotice = nil
		}
	}

	/// Undoes the last tiling change (the note's Undo button, a menu, or a right-click
	/// outside the switcher when that's turned on).
	func undoTiling() {
		tiling.undo { [weak self] label in
			self?.showNotice(label.map { "Undid \($0)" } ?? "Nothing to undo")
		}
	}

	/// A window's app name, for notes and menus.
	func name(of id: CGWindowID) -> String {
		state.recentOrder.first { $0.id == id }?.appName ?? "Window"
	}

	func canTile(_ id: CGWindowID) -> Bool {
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
	/// With `evaporating`, the windows fade out where they were let go, showing that
	/// nothing landed.
	func cancelDrag(evaporating: Bool = false) {
		displayDwellWork?.cancel()
		displayDwellWork = nil
		guard let drag = state.drag else { return }
		state.drag = nil
		NSCursor.arrow.set()
		if evaporating {
			noticeSerial += 1
			state.evaporating = EvaporatingDrag(
				windowIDs: [drag.windowID] + drag.windowIDs.filter { $0 != drag.windowID },
				point: drag.pointer, serial: noticeSerial)
			let shown = state.evaporating
			DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Tiling.evaporateDuration + 0.05)
			{ [weak self] in
				guard let self, self.state.evaporating == shown else { return }
				self.state.evaporating = nil
				if self.state.drag == nil, self.state.board == nil { self.tilingOverlay.hide() }
			}
		}
		if state.board == nil {
			if !evaporating { tilingOverlay.hide() }
			if drag.fromBoard { hideBoardTiles() }
		} else {
			showBoardDividers()
		}
	}

	/// The pointer for a drag: a puff of smoke when letting go untiles the window, "not
	/// allowed" over its own tile, the closed hand otherwise.
	private func dragCursor(for drag: WindowDrag) -> NSCursor {
		if drag.untiles { return .disappearingItem }
		let slack = Theme.Tiling.boardSlack
		let overBoard = drag.board.rect.insetBy(dx: -slack, dy: -slack).contains(drag.pointer)
		let overChip = drag.board.placement.displays.contains {
			$0.rect.insetBy(dx: -4, dy: -4).contains(drag.pointer)
		}
		if drag.target == nil, overBoard, !overChip { return .operationNotAllowed }
		return .closedHand
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
	func releaseIfModifierUp() {
		if switchesOnRelease, !modifierPhysicallyHeld { commit() }
	}
}
