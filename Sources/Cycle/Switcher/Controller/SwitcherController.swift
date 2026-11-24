import AppKit
import CoreGraphics

/// Session state machine — the equivalent of DockDoor's `WindowSwitcherController`
/// (`_sessionWindowIDs`, `_selectedIndex`, `_isActive`, `_sessionGeneration`,
/// `_mouseSelectionHasMoved`, `_pendingActivationMode`, …) together with its
/// `WindowSwitcherLifecycle` (delayed presentation task, outside-click monitor).
@MainActor
final class SwitcherController {
	let state = SwitcherState()
	let tap = KeyboardTap()
	let mru = MRUTracker()
	let thumbnails = ThumbnailCache()
	lazy var panel = SwitcherPanel(state: state, controller: self)
	/// Cycle's settings: under the gear during a session, or on its own when reopened.
	private(set) lazy var settingsPanel: SettingsPanelController = {
		let settings = SettingsPanelController(tapIsRunning: { [weak self] in
			self?.tapIsRunning ?? false
		})
		settings.settings.onChange = { [weak self] in self?.settingsChanged() }
		settings.currentLayout = { [weak self] in self?.currentPresetLayout() }
		settings.captureWorkspace = { [weak self] name in
			self?.tiling.captureWorkspace(named: name)
		}
		settings.applyWorkspace = { [weak self] workspace in
			self?.tiling.apply(workspace) ?? 0
		}
		return settings
	}()

	/// `loading` is between ⌘Tab and the window list arriving from the background scan;
	/// key presses then are remembered and applied when it lands.
	enum Phase { case idle, loading, active }
	var phase: Phase = .idle
	var generation = 0
	let loader = WindowLoader()
	let focuser = FocusQueue()
	/// Tab presses made while the list was loading.
	var pendingSteps = 0
	/// Trackpad scrolling accumulated toward the next step.
	var scrollRemainder: CGFloat = 0
	/// Points of trackpad scroll per window step; momentum after lifting the fingers
	/// counts for less than a fifth, so a flick glides to a stop instead of racing ahead.
	let scrollStepDistance: CGFloat = 60
	let momentumWeight: CGFloat = 0.15
	/// A mouse wheel moves at most one window per this long, so a quick spin doesn't skip.
	let wheelStepInterval: TimeInterval = 0.11
	var lastWheelStep = Date.distantPast
	var startBackward = false
	/// The modifier was released (or Return pressed) while loading: switch on arrival.
	var commitWhenLoaded = false
	/// The panel's delay passed while loading: show it on arrival.
	var presentWhenLoaded = false
	/// Catches a modifier release the tap missed (it can be briefly disabled), so a
	/// session never stays open eating keys.
	var modifierWatchdog: Timer?
	/// Watchdog checks in a row that found the modifier up. Acting needs two (0.2 s), so a
	/// momentary misreading of the modifier state can't end a session early.
	var releasedChecks = 0
	/// Thumbnails younger than this are reused instead of captured again.
	let thumbnailMaxAge: TimeInterval = 3

	/// True while the session owns the keyboard.
	var ownsKeyboard: Bool {
		phase == .active || (phase == .loading && !commitWhenLoaded)
	}
	var sessionModifier: InitializerModifier = .command
	var sessionMode: ActivationMode = .onKeyRelease
	var presentationWork: DispatchWorkItem?
	var outsideClickMonitor: Any?
	var mouseSelectionInitialLocation: CGPoint?

	var tapIsRunning: Bool { tap.isRunning }

	// Drag-to-tile (see SwitcherController+Tiling).
	let dragTracker = DragTracker()
	let tiling = TilingCoordinator()
	/// Grips on the board's dividers during a session.
	let boardDividers = DividerHandles(style: .board)
	private(set) lazy var tilingOverlay = TilingOverlayPanel(state: state)
	/// The board's hit layer, for picking up its tiles.
	let boardTilePanel = BoardTilePanel()
	/// The click that ends a drag reaches the card too; it mustn't switch windows.
	var ignoresNextClick = false
	/// The gap and margin the tiled windows were last placed with; changing either in
	/// settings re-tiles them (after a short pause, while a slider is still moving).
	var tilingSpacing = (gap: Settings.tilingGap, margin: Settings.tilingMargin)
	var retileWork: DispatchWorkItem?
	/// The card under the pointer, whether or not hovering has selected it.
	var pointerWindowID: CGWindowID?
	/// The menu bar icon, while it's turned on.
	private(set) lazy var menuBarItem = MenuBarItem(
		openSettings: { [weak self] in self?.settingsPanel.showStandalone() },
		applyWorkspace: { [weak self] workspace in self?.tiling.apply(workspace) })
	/// A context menu is open: the session stays open until it closes.
	var isShowingMenu = false
	/// Counts notes shown, so a note's timer only dismisses that note.
	var noticeSerial = 0
	/// Switches the board to the display chip the pointer rests on, mid-drag.
	var displayDwellWork: DispatchWorkItem?

