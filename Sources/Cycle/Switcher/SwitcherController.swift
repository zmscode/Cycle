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
	/// Cycle's settings: under the gear during a session, or on its own when reopened.
	private(set) lazy var settingsPanel: SettingsPanelController = {
		let settings = SettingsPanelController(tapIsRunning: { [weak self] in self?.tapIsRunning ?? false })
		settings.settings.onChange = { [weak self] in self?.settingsChanged() }
		return settings
	}()

	/// `loading` is between ⌘Tab and the window list arriving from the background scan;
	/// key presses then are remembered and applied when it lands.
	private enum Phase { case idle, loading, active }
	private var phase: Phase = .idle
	private var generation = 0
	private let loader = WindowLoader()
	private let focuser = FocusQueue()
	/// Tab presses made while the list was loading.
	private var pendingSteps = 0
	/// Trackpad scrolling accumulated toward the next step.
	private var scrollRemainder: CGFloat = 0
	/// Points of trackpad scroll per window step.
	private let scrollStepDistance: CGFloat = 28
	private var startBackward = false
	/// The modifier was released (or Return pressed) while loading: switch on arrival.
	private var commitWhenLoaded = false
	/// The panel's delay passed while loading: show it on arrival.
	private var presentWhenLoaded = false
	/// Catches a modifier release the tap missed (it can be briefly disabled), so a
	/// session never stays open eating keys.
	private var modifierWatchdog: Timer?
	/// Thumbnails younger than this are reused instead of captured again.
	private let thumbnailMaxAge: TimeInterval = 3

	/// True while the session owns the keyboard.
	private var ownsKeyboard: Bool {
		phase == .active || (phase == .loading && !commitWhenLoaded)
	}
	private var sessionModifier: InitializerModifier = .command
	private var sessionMode: ActivationMode = .onKeyRelease
	private var presentationWork: DispatchWorkItem?
	private var outsideClickMonitor: Any?
	private(set) var mouseSelectionInitialLocation: CGPoint?

	var tapIsRunning: Bool { tap.isRunning }

	private func trace(_ message: @autoclosure () -> String) {
		guard ProcessInfo.processInfo.environment["CYCLE_TRACE"] != nil else { return }
		FileHandle.standardError.write("[\(Date().timeIntervalSince1970)] \(message())\n".data(using: .utf8)!)
	}

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
		let modifier = ownsKeyboard ? sessionModifier : Settings.modifier
		let modifierHeld = flags.contains(modifier.flag)
		let shift = flags.contains(.maskShift)

		switch type {
		case .flagsChanged:
			// Releasing the initializer commits the highlighted window. The release itself
			// passes through so the system's modifier state stays right.
			// Searching holds the session open (DockDoor's `_searchHoldsSession`).
			if ownsKeyboard, !modifierHeld, holdsOnModifier {
				commit()
			}
			return false

		case .keyDown:
			// A release the tap never saw: finish the session and let this key through.
			if ownsKeyboard, holdsOnModifier, !modifierPhysicallyHeld {
				commit()
				return false
			}
			if keyCode == Key.tab, modifierHeld, onlyInitializer(flags, modifier) {
				if ownsKeyboard { step(shift ? -1 : 1) } else { begin(backward: shift) }
				return true
			}
			if !ownsKeyboard, keyCode == Key.escape, settingsPanel.isVisible {
				settingsPanel.close()
				return true
			}
			guard ownsKeyboard else { return false }
			// Until the list arrives only navigation and Escape mean anything.
			if phase == .loading {
				switch keyCode {
				case Key.escape: cancel()
				case Key.returnKey, Key.keypadEnter: commit()
				case Key.left: move(.left)
				case Key.right: move(.right)
				case Key.up: move(.up)
				case Key.down: move(.down)
				default: break
				}
				return true
			}
			switch keyCode {
			case Key.escape:
				if state.isShowingSettings {
					closeSettings()
				} else if !state.searchQuery.isEmpty {
					setQuery("")
				} else {
					cancel()
				}
			case Key.returnKey, Key.keypadEnter: commit()
			case Key.left: move(.left)
			case Key.right: move(.right)
			case Key.up: move(.up)
			case Key.down: move(.down)
			case Key.delete:
				if !state.searchQuery.isEmpty { setQuery(String(state.searchQuery.dropLast())) }
			case Key.grave: stepWithinApp(shift ? -1 : 1)
			default:
				// Typing filters: letters, digits and the like go into the query. There are
				// no letter shortcuts, so nothing else claims them. A leading space is ignored.
				if let text = Self.typedText(event),
					!(state.searchQuery.isEmpty && text.allSatisfy(\.isWhitespace))
				{
					setQuery(state.searchQuery + text)
				}
			}
			// While a session is open every key belongs to it.
			return true

		case .keyUp:
			return ownsKeyboard

		case .scrollWheel:
			guard ownsKeyboard else { return false }
			scrolled(event)
			// Swallowed, so the window underneath doesn't scroll as well.
			return true

		default:
			return false
		}
	}

	/// Releasing the modifier ends the session, switching to the highlighted window — a
	/// filtered one included (not while settings are open, or in confirm mode).
	private var holdsOnModifier: Bool {
		sessionMode == .onKeyRelease && !state.isShowingSettings
	}

	/// The modifier's actual state, read from the event system rather than inferred from
	/// the events the tap happened to see.
	private var modifierPhysicallyHeld: Bool {
		CGEventSource.flagsState(.combinedSessionState).contains(sessionModifier.flag)
	}

	/// Tab with the initializer, optionally Shift, and no other primary modifier.
	private func onlyInitializer(_ flags: CGEventFlags, _ modifier: InitializerModifier) -> Bool {
		let others: [CGEventFlags] = [.maskCommand, .maskAlternate, .maskControl].filter {
			$0 != modifier.flag
		}
		return others.allSatisfy { !flags.contains($0) }
	}

	// MARK: Session

	/// Starts a session at once and loads the window list in the background, so the tap
	/// returns immediately however long the scan takes.
	private func begin(backward: Bool) {
		generation += 1
		let thisGeneration = generation
		phase = .loading
		scrollRemainder = 0
		trace("begin gen=\(generation)")
		sessionModifier = Settings.modifier
		sessionMode = Settings.activationMode
		pendingSteps = 0
		startBackward = backward
		commitWhenLoaded = false
		presentWhenLoaded = false
		mouseSelectionInitialLocation = nil
		state.searchQuery = ""
		startWatchdog()

		loader.load(includeWindowless: Settings.showWindowlessApps) { [weak self] snapshot in
			self?.loaded(snapshot, generation: thisGeneration)
		}

		// A quick tap-and-release switches without ever drawing the panel.
		let work = DispatchWorkItem { [weak self] in
			guard let self, self.generation == thisGeneration else { return }
			switch self.phase {
			case .active: self.present()
			case .loading: self.presentWhenLoaded = true
			case .idle: break
			}
		}
		presentationWork = work
		DispatchQueue.main.asyncAfter(deadline: .now() + Settings.panelDelay, execute: work)
	}

	private func loaded(_ snapshot: WindowEnumerator.Snapshot, generation thisGeneration: Int) {
		guard generation == thisGeneration, phase == .loading else { return }
		trace("loaded \(snapshot.windows.count) windows commitWhenLoaded=\(commitWhenLoaded) presentWhenLoaded=\(presentWhenLoaded)")
		var windows = mru.sort(snapshot.windows, zOrder: snapshot.zOrder)
		if Settings.currentSpaceOnly { windows.removeAll { $0.isOnOtherSpace } }
		if !Settings.includeHiddenWindows { windows.removeAll { $0.isMinimized || $0.isAppHidden } }
		guard !windows.isEmpty else { return end() }

		state.recentOrder = windows
		state.allWindows = windows
		state.windows = windows
		state.images = [:]
		state.tints = [:]
		for window in windows {
			if let cached = thumbnails.cached(window.id) {
				state.images[window.id] = cached.image
				state.tints[window.id] = cached.tint
			}
		}
		// Start on the next window (the current one is first), or the last when going back,
		// then apply any Tab presses made while loading.
		let count = windows.count
		let start = startBackward ? count - 1 : min(1, count - 1)
		state.selectedID = windows[((start + pendingSteps) % count + count) % count].id
		// Grouped layout: keep each app's windows together, starting from the same
		// most-recent window.
		if Settings.layout == .grouped {
			state.allWindows = WindowGroup.groupedOrder(windows)
			state.windows = state.allWindows
		}
		thumbnails.prune(keeping: Set(windows.map(\.id)))
		phase = .active

		if commitWhenLoaded { return commitNow() }
		if presentWhenLoaded { present() }
	}

	/// `Cycle --preview`: opens a session without the keyboard, for checking the panel.
	func preview(seconds: TimeInterval) {
		begin(backward: false)
		presentationWork?.cancel()
		presentWhenLoaded = true
		DispatchQueue.main.asyncAfter(deadline: .now() + seconds) { [weak self] in self?.cancel() }
	}

	/// `Cycle --demo`: a session over made-up windows, for screenshots.
	func showDemo(
		_ windows: [SwitcherWindow], images: [CGWindowID: NSImage], tints: [CGWindowID: NSColor]
	) {
		generation += 1
		phase = .active
		state.recentOrder = windows
		state.allWindows = windows
		state.windows = windows
		state.images = images
		state.tints = tints
		state.searchQuery = ""
		state.selectedID = windows[min(1, windows.count - 1)].id
		if Settings.layout == .grouped {
			state.allWindows = WindowGroup.groupedOrder(windows)
			state.windows = state.allWindows
		}
		mouseSelectionInitialLocation = NSEvent.mouseLocation
		panel.show()
	}

	private func present() {
		guard phase == .active else { return }
		mouseSelectionInitialLocation = NSEvent.mouseLocation
		trace("present")
		panel.show()
		captureThumbnails()
		outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
			.leftMouseDown, .rightMouseDown,
		]) { [weak self] _ in
			MainActor.assumeIsolated { self?.cancel() }
		}
	}

	/// Captures only once the panel is on screen: a quick tap never captures, and a burst
	/// of sessions reuses thumbnails taken in the last few seconds.
	private func captureThumbnails() {
		let thisGeneration = generation
		let ids = state.windows.filter { !$0.isWindowless }.map(\.id)
		thumbnails.capture(ids, best: false, maxAge: thumbnailMaxAge) { [weak self] id, captured in
			guard let self, self.generation == thisGeneration else { return }
			self.state.images[id] = captured.image
			self.state.tints[id] = captured.tint
		}
	}

	private func step(_ delta: Int) {
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
	private func move(_ direction: ArrowDirection) {
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
	/// left) for the previous, wrapping like Tab. A mouse wheel moves one window per notch;
	/// trackpad scrolling moves one per `scrollStepDistance` points, and the momentum
	/// after lifting the fingers is ignored so a flick can't run away.
	private func scrolled(_ event: CGEvent) {
		guard event.getIntegerValueField(.scrollWheelEventMomentumPhase) == 0 else { return }
		let continuous = event.getIntegerValueField(.scrollWheelEventIsContinuous) != 0
		if continuous {
			let vertical = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis1)
			let horizontal = event.getDoubleValueField(.scrollWheelEventPointDeltaAxis2)
			let delta = abs(vertical) >= abs(horizontal) ? vertical : horizontal
			scrollRemainder += delta
			while abs(scrollRemainder) >= scrollStepDistance {
				step(scrollRemainder > 0 ? -1 : 1)
				scrollRemainder -= scrollRemainder > 0 ? scrollStepDistance : -scrollStepDistance
			}
		} else {
			let lines = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
			guard lines != 0 else { return }
			scrollRemainder = 0
			step(lines > 0 ? -1 : 1)
		}
	}

	/// Next window of the highlighted app (DockDoor's in-switcher app-window stepping).
	private func stepWithinApp(_ delta: Int) {
		guard phase == .active, let selected = state.selected else { return }
		let siblings = state.windows.filter { $0.pid == selected.pid }
		guard siblings.count > 1, let i = siblings.firstIndex(where: { $0.id == selected.id })
		else { return }
		state.selectedID = siblings[(i + delta + siblings.count) % siblings.count].id
	}

	func select(_ id: CGWindowID) { state.selectedID = id }

	func commit() {
		switch phase {
		case .loading:
			// Switch as soon as the list arrives; until then keys are the user's again.
			commitWhenLoaded = true
			presentationWork?.cancel()
			stopWatchdog()
		case .active:
			commitNow()
		case .idle:
			break
		}
	}

	private func commitNow() {
		let target = state.selected
		end()
		guard let target else { return }
		focuser.focus(target)
		mru.touch(target.id)
	}

	func cancel() {
		guard phase != .idle else { return }
		end()
	}

	private func end() {
		trace("end phase=\(phase)")
		phase = .idle
		generation += 1
		commitWhenLoaded = false
		presentWhenLoaded = false
		stopWatchdog()
		presentationWork?.cancel()
		presentationWork = nil
		if let outsideClickMonitor { NSEvent.removeMonitor(outsideClickMonitor) }
		outsideClickMonitor = nil
		thumbnails.cancelPending()
		if state.isShowingSettings { closeSettings() }
		panel.hide()
	}

	private func startWatchdog() {
		stopWatchdog()
		let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
			MainActor.assumeIsolated { self?.checkModifier() }
		}
		RunLoop.main.add(timer, forMode: .common)
		modifierWatchdog = timer
	}

	private func stopWatchdog() {
		modifierWatchdog?.invalidate()
		modifierWatchdog = nil
	}

	private func checkModifier() {
		guard ownsKeyboard, holdsOnModifier, !modifierPhysicallyHeld else { return }
		trace("watchdog commit")
		commit()
	}

	// MARK: Settings (the gear)

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
	private func closeSettings() {
		state.isShowingSettings = false
		settingsPanel.close()
	}

	/// Just below the gear, right-aligned with it, unless that would cover the switcher:
	/// then beside the panel (left, else right), else below it.
	private func settingsAnchor(in frame: CGRect) -> CGPoint {
		let size = settingsPanel.size
		let gap: CGFloat = 12
		let visible = SwitcherPanel.screenUnderPointer().visibleFrame
		if let gear = panel.gearFrame {
			let topLeft = CGPoint(x: gear.maxX - size.width, y: gear.minY - gap)
			let rect = CGRect(x: topLeft.x, y: topLeft.y - size.height, width: size.width, height: size.height)
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
	private func settingsChanged() {
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

	// MARK: Window controls (keyboard and the card's traffic lights)

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
		guard phase == .active else { return }
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
