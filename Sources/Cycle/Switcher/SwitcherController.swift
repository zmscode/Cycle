import AppKit
import CoreGraphics

/// Session state machine — the equivalent of DockDoor's `WindowSwitcherController`
/// (`_sessionWindowIDs`, `_selectedIndex`, `_isActive`, `_sessionGeneration`,
/// `_mouseSelectionHasMoved`, `_pendingActivationMode`, …) together with its
/// `WindowSwitcherLifecycle` (delayed presentation task, outside-click monitor).
@MainActor
final class SwitcherController {
	let state = SwitcherState()
	private let tap = KeyboardTap()
	private let mru = MRUTracker()
	private let thumbnails = ThumbnailCache()
	private lazy var panel = SwitcherPanel(state: state, controller: self)

	private var isActive = false
	private var generation = 0
	private var sessionModifier: InitializerModifier = .command
	private var sessionMode: ActivationMode = .onKeyRelease
	private var presentationWork: DispatchWorkItem?
	private var outsideClickMonitor: Any?
	private(set) var mouseSelectionInitialLocation: CGPoint?

	var tapIsRunning: Bool { tap.isRunning }

	func start() {
		mru.start()
		tap.handler = { [weak self] type, event in
			// The tap runs on the main run loop.
			MainActor.assumeIsolated { self?.handle(type, event) ?? false }
		}
		startTapWhenTrusted()
	}

