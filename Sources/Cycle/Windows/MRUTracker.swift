import AppKit
import ApplicationServices

/// Most-recently-used window order — DockDoor's `lastInteractionTime` and its
/// "Switcher Last Focused Time" sort. Watches app activation and each app's
/// focused-window changes through AX observers.
final class MRUTracker {
	private var lastUse: [CGWindowID: TimeInterval] = [:]
	private var observers: [pid_t: AXObserver] = [:]
	private var workspaceTokens: [NSObjectProtocol] = []

	func start() {
		let center = NSWorkspace.shared.notificationCenter
		workspaceTokens.append(
			center.addObserver(
				forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main
			) { [weak self] note in
				guard
					let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
						as? NSRunningApplication
				else { return }
				self?.observe(app)
				self?.touchFocusedWindow(of: app.processIdentifier)
			})
		workspaceTokens.append(
			center.addObserver(
				forName: NSWorkspace.didLaunchApplicationNotification, object: nil, queue: .main
			) { [weak self] note in
				guard
					let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
						as? NSRunningApplication
				else { return }
				self?.observe(app)
			})
		workspaceTokens.append(
			center.addObserver(
				forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main
			) { [weak self] note in
				guard
					let app = note.userInfo?[NSWorkspace.applicationUserInfoKey]
						as? NSRunningApplication
				else { return }
				self?.unobserve(app.processIdentifier)
			})
		for app in NSWorkspace.shared.runningApplications where app.activationPolicy == .regular {
			observe(app)
		}
		// Seed with the current front-to-back order so the first session is sensible.
		let now = Date.timeIntervalSinceReferenceDate
		let info =
			(CGWindowListCopyWindowInfo(
				[.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]])
			?? []
		for (i, entry) in info.enumerated() {
			guard let wid = entry[kCGWindowNumber as String] as? CGWindowID else { continue }
			lastUse[wid] = now - Double(i) * 0.001 - 1
		}
	}

	/// Counts the frontmost app's focused window as just used. A session starts from the
	/// window being left, even if a focus change was missed (a window that opened while
	/// its app was already active).
	func touchFrontmost() {
		guard let app = NSWorkspace.shared.frontmostApplication,
			app.processIdentifier != ProcessInfo.processInfo.processIdentifier
		else { return }
		touchFocusedWindow(of: app.processIdentifier)
	}

	func touch(_ windowID: CGWindowID) {
		lastUse[windowID] = Date.timeIntervalSinceReferenceDate
	}

	/// MRU first; windows never seen fall back to window-server z-order.
	func sort(_ windows: [SwitcherWindow], zOrder: [CGWindowID: Int]) -> [SwitcherWindow] {
		windows.sorted { a, b in
			if a.isWindowless != b.isWindowless { return !a.isWindowless }
			let ta = lastUse[a.id]
			let tb = lastUse[b.id]
			switch (ta, tb) {
			case (let x?, let y?) where x != y: return x > y
			case (.some, nil): return true
			case (nil, .some): return false
			default:
				return (zOrder[a.id] ?? .max) < (zOrder[b.id] ?? .max)
			}
		}
	}

	private func touchFocusedWindow(of pid: pid_t) {
		let app = AXUIElementCreateApplication(pid)
		AXUIElementSetMessagingTimeout(app, 0.1)
		guard let window: AXUIElement = app.attribute(kAXFocusedWindowAttribute) else { return }
		var wid: CGWindowID = 0
		if _AXUIElementGetWindow(window, &wid) == .success, wid != 0 { touch(wid) }
	}

	private func observe(_ app: NSRunningApplication) {
		let pid = app.processIdentifier
		guard observers[pid] == nil, pid != ProcessInfo.processInfo.processIdentifier else {
			return
		}
		var observer: AXObserver?
		let callback: AXObserverCallback = { _, element, _, refcon in
			guard let refcon else { return }
			let tracker = Unmanaged<MRUTracker>.fromOpaque(refcon).takeUnretainedValue()
			var wid: CGWindowID = 0
			var target = element
			// App-level notifications hand us the app; resolve its focused window.
			if let focused: AXUIElement = element.attribute(kAXFocusedWindowAttribute) {
				target = focused
			}
			if _AXUIElementGetWindow(target, &wid) == .success, wid != 0 { tracker.touch(wid) }
		}
		guard AXObserverCreate(pid, callback, &observer) == .success, let observer else { return }
		let element = AXUIElementCreateApplication(pid)
		let refcon = Unmanaged.passUnretained(self).toOpaque()
		for name in [kAXFocusedWindowChangedNotification, kAXMainWindowChangedNotification] {
			AXObserverAddNotification(observer, element, name as CFString, refcon)
		}
		CFRunLoopAddSource(CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
		observers[pid] = observer
	}

	private func unobserve(_ pid: pid_t) {
		guard let observer = observers.removeValue(forKey: pid) else { return }
		CFRunLoopRemoveSource(
			CFRunLoopGetMain(), AXObserverGetRunLoopSource(observer), .defaultMode)
	}
}
