import AppKit

/// The settings panel under the gear, and redrawing when a setting changes.
extension SwitcherController {
	/// Opens or closes the settings panel under the gear. While open it holds the session,
	/// so the modifier can be let go to use it.
	func toggleSettings() {
		if state.isShowingSettings { return closeSettings() }
		guard phase == .active, let frame = panel.frame else { return }
		state.isShowingSettings = true
		// From here the session stays open until Return, a click or Escape, so letting go
		// of the modifier to use settings doesn't switch windows.
		sessionMode = .onConfirmation
		settingsPanel.show(topLeft: settingsAnchor(in: frame))
	}

	/// Closes settings; the switcher stays open (Escape again to close it).
	func closeSettings() {
		state.isShowingSettings = false
		settingsPanel.close()
	}

	/// Just below the gear, right-aligned with it, unless that would cover the switcher:
	/// then beside the panel (left, else right), else below it.
	func settingsAnchor(in frame: CGRect) -> CGPoint {
		let size = settingsPanel.size
		let gap: CGFloat = 12
		let visible = SwitcherPanel.screenUnderPointer().visibleFrame
		if let gear = panel.gearFrame {
			let topLeft = CGPoint(x: gear.maxX - size.width, y: gear.minY - gap)
			let rect = CGRect(
				x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
			if !rect.intersects(frame.insetBy(dx: -gap, dy: -gap)), rect.minY >= visible.minY {
				return topLeft
			}
		}
		if frame.minX - gap - size.width >= visible.minX {
			return CGPoint(x: frame.minX - gap - size.width, y: frame.maxY)
		}
		if frame.maxX + gap + size.width <= visible.maxX {
			return CGPoint(x: frame.maxX + gap, y: frame.maxY)
		}
		let x = min(max(frame.minX, visible.minX), visible.maxX - size.width)
		let y = max(frame.minY - gap, visible.minY + size.height)
		return CGPoint(x: x, y: y)
	}

	/// A setting changed in the panel: redraw an open switcher in the new arrangement.
	func settingsChanged() {
		tiling.settingsChanged()
		retileIfSpacingChanged()
		guard phase == .active else { return }
		let recent = state.recentOrder
		state.allWindows = Settings.layout == .grouped ? WindowGroup.groupedOrder(recent) : recent
		let selected = state.selectedID
		setQuery(state.searchQuery)
		state.selectedID = selected
		panel.relayout()
		if state.isShowingSettings, let frame = panel.frame {
			settingsPanel.show(topLeft: settingsAnchor(in: frame))
		}
	}
}
