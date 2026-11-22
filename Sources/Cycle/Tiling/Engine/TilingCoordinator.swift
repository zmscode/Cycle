import AppKit
import RiftCore

/// Runs tiling between and during sessions: applies dropped layouts, re-places windows
/// when the spacing changes, closes gaps when tiled windows close or their apps quit, puts
/// remembered layouts back when Cycle starts or a tiled app reopens, drives divider drags
/// (see +Resize) and the grips between tiled windows (+Dividers), and keeps the undo
/// history (+Undo).
@MainActor
final class TilingCoordinator {
	/// Windows were placed; the switcher refreshes their previews if it's open.
	var onPlaced: (([CGWindowID]) -> Void)?
	/// A display's layout changed (or is changing, mid-drag); the board follows.
	var onLayoutChanged: ((String, RiftLayout<CGWindowID>?) -> Void)?

	let store: TilingStore
	let tiler = WindowTiler()
	let loader = WindowLoader()
	let screenDividers = DividerHandles(style: .screen)
	private let memory = LayoutMemory()
	private let watcher = TiledWindowWatcher()
	private var restoreWork: [DispatchWorkItem] = []
	/// Gap filling as last applied: turning it on closes the gaps away windows left.
	private var fillsGaps = Settings.tilingFillsGaps
	/// Windows reported moved or resized, checked once they settle.
	private var movedWork: [CGWindowID: DispatchWorkItem] = [:]

	/// The divider being dragged, on the screen or the board.
	var resize: DividerResize?
	/// A live placement is running; the next waits here rather than queueing up.
	var isPlacingLive = false
	var pendingLive: TilingBoard?
	/// Recent tiling changes, newest last, for undo.
	var history: [TilingChange] = []

	init() {
		store = TilingStore(remembered: Settings.tilingRestoresLayouts ? memory.load() : [:])
		store.onChange = { [weak self] in
			guard let self else { return }
			self.memory.save(self.store.remembered)
		}
		watcher.onDestroyed = { [weak self] id in self?.windowDestroyed(id) }
		watcher.onChanged = { [weak self] id in self?.windowChanged(id) }
		setUpDividers()
		let center = NSWorkspace.shared.notificationCenter
		center.addObserver(
			forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
		) { [weak self] note in
			let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
			guard let pid = app?.processIdentifier else { return }
			MainActor.assumeIsolated { self?.appQuit(pid) }
		}
		center.addObserver(
			forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
		) { [weak self] note in
			let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
			guard let bundleID = app?.bundleIdentifier else { return }
			MainActor.assumeIsolated { self?.appLaunched(bundleID) }
		}
	}

	/// Looks for remembered windows a few times after launch, as apps reopen at login.
	func start() {
		scheduleRestore(after: [1, 4, 10, 25, 60])
		refreshDividersSoon()
	}

	// MARK: Sessions

	/// `screen`'s layout, forgetting windows in `windows` that have moved.
	func layout(for screen: NSScreen, windows: [SwitcherWindow]) -> RiftLayout<CGWindowID>? {
		guard let display = screen.displayUUID else { return nil }
		return store.layout(for: display, windows: windows)
	}

	/// A session's window list arrived: a chance to bind remembered windows.
	func sessionLoaded(_ windows: [SwitcherWindow]) {
		restore(from: windows)
	}

	/// Saves `layout` for the board's screen and moves its windows into place. `label`
	/// names the change for undo ("Thirds", "Move").
	func apply(
		_ layout: RiftLayout<CGWindowID>, on board: TilingBoard, screen: NSScreen,
		windows: [SwitcherWindow], label: String
	) {
		guard let display = screen.displayUUID else { return }
		record(display, label: label)
		store.save(layout, for: display, windows: windows)
		var board = board
		board.layout = store.layout(for: display)
		onLayoutChanged?(display, board.layout)
		place(board, windows: windows)
	}

	/// Re-places every tiled window (the gap or margin changed).
	func retileAll() {
		loader.load(includeWindowless: false) { [weak self] snapshot in
			MainActor.assumeIsolated {
				guard let self else { return }
				self.retile(Set(self.store.remembered.keys), windows: snapshot.windows)
			}
		}
	}

	/// The settings changed: let go of away windows if restoring was turned off, redo the
	/// layouts if gap filling changed how away windows show, and redraw the grips.
	func settingsChanged() {
		if !Settings.tilingRestoresLayouts, store.hasAwayWindows { store.forgetAway() }
		if Settings.tilingFillsGaps != fillsGaps {
			fillsGaps = Settings.tilingFillsGaps
			retileAll()
		}
		refreshDividersSoon()
	}

	// MARK: Events

