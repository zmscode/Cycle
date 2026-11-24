import AppKit

/// Requests a second copy of Cycle hands to the one already running (from the `cycle`
/// command line), so there's only ever one Cycle: open settings, apply a workspace.
enum RemoteRequest {
	nonisolated static let openSettings = Notification.Name("com.zms.Cycle.openSettings")
	nonisolated static let applyWorkspace = Notification.Name("com.zms.Cycle.applyWorkspace")

	/// When another Cycle is running and the arguments ask for something it can do, sends
	/// it the request and exits; otherwise returns, and this copy starts up as usual.
	static func forwardIfRunning(_ arguments: [String]) {
		let others = NSRunningApplication.runningApplications(
			withBundleIdentifier: Bundle.main.bundleIdentifier ?? "com.zms.Cycle"
		).filter { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier }
		guard !others.isEmpty else { return }
		let center = DistributedNotificationCenter.default()
		if let index = arguments.firstIndex(of: "--workspace"), arguments.indices.contains(index + 1)
		{
			center.postNotificationName(
				applyWorkspace, object: arguments[index + 1], userInfo: nil,
				deliverImmediately: true)
			exit(0)
		}
		if arguments.contains("--settings") {
			center.postNotificationName(
				openSettings, object: nil, userInfo: nil, deliverImmediately: true)
			exit(0)
		}
	}
}
