import AppKit

/// Type-to-filter.
extension SwitcherController {
	func setQuery(_ query: String) {
		guard phase == .active else { return }
		state.searchQuery = query
		state.windows =
			query.isEmpty
			? state.allWindows
			: state.allWindows.filter { Self.matches(query, $0.appName + " " + $0.title) }
		if !state.windows.contains(where: { $0.id == state.selectedID }) {
			state.selectedID = state.windows.first?.id
		}
		panel.relayout()
	}

	/// Case-insensitive subsequence match, so "chfig" finds "Chrome — Fig & Fennel".
	static func matches(_ query: String, _ text: String) -> Bool {
		var remaining = Substring(query.lowercased().filter { !$0.isWhitespace })
		for ch in text.lowercased() where ch == remaining.first {
			remaining = remaining.dropFirst()
			if remaining.isEmpty { return true }
		}
		return remaining.isEmpty
	}
}
