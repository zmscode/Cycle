import AppKit
import RiftCore

/// Undo: each drop, preset and divider drag remembers the layout from before, and undo
/// puts the last one back (right-click outside the switcher).
extension TilingCoordinator {
	/// Deep enough to unwind a whole session's rearranging.
	private static let historyLimit = 100

	var canUndo: Bool { !history.isEmpty }

	/// What undo would put back ("Thirds", "Resize"), if anything.
	var undoLabel: String? { history.last?.label }

	/// Remembers `display`'s layout before a change named `label`.
	func record(_ display: String, label: String) {
		history.append(
			TilingChange(display: display, before: store.tree(for: display), label: label))
		if history.count > Self.historyLimit { history.removeFirst() }
	}

	/// Undoes the last change: its display's layout goes back, and the windows still open
	/// return to their places. Calls `done` with what was undone, or nil with nothing to undo.
	func undo(done: @escaping (String?) -> Void) {
		guard let change = history.popLast() else { return done(nil) }
		loader.load(includeWindowless: false) { [weak self] snapshot in
			MainActor.assumeIsolated {
				guard let self else { return }
				self.store.restore(change.before, for: change.display, windows: snapshot.windows)
				self.onLayoutChanged?(change.display, self.store.layout(for: change.display))
				self.retile([change.display], windows: snapshot.windows)
				done(change.label)
			}
		}
	}
}
