import CoreGraphics

/// The held modifier that opens the switcher — DockDoor's `KeyboardInitializerModifier`
/// (option / control / command / shift). The trailing key is Tab.
enum InitializerModifier: String, CaseIterable {
	case command, option, control

	var flag: CGEventFlags {
		switch self {
		case .command: .maskCommand
		case .option: .maskAlternate
		case .control: .maskControl
		}
	}

	var name: String {
		switch self {
		case .command: "Command"
		case .option: "Option"
		case .control: "Control"
		}
	}

	var symbol: String {
		switch self {
		case .command: "⌘"
		case .option: "⌥"
		case .control: "⌃"
		}
	}
}
