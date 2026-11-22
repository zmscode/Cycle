import AppKit
import ApplicationServices

/// Tells Cycle when a tiled window closes, through an Accessibility observer per app.
@MainActor
final class TiledWindowWatcher {
	var onDestroyed: ((CGWindowID) -> Void)?

	private var observers: [pid_t: AXObserver] = [:]
	private var watched: [CGWindowID: (pid: pid_t, element: AXUIElement)] = [:]

	/// The observer callback is a C function; it finds the watcher here.
	nonisolated(unsafe) fileprivate static weak var current: TiledWindowWatcher?

	init() {
		Self.current = self
	}

	/// Starts watching `window`, if it isn't watched already.
	func watch(_ window: SwitcherWindow) {
		guard watched[window.id] == nil, let element = window.axElement,
			let observer = observer(for: window.pid)
		else { return }
		let refcon = UnsafeMutableRawPointer(bitPattern: UInt(window.id))
		let result = AXObserverAddNotification(
			observer, element, kAXUIElementDestroyedNotification as CFString, refcon)
		guard result == .success || result == .notificationAlreadyRegistered else { return }
		watched[window.id] = (window.pid, element)
	}

	/// Stops watching every window not in `ids`.
	func keep(only ids: Set<CGWindowID>) {
		for (id, entry) in watched where !ids.contains(id) {
			if let observer = observers[entry.pid] {
				AXObserverRemoveNotification(
					observer, entry.element, kAXUIElementDestroyedNotification as CFString)
			}
			watched[id] = nil
		}
		let pids = Set(watched.values.map(\.pid))
		for (pid, observer) in observers where !pids.contains(pid) {
			CFRunLoopRemoveSource(
				CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
			observers[pid] = nil
		}
	}

	fileprivate func destroyed(_ id: CGWindowID) {
		guard watched.removeValue(forKey: id) != nil else { return }
		onDestroyed?(id)
	}

	private func observer(for pid: pid_t) -> AXObserver? {
		if let observer = observers[pid] { return observer }
		var observer: AXObserver?
		guard AXObserverCreate(pid, windowDestroyed, &observer) == .success, let observer else {
			return nil
		}
		CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
		observers[pid] = observer
		return observer
	}
}

/// The window's id rides along as the notification's refcon.
private func windowDestroyed(
	_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString,
	_ refcon: UnsafeMutableRawPointer?
) {
	let id = CGWindowID(truncatingIfNeeded: UInt(bitPattern: refcon))
	MainActor.assumeIsolated { TiledWindowWatcher.current?.destroyed(id) }
}
