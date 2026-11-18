import Foundation

/// Loads window snapshots on a background queue, one at a time. Requests that arrive while
/// a load is running share its result instead of queueing more work, so rapid ⌘Tab
/// presses never pile up scans or block the keyboard tap.
@MainActor
final class WindowLoader {
	private let queue = DispatchQueue(label: "Cycle.windows", qos: .userInteractive)
	private var isLoading = false
	private var waiters: [(WindowEnumerator.Snapshot) -> Void] = []

	func load(includeWindowless: Bool, completion: @escaping (WindowEnumerator.Snapshot) -> Void) {
		waiters.append(completion)
		guard !isLoading else { return }
		isLoading = true
		queue.async { [weak self] in
			let snapshot = WindowEnumerator.collect(includeWindowless: includeWindowless)
			DispatchQueue.main.async {
				MainActor.assumeIsolated { self?.deliver(snapshot) }
			}
		}
	}

	private func deliver(_ snapshot: WindowEnumerator.Snapshot) {
		isLoading = false
		let waiting = waiters
		waiters = []
		waiting.forEach { $0(snapshot) }
	}
}
