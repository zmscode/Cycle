import AppKit
import ApplicationServices

/// Builds the switcher's window list. DockDoor keeps a live repository (`WindowKit` /
/// `WindowTracker`) fed by AX observers; this takes a snapshot when a session starts:
///
/// 1. CGWindowList (all windows, front to back) for ids, bounds, titles and z-order.
/// 2. Each regular app's AXWindows, keyed by `_AXUIElementGetWindow`, for minimized state,
///    subrole filtering and the AX element used to raise / close.
/// 3. `CGSCopySpacesForWindows` to tell windows on other Spaces apart.
enum WindowEnumerator {
	/// Unsorted windows plus their window-server z-order, safe to build off the main thread.
	struct Snapshot: @unchecked Sendable {
		let windows: [SwitcherWindow]
		let zOrder: [CGWindowID: Int]
	}

	/// Sorted most recent first. Main thread only: the MRU order lives there.
	@MainActor
	static func snapshot(order: MRUTracker, includeWindowless: Bool) -> [SwitcherWindow] {
		let snapshot = collect(includeWindowless: includeWindowless)
		return order.sort(snapshot.windows, zOrder: snapshot.zOrder)
	}

	/// Reads the window server and each app's AX windows. Takes tens of milliseconds, or
	/// up to the AX timeout when an app hangs, so sessions call it on a background queue.
	nonisolated static func collect(includeWindowless: Bool) -> Snapshot {
		let ownPID = ProcessInfo.processInfo.processIdentifier
		let apps = NSWorkspace.shared.runningApplications.filter {
			$0.activationPolicy == .regular && $0.processIdentifier != ownPID && !$0.isTerminated
		}
		let appsByPID = Dictionary(
			apps.map { ($0.processIdentifier, $0) }, uniquingKeysWith: { a, _ in a })

		// 1. Window-server view, front to back.
		let info =
			(CGWindowListCopyWindowInfo([.optionAll, .excludeDesktopElements], kCGNullWindowID)
				as? [[String: Any]]) ?? []
		var zOrder: [CGWindowID: Int] = [:]
		var cgInfo: [CGWindowID: [String: Any]] = [:]
		for (index, entry) in info.enumerated() {
			guard let wid = entry[kCGWindowNumber as String] as? CGWindowID,
				let layer = entry[kCGWindowLayer as String] as? Int, layer == 0,
				let pid = entry[kCGWindowOwnerPID as String] as? pid_t, appsByPID[pid] != nil
			else { continue }
			zOrder[wid] = index
			cgInfo[wid] = entry
		}

		// 2. AX windows per app, concurrently with a short messaging timeout so one hung app
		// can't stall the switcher.
		let axResults = AXWindows.collect(pids: apps.map(\.processIdentifier))

		// 3. Which window ids sit on the currently visible Spaces.
		let visibleSpaceWindowIDs = Set(
			((CGWindowListCopyWindowInfo(
				[.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]])
				?? [])
				.compactMap { $0[kCGWindowNumber as String] as? CGWindowID }
		)

		var windows: [SwitcherWindow] = []
		var seen = Set<CGWindowID>()

		for (pid, axWindows) in axResults {
			guard let app = appsByPID[pid] else { continue }
			for ax in axWindows {
				guard !seen.contains(ax.id) else { continue }
				let cg = cgInfo[ax.id]
				let bounds = cg.flatMap(Self.bounds) ?? ax.frame
				guard bounds.width >= 40, bounds.height >= 40 else { continue }
				seen.insert(ax.id)
				windows.append(
					SwitcherWindow(
						id: ax.id, pid: pid,
						appName: app.localizedName ?? "",
						bundleID: app.bundleIdentifier,
						title: ax.title ?? (cg?[kCGWindowName as String] as? String) ?? "",
						bounds: bounds,
						axElement: ax.element,
						isMinimized: ax.isMinimized,
						isAppHidden: app.isHidden,
						isOnOtherSpace: !ax.isMinimized && !app.isHidden
							&& !visibleSpaceWindowIDs.contains(ax.id),
						isWindowless: false,
						isDialog: ax.isDialog
					))
			}
		}

		// Windows on other Spaces aren't in AXWindows (AX only sees the current Space). The
		// window server still lists them; keep those that sit in a real user Space.
		let otherSpaceCandidates = cgInfo.keys.filter {
			!seen.contains($0) && !visibleSpaceWindowIDs.contains($0)
		}
		let spaced = Self.windowsInSomeSpace(Array(otherSpaceCandidates))
		for wid in otherSpaceCandidates where spaced.contains(wid) {
			guard let entry = cgInfo[wid],
				let pid = entry[kCGWindowOwnerPID as String] as? pid_t,
				let app = appsByPID[pid],
				let bounds = Self.bounds(entry), bounds.width >= 100, bounds.height >= 100,
				(entry[kCGWindowAlpha as String] as? Double ?? 1) > 0
			else { continue }
			let title = entry[kCGWindowName as String] as? String ?? ""
			// Untitled off-space windows are mostly helper surfaces; titles need Screen Recording.
			guard !title.isEmpty else { continue }
			seen.insert(wid)
			windows.append(
				SwitcherWindow(
					id: wid, pid: pid, appName: app.localizedName ?? "",
					bundleID: app.bundleIdentifier,
					title: title, bounds: bounds, axElement: nil, isMinimized: false,
					isAppHidden: app.isHidden, isOnOtherSpace: true, isWindowless: false
				))
		}

		if includeWindowless {
			let withWindows = Set(windows.map(\.pid))
			for app in apps where !withWindows.contains(app.processIdentifier) {
				windows.append(
					SwitcherWindow(
						id: CGWindowID(
							UInt32.max - UInt32(truncatingIfNeeded: app.processIdentifier)),
						pid: app.processIdentifier, appName: app.localizedName ?? "",
						bundleID: app.bundleIdentifier,
						title: "", bounds: .zero, axElement: nil, isMinimized: false,
						isAppHidden: app.isHidden,
						isOnOtherSpace: false, isWindowless: true
					))
			}
		}

		return Snapshot(windows: windows, zOrder: zOrder)
	}

	private static func bounds(_ entry: [String: Any]) -> CGRect? {
		guard let dict = entry[kCGWindowBounds as String] as? NSDictionary else { return nil }
		return CGRect(dictionaryRepresentation: dict as CFDictionary)
	}

	private static func windowsInSomeSpace(_ ids: [CGWindowID]) -> Set<CGWindowID> {
		var result = Set<CGWindowID>()
		let cid = CGSMainConnectionID()
		for wid in ids {
			let list = [NSNumber(value: wid)] as CFArray
			guard
				let spaces = CGSCopySpacesForWindows(cid, 0x7, list)?.takeRetainedValue()
					as? [NSNumber],
				!spaces.isEmpty
			else { continue }
			result.insert(wid)
		}
		return result
	}
}
