import AppKit

/// Moving the selection: Tab steps, arrows move by position, scrolling glides, ` stays
/// within the app.
extension SwitcherController {
	func step(_ delta: Int) {
		if phase == .loading {
			pendingSteps += delta
			return
		}
		guard phase == .active else { return }
		let windows = state.windows
		guard !windows.isEmpty else { return }
		let index = windows.firstIndex { $0.id == state.selectedID } ?? 0
		state.selectedID = windows[(index + delta + windows.count) % windows.count].id
	}

	/// Moves the selection by position on screen: left and right stay on the current row
	/// (wrapping at its ends), up and down go to the nearest card in the row above or below
	/// and stop at the first and last rows. Presses made while loading count as steps.
	func move(_ direction: ArrowDirection) {
		if phase == .loading {
			pendingSteps += (direction == .left || direction == .up) ? -1 : 1
			return
		}
		guard phase == .active,
			let current = state.windows.firstIndex(where: { $0.id == state.selectedID })
		else { return }
		let rows = panel.navigationRows()
		guard let rowIndex = rows.firstIndex(where: { $0.contains { $0.index == current } }),
			let column = rows[rowIndex].firstIndex(where: { $0.index == current })
		else { return step(direction == .left || direction == .up ? -1 : 1) }
		let row = rows[rowIndex]

		let target: Int?
		switch direction {
		case .left, .right:
			let delta = direction == .left ? -1 : 1
			target = row.count > 1 ? row[(column + delta + row.count) % row.count].index : nil
		case .up, .down:
			let next = rowIndex + (direction == .up ? -1 : 1)
			if rows.indices.contains(next) {
				let x = row[column].x
				target = rows[next].min(by: { abs($0.x - x) < abs($1.x - x) })?.index
			} else {
				target = nil
			}
		}
		if let target, state.windows.indices.contains(target) {
			state.selectedID = state.windows[target].id
		}
	}

	/// The scroll wheel steps through windows: down (or right) for the next one, up (or
	/// left) for the previous, wrapping like Tab. A mouse wheel moves one window per notch.
	/// Trackpad scrolling moves one per `scrollStepDistance` points with a light haptic
	/// tick per step; momentum keeps going at `momentumWeight`, so flicks glide.
	func scrolled(_ event: CGEvent) {
		// Mid-drag over a preset with several windows, scrolling rotates them through its
		// slots instead (stepping through the switcher is no use then).
		let advance: (Int) -> Void =
			state.drag?.rotatesSlots == true
			? { [weak self] delta in self?.state.drag?.slotOffset += delta }
			: { [weak self] delta in self?.step(delta) }
		let rotating = state.drag?.rotatesSlots == true
		let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
		if continuous {
			let momentum = event.getIntegerValueField(.scrollWheelEventMomentumPhase) != 0
			// A new gesture starts from zero rather than finishing the last one's leftover.
			if event.getIntegerValueField(.scrollWheelEventScrollPhase) == 1 { scrollRemainder = 0 }
			let vertical = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
			let horizontal = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
			let delta = abs(vertical) >= abs(horizontal) ? vertical : horizontal
			scrollRemainder += delta * (momentum ? momentumWeight : 1)
			while abs(scrollRemainder) >= scrollStepDistance {
				advance(scrollRemainder > 0 ? -1 : 1)
				scrollRemainder -= scrollRemainder > 0 ? scrollStepDistance : -scrollStepDistance
				// Rotating slots is a discrete change worth feeling; stepping through windows
				// happens too often for a tick each time.
				if rotating { Haptics.confirm() }
			}
		} else {
			let lines = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
			guard lines != 0 else { return }
			scrollRemainder = 0
			advance(lines > 0 ? -1 : 1)
		}
	}

	/// Next window of the highlighted app (DockDoor's in-switcher app-window stepping).
	func stepWithinApp(_ delta: Int) {
		guard phase == .active, let selected = state.selected else { return }
		let siblings = state.windows.filter { $0.pid == selected.pid }
		guard siblings.count > 1, let i = siblings.firstIndex(where: { $0.id == selected.id })
		else { return }
		state.selectedID = siblings[(i + delta + siblings.count) % siblings.count].id
	}

	func select(_ id: CGWindowID) { state.selectedID = id }
}