	var isActive: Bool { phase == .active }
	var panelFrame: CGRect? { panel.frame }
	var panelScreen: NSScreen? { panel.screen }
	func panelOwns(_ window: NSWindow?) -> Bool { panel.owns(window) }

	func trace(_ message: @autoclosure () -> String) {
		guard ProcessInfo.processInfo.environment["CYCLE_TRACE"] != nil else { return }
		FileHandle.standardError.write(
			"[\(Date().timeIntervalSince1970)] \(message())\n".data(using: .utf8)!)
	}

	func start() {
		// `cycle.config` edited by hand: show the new values and apply them.
		ConfigStore.shared.onExternalChange = { [weak self] in
			self?.settingsPanel.settings.reload()
			self?.settingsChanged()
		}
		ConfigStore.shared.watch()
		tiling.onPlaced = { [weak self] ids in self?.windowsMoved(ids) }
		tiling.start()
		mru.start()
		setUpDragTracker()
		setUpBoard()
		setUpBoardTiles()
		listenForRemoteRequests()
		menuBarItem.update()
		tap.handler = { [weak self] type, event in
			// The tap runs on the main run loop.
			MainActor.assumeIsolated { self?.handle(type, event) ?? false }
		}
		startTapWhenTrusted()
	}

	func startTapWhenTrusted() {
		if AXIsProcessTrusted(), tap.start() { return }
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
			self?.startTapWhenTrusted()
		}
	}

	// MARK: Session

	/// Starts a session at once and loads the window list in the background, so the tap
	/// returns immediately however long the scan takes.
	func begin(backward: Bool) {
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

	func loaded(_ snapshot: WindowEnumerator.Snapshot, generation thisGeneration: Int) {
		guard generation == thisGeneration, phase == .loading else { return }
		trace(
			"loaded \(snapshot.windows.count) windows commitWhenLoaded=\(commitWhenLoaded) presentWhenLoaded=\(presentWhenLoaded)"
		)
		tiling.sessionLoaded(snapshot.windows)
		mru.touchFrontmost()
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

	func present() {
		guard phase == .active else { return }
		mouseSelectionInitialLocation = NSEvent.mouseLocation
		trace("present")
		panel.show()
		dragTracker.start()
		showBoard()
		captureThumbnails()
		// A right-click outside undoes instead (the event tap sees it first).
		outsideClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown]) { [weak self] _ in
			MainActor.assumeIsolated { self?.cancel() }
		}
	}

	/// Captures only once the panel is on screen: a quick tap never captures, and a burst
	/// of sessions reuses thumbnails taken in the last few seconds.
	func captureThumbnails() {
		let thisGeneration = generation
		let ids = state.windows.filter { !$0.isWindowless }.map(\.id)
		thumbnails.capture(ids, best: false, maxAge: thumbnailMaxAge) { [weak self] id, captured in
			guard let self, self.generation == thisGeneration else { return }
			self.state.images[id] = captured.image
			self.state.tints[id] = captured.tint
		}
	}


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

	func commitNow() {
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

	func end() {
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
		dragTracker.stop()
		cancelDrag()
		hideBoard()
		state.evaporating = nil
		pointerWindowID = nil
		state.markedIDs = []
		state.tilingNotice = nil
		panel.hide()
	}

	func startWatchdog() {
		stopWatchdog()
		releasedChecks = 0
		let timer = Timer(timeInterval: 0.1, repeats: true) { [weak self] _ in
			MainActor.assumeIsolated { self?.checkModifier() }
		}
		RunLoop.main.add(timer, forMode: .common)
		modifierWatchdog = timer
	}

	func stopWatchdog() {
		modifierWatchdog?.invalidate()
		modifierWatchdog = nil
	}

	func checkModifier() {
		guard ownsKeyboard, holdsOnModifier, !modifierPhysicallyHeld else {
			releasedChecks = 0
			return
		}
		releasedChecks += 1
		guard releasedChecks >= 2 else { return }
		trace("watchdog commit")
		commit()
	}
}