	private func startTapWhenTrusted() {
		if AXIsProcessTrusted(), tap.start() { return }
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
			self?.startTapWhenTrusted()
		}
	}

	// MARK: Keyboard

	private func handle(_ type: CGEventType, _ event: CGEvent) -> Bool {
		let flags = event.flags
		let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))
		let modifier = isActive ? sessionModifier : Settings.modifier
		let modifierHeld = flags.contains(modifier.flag)
		let shift = flags.contains(.maskShift)

		switch type {
		case .flagsChanged:
			// Releasing the initializer commits the highlighted window. The release itself
			// passes through so the system's modifier state stays right.
			// Searching holds the session open (DockDoor's `_searchHoldsSession`).
			if isActive, !modifierHeld, sessionMode == .onKeyRelease, !state.isSearching {
				commit()
			}
			return false

		case .keyDown:
			if keyCode == Key.tab, modifierHeld, onlyInitializer(flags, modifier) {
				if isActive { step(shift ? -1 : 1) } else { begin(backward: shift) }
				return true
			}
			guard isActive else { return false }
			switch keyCode {
			case Key.escape:
				if !state.searchQuery.isEmpty {
					setQuery("")
				} else if state.isSearching {
					state.isSearching = false
				} else {
					cancel()
				}
			case Key.returnKey, Key.keypadEnter: commit()
			case Key.left, Key.up: step(-1)
			case Key.right, Key.down: step(1)
			case Key.delete where state.isSearching: setQuery(String(state.searchQuery.dropLast()))
			case _ where state.isSearching:
				if let text = Self.typedText(event) { setQuery(state.searchQuery + text) }
			case Key.searchTrigger: state.isSearching = true
			case Key.grave: stepWithinApp(shift ? -1 : 1)
			case Key.w: perform(.close)
			case Key.m: perform(.minimize)
			case Key.h: perform(.hide)
			case Key.f: perform(.fullScreen)
			case Key.q: perform(.quit)
			default: break
			}
			// While a session is open every key belongs to it.
			return true

		case .keyUp:
			return isActive

		default:
			return false
		}
	}

	/// Tab with the initializer, optionally Shift, and no other primary modifier.
	private func onlyInitializer(_ flags: CGEventFlags, _ modifier: InitializerModifier) -> Bool {
		let others: [CGEventFlags] = [.maskCommand, .maskAlternate, .maskControl].filter {
			$0 != modifier.flag
		}
		return others.allSatisfy { !flags.contains($0) }
	}

	// MARK: Session

	private func begin(backward: Bool) {
		var windows = WindowEnumerator.snapshot(
			order: mru, includeWindowless: Settings.showWindowlessApps)
		if Settings.currentSpaceOnly { windows.removeAll { $0.isOnOtherSpace } }
		if !Settings.includeHiddenWindows { windows.removeAll { $0.isMinimized || $0.isAppHidden } }
		guard !windows.isEmpty else { return }

		generation += 1
		isActive = true
		sessionModifier = Settings.modifier
		sessionMode = Settings.activationMode
		mouseSelectionInitialLocation = nil

		state.allWindows = windows
		state.windows = windows
		state.searchQuery = ""
		state.isSearching = false
		state.images = [:]
		state.tints = [:]
		for w in windows {
			if let cached = thumbnails.cached(w.id) {
				state.images[w.id] = cached.image
				state.tints[w.id] = cached.tint
			}
		}
		// Start on the next window (the current one is first), or the last when going back.
		let start = backward ? windows.count - 1 : min(1, windows.count - 1)
		state.selectedID = windows[start].id

		let thisGeneration = generation
		thumbnails.capture(windows.filter { !$0.isWindowless }.map(\.id), best: false) {
			[weak self] id, captured in
			guard let self, self.generation == thisGeneration else { return }
			self.state.images[id] = captured.image
			self.state.tints[id] = captured.tint
		}
		thumbnails.prune(keeping: Set(windows.map(\.id)))

		// A quick tap-and-release switches without ever drawing the panel.
		let work = DispatchWorkItem { [weak self] in
			guard let self, self.isActive, self.generation == thisGeneration else { return }
			self.present()
		}
		presentationWork = work
		DispatchQueue.main.asyncAfter(deadline: .now() + Settings.panelDelay, execute: work)
	}

	/// `Cycle --preview`: opens a session without the keyboard, for checking the panel.
	func preview(seconds: TimeInterval) {
		begin(backward: false)
		presentationWork?.cancel()
		present()
		DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in self?.cancel() }
	}

	/// `Cycle --demo`: a session over made-up windows, for screenshots.
	func showDemo(_ windows: [SwitcherWindow], images: [CGWindowID: NSImage], tints: [CGWindowID: NSColor]) {
		generation += 1
		isActive = true
		state.allWindows = windows
		state.windows = windows
		state.images = images
		state.tints = tints
		state.searchQuery = ""
		state.isSearching = false
		state.selectedID = windows[min(1, windows.count - 1)].id
		mouseSelectionInitialLocation = NSEvent.mouseLocation
		panel.show()
	}

	private func present() {
		mouseSelectionInitialLocation = NSEvent.mouseLocation
		panel.show()
		outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
			.leftMouseDown, .rightMouseDown,
		]) { [weak self] _ in
			MainActor.assumeIsolated { self?.cancel() }
		}
	}

	private func step(_ delta: Int) {
		let windows = state.windows
		guard !windows.isEmpty else { return }
		let index = windows.firstIndex { $0.id == state.selectedID } ?? 0
		state.selectedID = windows[(index + delta + windows.count) % windows.count].id
	}

	/// Next window of the highlighted app (DockDoor's in-switcher app-window stepping).
	private func stepWithinApp(_ delta: Int) {
		guard let selected = state.selected else { return }
		let siblings = state.windows.filter { $0.pid == selected.pid }
		guard siblings.count > 1, let i = siblings.firstIndex(where: { $0.id == selected.id })
		else { return }
		state.selectedID = siblings[(i + delta + siblings.count) % siblings.count].id
	}

	func select(_ id: CGWindowID) { state.selectedID = id }

	func commit() {
		guard isActive else { return }
		let target = state.selected
		end()
		guard let target else { return }
		WindowActions.focus(target)
		mru.touch(target.id)
	}

	func cancel() {
		guard isActive else { return }
		end()
	}

	private func end() {
		isActive = false
		generation += 1
		presentationWork?.cancel()
		presentationWork = nil
		if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
		outsideClickMonitor = nil
		panel.hide()
	}

	// MARK: Window controls (keyboard and the card's traffic lights)

	/// Runs a card action on the highlighted window, or on `id` when a card's button was
	/// clicked. The session stays open afterwards, like DockDoor's
	/// `windowSwitcherKeepOpenAfterWindowAction`, except for full screen, which needs focus.
	func perform(_ action: CardAction, on id: CGWindowID? = nil) {
		guard
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
			WindowActions.focus(window)
			mru.touch(window.id)
			WindowActions.toggleFullScreen(window)
		}
	}

	private func remove(where predicate: (SwitcherWindow) -> Bool) {
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

	// MARK: Search

	private func setQuery(_ query: String) {
		state.searchQuery = query
		state.windows =
			query.isEmpty
			? state.allWindows
			: state.allWindows.filter { Self.matches(query, $0.appName + " " + $0.title) }
		if !state.windows.contains(where: { $0.id == state.selectedID }) {
			state.selectedID = state.windows.first?.id
		}
		panel.relayout()
	}

	/// Case-insensitive subsequence match, so "chfig" finds "Chrome — Fig & Fennel".
	private static func matches(_ query: String, _ text: String) -> Bool {
		var remaining = Substring(query.lowercased().filter { !$0.isWhitespace })
		for ch in text.lowercased() where ch == remaining.first {
			remaining = remaining.dropFirst()
			if remaining.isEmpty { return true }
		}
		return remaining.isEmpty
	}

	private static func typedText(_ event: CGEvent) -> String? {
		var length = 0
		var chars = [UniChar](repeating: 0, count: 8)
		event.keyboardGetUnicodeString(
			maxStringLength: 8, actualStringLength: &length, unicodeString: &chars)
		guard length > 0 else { return nil }
		let text = String(utf16CodeUnits: chars, count: length)
		return text.unicodeScalars.allSatisfy({ !CharacterSet.controlCharacters.contains($0) })
			? text : nil
	}

	/// Minimize / hide change what a card shows; re-read the list after the app reacts.
	private func refreshSoon() {
		let thisGeneration = generation
		let selected = state.selectedID
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
			guard let self, self.isActive, self.generation == thisGeneration else { return }
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

	// MARK: Mouse (from the panel)

	/// Hover only selects once the pointer has actually moved since the panel appeared,
	/// so a resting pointer doesn't steal the keyboard selection.
	func hover(_ id: CGWindowID) {
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

	func click(_ id: CGWindowID) {
		state.selectedID = id
		commit()
	}
}

/// The card controls, in DockDoor's default traffic-light order (its `PreviewAction`
/// cases quit / close / minimize / fullscreen).
enum CardAction: CaseIterable {
	case quit, close, minimize, fullScreen, hide
	static let trafficLights: [CardAction] = [.quit, .close, .minimize, .fullScreen]
}

@Observable
final class SwitcherState {
	/// The session's full list; `windows` is it filtered by the search query.
	var allWindows: [SwitcherWindow] = []
	var windows: [SwitcherWindow] = []
	var selectedID: CGWindowID?
	var images: [CGWindowID: NSImage] = [:]
	/// Average colour of each thumbnail; the card is tinted with it.
	var tints: [CGWindowID: NSColor] = [:]
	var isSearching = false
	var searchQuery = ""

	var selected: SwitcherWindow? { windows.first { $0.id == selectedID } }
}
