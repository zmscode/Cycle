import AppKit
import RiftCore

/// Workspaces: the remembered layouts of every display, saved under a name and put back
/// later. Applying one opens the apps it needs that aren't running, then tiles their
/// windows as they appear, matched the way remembered layouts are (window id, then app and
/// title, then app). A display that isn't connected is skipped. Each display it lays out
/// is one undo step.
extension TilingCoordinator {
	/// The layouts now, as a workspace named `name`; nil when nothing is tiled.
	func captureWorkspace(named name: String) -> Workspace? {
		let displays = store.remembered.filter { !$0.value.paneIDs.isEmpty }
		guard displays.values.contains(where: { tree in
			tree.paneIDs.contains { if case .window = $0 { true } else { false } }
		})
		else { return nil }
		return Workspace(name: name, displays: displays)
	}

	/// Lays out every connected display in `workspace`. Returns how many of its displays
	/// aren't connected (and were skipped).
	@discardableResult
	func apply(_ workspace: Workspace) -> Int {
		let connected = workspace.displays.filter { NSScreen.screen(uuid: $0.key) != nil }
		for (display, tree) in connected {
			record(display, label: workspace.name)
			store.replace(tree, for: display)
		}
		watcher.keep(only: store.tiledWindowIDs)
		for display in connected.keys { onLayoutChanged?(display, store.layout(for: display)) }
		Self.launchMissingApps(for: workspace)
		loader.load(includeWindowless: false) { [weak self] snapshot in
			MainActor.assumeIsolated { self?.restore(from: snapshot.windows, force: true) }
		}
		// Apps just opened take a while to show their windows.
		scheduleRestore(after: [1, 2.5, 5, 10, 20], force: true)
		return workspace.displays.count - connected.count
	}

	/// The workspace named `name` (ignoring case), from `cycle.config`.
	func workspace(named name: String) -> Workspace? {
		Settings.tilingWorkspaces.first {
			$0.name.compare(name, options: .caseInsensitive) == .orderedSame
		}
	}

	private static func launchMissingApps(for workspace: Workspace) {
		for bundleID in workspace.bundleIDs
		where NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).isEmpty {
			guard let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID)
			else { continue }
			let configuration = NSWorkspace.OpenConfiguration()
			configuration.activates = false
			NSWorkspace.shared.openApplication(at: url, configuration: configuration)
		}
	}
}
