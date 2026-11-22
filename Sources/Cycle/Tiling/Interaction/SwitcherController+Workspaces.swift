import AppKit

/// `Cycle --workspace <name>` from the command line: a second copy of Cycle hands the
/// name to the one running and exits; the running one applies it.
extension SwitcherController {
	nonisolated static let workspaceRequest = Notification.Name("com.zms.Cycle.applyWorkspace")

	func listenForWorkspaceRequests() {
		DistributedNotificationCenter.default().addObserver(
			forName: Self.workspaceRequest, object: nil, queue: .main
		) { [weak self] note in
			guard let name = note.object as? String else { return }
			MainActor.assumeIsolated { self?.applyWorkspace(named: name) }
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
