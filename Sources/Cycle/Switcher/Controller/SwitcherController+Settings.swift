import AppKit

/// The settings panel beside the switcher (opened by the gear), and redrawing when a
/// setting changes.
extension SwitcherController {
	/// Opens or closes the settings panel beside the switcher. While open it holds the session,
	/// so the modifier can be let go to use it.
	func toggleSettings() {
		if state.isShowingSettings { return closeSettings() }
		guard phase == .active, let frame = panel.frame else { return }
		state.isShowingSettings = true
		// From here the session stays open until Return, a click or Escape, so letting go
		// of the modifier to use settings doesn't switch windows.
		sessionMode = .onConfirmation
		// The board's tiles mustn't take clicks meant for settings.
		hideBoardTiles()
		settingsPanel.show(topLeft: settingsAnchor(in: frame))
	}

	/// Closes settings; the switcher stays open (Escape again to close it).
	func closeSettings() {
		state.isShowingSettings = false
		settingsPanel.close()
		if state.board != nil { showBoardTiles() }
	}

	/// Left of the settings button (which sits left of the switcher), centred on the
	/// switcher vertically; on the switcher's right when there's no room on the left. A
	/// panel taller than the screen allows scrolls.
	func settingsAnchor(in frame: CGRect) -> CGPoint {
		let gap: CGFloat = 12
		let screen = panel.screen ?? SwitcherPanel.screenUnderPointer()
		let visible = screen.visibleFrame.insetBy(dx: gap, dy: gap)
		let size = settingsPanel.prepare(maxHeight: visible.height)
		let height = min(size.height, visible.height)
		var x = (panel.gearFrame?.minX ?? frame.minX) - gap - size.width
		if x < visible.minX { x = min(frame.maxX + gap, visible.maxX - size.width) }
		// Centred on the switcher, kept on screen.
		let top = min(max(frame.midY + height / 2, visible.minY + height), visible.maxY)
		return CGPoint(x: x, y: top)
	}

	/// A setting changed in the panel: redraw an open switcher in the new arrangement.
	func settingsChanged() {
		tiling.settingsChanged()
		retileIfSpacingChanged()
		menuBarItem.update()
		guard phase == .active else { return }
		// Previews turned on or off mid-session: capture now, or drop the pictures.
		if Settings.showPreviews {
			if state.images.isEmpty { captureThumbnails() }
		} else {
			state.images = [:]
			state.tints = [:]
		}
		let recent = state.recentOrder
		state.allWindows = Settings.layout == .grouped ? WindowGroup.groupedOrder(recent) : recent
		let selected = state.selectedID
		setQuery(state.searchQuery)
		state.selectedID = selected
		panel.relayout()
		if state.board != nil { showBoard() }
		if state.isShowingSettings, let frame = panel.frame {
			settingsPanel.show(topLeft: settingsAnchor(in: frame))
		}
	}
}
