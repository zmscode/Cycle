import SwiftUI

/// How the switcher lays out windows.
enum SwitcherStyle: String, CaseIterable {
	/// One group per app, its windows side by side (the default).
	case grouped
	/// Thumbnails in rows, labels below.
	case grid
	/// A list with large app icons, and a big preview of the highlighted window.
	case list

	var title: String {
		switch self {
		case .grid: "Grid"
		case .list: "List"
		case .grouped: "Grouped by App"
		}
	}

	var shortTitle: String {
		switch self {
		case .grouped: "By App"
		case .grid: "Grid"
		case .list: "List"
		}
	}

	var systemImage: String {
		switch self {
		case .grouped: "rectangle.3.group"
		case .grid: "square.grid.3x2"
		case .list: "list.bullet.rectangle"
		}
	}
}
