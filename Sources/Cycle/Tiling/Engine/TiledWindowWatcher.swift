import AppKit
import ApplicationServices

/// Tells Cycle when a tiled window closes, moves or resizes, through an Accessibility
/// observer per app.
@MainActor
final class TiledWindowWatcher {
	var onDestroyed: ((CGWindowID) -> Void)?
	/// Moved or resized (by Cycle or by the user: the coordinator tells them apart).
	var onChanged: ((CGWindowID) -> Void)?

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
		for name in Self.changes {
			AXObserverAddNotification(observer, element, name as CFString, refcon)
		}
		watched[window.id] = (window.pid, element)
	}

	/// A watched window's frame now, read through Accessibility.
	func frame(of id: CGWindowID) -> CGRect? {
		guard let element = watched[id]?.element,
			let origin = element.pointAttribute(kAXPositionAttribute),
			let size = element.sizeAttribute(kAXSizeAttribute)
		else { return nil }
		return CGRect(origin: origin, size: size)
	}

	private static let changes = [kAXMovedNotification, kAXResizedNotification]

	/// Stops watching every window not in `ids`.
	func keep(only ids: Set<CGWindowID>) {
		for (id, entry) in watched where !ids.contains(id) {
			if let observer = observers[entry.pid] {
				AXObserverRemoveNotification(
					observer, entry.element, kAXUIElementDestroyedNotification as CFString)
				for name in Self.changes {
					AXObserverRemoveNotification(observer, entry.element, name as CFString)
				}
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

	fileprivate func changed(_ id: CGWindowID) {
		guard watched[id] != nil else { return }
		onChanged?(id)
	}

	fileprivate func destroyed(_ id: CGWindowID) {
		guard watched.removeValue(forKey: id) != nil else { return }
		onDestroyed?(id)
	}

	private func observer(for pid: pid_t) -> AXObserver? {
		if let observer = observers[pid] { return observer }
		var observer: AXObserver?
		guard AXObserverCreate(pid, windowNotification, &observer) == .success, let observer else {
			return nil
		}
		CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
		observers[pid] = observer
		return observer
	}
}

/// The window's id rides along as the notification's refcon.
private func windowNotification(
	_ observer: AXObserver, _ element: AXUIElement, _ notification: CFString,
	_ refcon: UnsafeMutableRawPointer?
) {
	let id = CGWindowID(truncatingIfNeeded: UInt(bitPattern: refcon))
	let destroyed = (notification as String) == kAXUIElementDestroyedNotification
	MainActor.assumeIsolated {
		if destroyed {
			TiledWindowWatcher.current?.destroyed(id)
		} else {
			TiledWindowWatcher.current?.changed(id)
		}
	}
}
