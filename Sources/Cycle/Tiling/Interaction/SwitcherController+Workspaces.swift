import AppKit

/// Requests from the `cycle` command line, handed over by a second copy of Cycle (see
/// `RemoteRequest`): apply a workspace, open settings.
extension SwitcherController {
	func listenForRemoteRequests() {
		let center = DistributedNotificationCenter.default()
		center.addObserver(forName: RemoteRequest.applyWorkspace, object: nil, queue: .main) {
			[weak self] note in
			guard let name = note.object as? String else { return }
			MainActor.assumeIsolated { self?.applyWorkspace(named: name) }
		}
		center.addObserver(forName: RemoteRequest.openSettings, object: nil, queue: .main) {
			[weak self] _ in
			MainActor.assumeIsolated { self?.settingsPanel.showStandalone() }
		}
	}

	/// Applies the saved workspace called `name` (ignoring case), if there is one.
	func applyWorkspace(named name: String) {
		guard let workspace = tiling.workspace(named: name) else {
			FileHandle.standardError.write(Data("Cycle: no workspace named \(name)\n".utf8))
			return
		}
		tiling.apply(workspace)
	}
}
