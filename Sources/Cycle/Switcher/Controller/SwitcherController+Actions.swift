import AppKit

/// Card actions (close, minimize, hide, quit, full screen) and re-reading windows after
/// they change.
extension SwitcherController {
	/// Runs a card action on the highlighted window, or on `id` when a card's button was
	/// clicked. The session stays open afterwards, like DockDoor's
	/// `windowSwitcherKeepOpenAfterWindowAction`, except for full screen, which needs focus.
	func perform(_ action: CardAction, on id: CGWindowID? = nil) {
		guard
			phase == .active,
			let window = id.flatMap({ id in state.windows.first { $0.id == id } }) ?? state.selected
		else { return }
		switch action {
		case .quit:
			WindowActions.quit(window)
			remove { $0.pid == window.pid }
		case .close:
			guard !window.isWindowless else { return }
			WindowActions.close(window)
			remove { $0.id == window.id }
		case .minimize:
			guard !window.isWindowless else { return }
			WindowActions.toggleMinimize(window)
			refreshSoon()
		case .hide:
			WindowActions.toggleHidden(window)
			refreshSoon()
		case .fullScreen:
			guard !window.isWindowless else { return }
			end()
			focuser.focus(window, then: WindowActions.toggleFullScreen)
			mru.touch(window.id)
		}
	}

	func remove(where predicate: (SwitcherWindow) -> Bool) {
		let windows = state.windows
		let index = windows.firstIndex { $0.id == state.selectedID } ?? 0
		state.allWindows.removeAll(where: predicate)
		state.windows.removeAll(where: predicate)
		if state.allWindows.isEmpty {
			cancel()
			return
		}
		if !state.windows.isEmpty {
			state.selectedID = state.windows[min(index, state.windows.count - 1)].id
		}
		panel.relayout()
	}

	/// Minimize / hide change what a card shows; re-read the list after the app reacts.
	func refreshSoon() {
		let thisGeneration = generation
		let selected = state.selectedID
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
			guard let self, self.phase == .active, self.generation == thisGeneration else { return }
			var windows = WindowEnumerator.snapshot(
				order: self.mru, includeWindowless: Settings.showWindowlessApps)
			if Settings.currentSpaceOnly { windows.removeAll { $0.isOnOtherSpace } }
			// Keep the session's order; only refresh flags.
			let byID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
			self.state.allWindows = self.state.allWindows.map { byID[$0.id] ?? $0 }
			self.state.windows = self.state.windows.map { byID[$0.id] ?? $0 }
			self.state.selectedID = selected
		}
	}

	/// Windows were tiled: once the apps have redrawn, re-read their frames (so previews
	/// take their new shapes) and capture them again.
	func windowsMoved(_ ids: [CGWindowID]) {
		let thisGeneration = generation
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
			guard let self, self.phase == .active, self.generation == thisGeneration else { return }
			let fresh = WindowEnumerator.snapshot(
				order: self.mru, includeWindowless: Settings.showWindowlessApps)
			let byID = Dictionary(fresh.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
			self.state.recentOrder = self.state.recentOrder.map { byID[$0.id] ?? $0 }
			self.state.allWindows = self.state.allWindows.map { byID[$0.id] ?? $0 }
			self.state.windows = self.state.windows.map { byID[$0.id] ?? $0 }
			self.panel.relayout()
			self.thumbnails.capture(ids, best: false, maxAge: 0) { [weak self] id, captured in
				guard let self, self.generation == thisGeneration else { return }
				self.state.images[id] = captured.image
				self.state.tints[id] = captured.tint
			}
		}
	}
}
