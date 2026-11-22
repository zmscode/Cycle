import SwiftUI

/// Actions on a card's window, from its controls or the keyboard. DockDoor's equivalent
/// is its `PreviewAction` enum.
enum CardAction: CaseIterable {
	case quit, close, minimize, fullScreen, hide

	/// The three standard controls, in macOS order. Quit sits after them, apart.
	static let trafficLights: [CardAction] = [.close, .minimize, .fullScreen]

	var title: LocalizedStringKey {
		switch self {
		case .quit: "Quit App"
		case .close: "Close Window"
		case .minimize: "Minimize"
		case .fullScreen: "Full Screen"
		case .hide: "Hide App"
		}
	}

	var systemImage: String {
		switch self {
		case .quit: "power"
		case .close: "xmark"
		case .minimize: "minus"
		case .fullScreen: "arrow.up.left.and.arrow.down.right"
		case .hide: "eye.slash"
		}
	}

	var color: Color {
		switch self {
		case .quit: Theme.Colors.quit
		case .close: Theme.Colors.close
		case .minimize: Theme.Colors.minimize
		case .fullScreen: Theme.Colors.fullScreen
		case .hide: Theme.Colors.hide
		}
	}
}
