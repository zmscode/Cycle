import SwiftUI

/// How the switcher lays out windows.
enum SwitcherStyle: String, CaseIterable {
	/// One group per app, its windows side by side (the default).
	case grouped
	/// Thumbnails in rows, labels below.
	case grid
	/// A list with large app icons, and a big preview of the highlighted window.
	case list
	/// One card per app with its windows stacked; ↓ fans the stack out.
	case deck
	/// A strip of app icons with the highlighted app's windows on a shelf below.
	case shelf
	/// One column per app, its windows stacked underneath.
	case columns

	var title: String {
		switch self {
		case .grid: "Grid"
		case .list: "List"
		case .grouped: "Grouped by App"
		case .deck: "Stacked Deck"
		case .shelf: "App Strip and Shelf"
		case .columns: "Columns per App"
		}
	}

	var shortTitle: String {
		switch self {
		case .grouped: "By App"
		case .grid: "Grid"
		case .list: "List"
		case .deck: "Deck"
		case .shelf: "Shelf"
		case .columns: "Columns"
		}
	}

	var systemImage: String {
		switch self {
		case .grouped: "rectangle.3.group"
		case .grid: "square.grid.3x2"
		case .list: "list.bullet.rectangle"
		case .deck: "square.stack.3d.down.right"
		case .shelf: "dock.rectangle"
		case .columns: "rectangle.split.3x1"
		}
	}

	/// Layouts that keep each app's windows together in the session order.
	var groupsByApp: Bool {
		switch self {
		case .grouped, .deck, .shelf, .columns: true
		case .grid, .list: false
		}
	}

	/// Layouts where Tab, scrolling, and ← → move between apps rather than windows.
	var stepsByApp: Bool {
		self == .deck || self == .shelf
	}
}
