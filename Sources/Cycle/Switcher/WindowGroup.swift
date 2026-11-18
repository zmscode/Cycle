import Foundation

/// One app's windows in the grouped layout, as indexes into the session's window list.
struct WindowGroup: Identifiable {
	let id: String
	let indices: [Int]

	/// Groups windows by app, keeping each app at the position of its first window.
	static func groups(for windows: [SwitcherWindow]) -> [WindowGroup] {
		var order: [String] = []
		var members: [String: [Int]] = [:]
		for (index, window) in windows.enumerated() {
			let key = groupKey(window)
			if members[key] == nil { order.append(key) }
			members[key, default: []].append(index)
		}
		return order.map { WindowGroup(id: $0, indices: members[$0] ?? []) }
	}

	/// The session order the grouped layout steps through: each app's windows together.
	static func groupedOrder(_ windows: [SwitcherWindow]) -> [SwitcherWindow] {
		groups(for: windows).flatMap { group in group.indices.map { windows[$0] } }
	}

	private static func groupKey(_ window: SwitcherWindow) -> String {
		"\(window.pid)-\(window.appName)"
	}
}
