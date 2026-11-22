import AppKit

/// Hover and clicks from the panel's cards.
extension SwitcherController {
	/// Hover only selects once the pointer has actually moved since the panel appeared,
	/// so a resting pointer doesn't steal the keyboard selection.
	func hover(_ id: CGWindowID) {
		pointerWindowID = id
		// Mid-drag the highlight stays on the dragged window.
		guard state.drag == nil else { return }
		guard let start = mouseSelectionInitialLocation else {
			state.selectedID = id
			return
		}
		let now = NSEvent.mouseLocation
		if hypot(now.x - start.x, now.y - start.y) > 4 {
			mouseSelectionInitialLocation = nil
			state.selectedID = id
		}
	}

	func hoverEnded(_ id: CGWindowID) {
		if pointerWindowID == id { pointerWindowID = nil }
	}

	func click(_ id: CGWindowID) {
		if ignoresNextClick {
			ignoresNextClick = false
			return
		}
		state.selectedID = id
		commit()
	}
}