	private func windowDestroyed(_ id: CGWindowID) {
		// Wait a moment: windows also close when their app quits, which leaves them away
		// (to come back) rather than gone.
		DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
			guard let self, let pid = self.store.pid(of: id) else {
				self?.closeTiled(id)
				return
			}
			if NSRunningApplication(processIdentifier: pid)?.isTerminated ?? true {
				self.appQuit(pid)
			} else {
				self.closeTiled(id)
			}
		}
	}

	/// A tiled window moved or resized. Once it settles, if it isn't where Cycle put it
	/// (the user moved it), it leaves the layout; the grips follow either way.
	private func windowChanged(_ id: CGWindowID) {
		guard resize == nil else { return }
		movedWork[id]?.cancel()
		let work = DispatchWorkItem { [weak self] in
			MainActor.assumeIsolated {
				guard let self else { return }
				self.movedWork[id] = nil
				if let frame = self.watcher.frame(of: id), !self.store.isWherePlaced(id, frame),
					let display = self.store.forget(id)
				{
					self.watcher.keep(only: self.store.tiledWindowIDs)
					self.onLayoutChanged?(display, self.store.layout(for: display))
				}
				self.refreshDividersSoon()
			}
		}
		movedWork[id] = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
	}

	private func closeTiled(_ id: CGWindowID) {
		guard let display = store.windowClosed(id) else { return }
		watcher.keep(only: store.tiledWindowIDs)
		onLayoutChanged?(display, store.layout(for: display))
		guard Settings.tilingFillsGaps else { return refreshDividersSoon() }
		retileSoon([display])
	}

	private func appQuit(_ pid: pid_t) {
		let displays = store.appQuit(pid)
		guard !displays.isEmpty else { return }
		watcher.keep(only: store.tiledWindowIDs)
		for display in displays { onLayoutChanged?(display, store.layout(for: display)) }
		guard Settings.tilingFillsGaps else { return refreshDividersSoon() }
		retileSoon(displays)
	}

	private func appLaunched(_ bundleID: String) {
		guard Settings.tilingRestoresLayouts, store.isAway(bundleID: bundleID) else { return }
		// Its windows take a moment to open (and longer to restore their state).
		scheduleRestore(after: [1.5, 4, 8, 15])
	}

	// MARK: Restoring

	private func scheduleRestore(after delays: [TimeInterval]) {
		restoreWork.forEach { $0.cancel() }
		restoreWork = delays.map { delay in
			let work = DispatchWorkItem { [weak self] in
				MainActor.assumeIsolated { self?.restoreFromSnapshot() }
			}
			DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: work)
			return work
		}
	}

	private func restoreFromSnapshot() {
		guard Settings.tilingRestoresLayouts, store.hasAwayWindows else {
			restoreWork.forEach { $0.cancel() }
			return
		}
		loader.load(includeWindowless: false) { [weak self] snapshot in
			MainActor.assumeIsolated { self?.restore(from: snapshot.windows) }
		}
	}

	private func restore(from windows: [SwitcherWindow]) {
		guard Settings.tilingRestoresLayouts, store.hasAwayWindows else { return }
		let displays = store.bind(windows)
		guard !displays.isEmpty else { return }
		for display in displays { onLayoutChanged?(display, store.layout(for: display)) }
		retile(displays, windows: windows)
	}

	// MARK: Placing

	func retileSoon(_ displays: Set<String>) {
		loader.load(includeWindowless: false) { [weak self] snapshot in
			MainActor.assumeIsolated { self?.retile(displays, windows: snapshot.windows) }
		}
	}

	func retile(_ displays: Set<String>, windows: [SwitcherWindow]) {
		for display in displays {
			guard let screen = NSScreen.screen(uuid: display),
				let layout = store.layout(for: display)
			else { continue }
			place(TilingBoard.offscreen(on: screen, layout: layout), windows: windows)
		}
	}

	/// Moves each window on `board` to its frame (gliding there when animation is on),
	/// then remembers where they landed and watches them for closing and moving.
	func place(_ board: TilingBoard, windows: [SwitcherWindow], animated: Bool = true) {
		let placements = Self.placements(for: board, windows: windows)
		guard !placements.isEmpty else { return refreshDividersSoon() }
		for placement in placements { watcher.watch(placement.window) }
		tiler.place(placements, animation: animated ? WindowAnimation.current : nil) {
			[weak self] placed in
			guard let self else { return }
			for (id, frame) in placed { self.store.recordPlacement(id, frame: frame) }
			self.watcher.keep(only: self.store.tiledWindowIDs)
			self.onPlaced?(Array(placed.keys))
			self.refreshDividersSoon()
		}
	}

	static func placements(for board: TilingBoard, windows: [SwitcherWindow])
		-> [(window: SwitcherWindow, frame: CGRect)]
	{
		let byID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
		return board.frames.compactMap { id, frame in
			byID[id].map { (window: $0, frame: frame) }
		}
	}

	/// The board for `display` as it's laid out now, if the display is connected.
	func board(for display: String) -> (screen: NSScreen, board: TilingBoard)? {
		guard let screen = NSScreen.screen(uuid: display) else { return nil }
		return (screen, TilingBoard.offscreen(on: screen, layout: store.layout(for: display)))
	}
}
