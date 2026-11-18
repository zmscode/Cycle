import AppKit
import Carbon.HIToolbox

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

/// DockDoor's `WindowCycleActivationMode`: commit when the modifier is released, or keep
/// the panel open until Return / click.
enum ActivationMode: String, CaseIterable {
	case onKeyRelease, onConfirmation
}

enum Key {
	static let tab = CGKeyCode(kVK_Tab)
	static let escape = CGKeyCode(kVK_Escape)
	static let returnKey = CGKeyCode(kVK_Return)
	static let keypadEnter = CGKeyCode(kVK_ANSI_KeypadEnter)
	static let left = CGKeyCode(kVK_LeftArrow)
	static let right = CGKeyCode(kVK_RightArrow)
	static let up = CGKeyCode(kVK_UpArrow)
	static let down = CGKeyCode(kVK_DownArrow)
	static let grave = CGKeyCode(kVK_ANSI_Grave)
	static let delete = CGKeyCode(kVK_Delete)
}

/// User settings, stored in UserDefaults under DockDoor's key names where one exists.
enum Settings {
	private static let defaults = UserDefaults.standard

	/// A stored Bool, or `fallback` when unset. `bool(forKey:)` also reads "YES"/"NO"
	/// passed as `-key value` launch arguments, which arrive as strings.
	private static func flag(_ key: String, default fallback: Bool) -> Bool {
		defaults.object(forKey: key) == nil ? fallback : defaults.bool(forKey: key)
	}

	static var modifier: InitializerModifier {
		get {
			InitializerModifier(
				rawValue: defaults.string(forKey: "keyboardInitializerModifier") ?? "") ?? .command
		}
		set { defaults.set(newValue.rawValue, forKey: "keyboardInitializerModifier") }
	}

	static var activationMode: ActivationMode {
		get {
			ActivationMode(rawValue: defaults.string(forKey: "windowSwitcherActivationMode") ?? "")
				?? .onKeyRelease
		}
		set { defaults.set(newValue.rawValue, forKey: "windowSwitcherActivationMode") }
	}

	static var currentSpaceOnly: Bool {
		get { defaults.bool(forKey: "windowSwitcherCurrentSpaceOnly") }
		set { defaults.set(newValue, forKey: "windowSwitcherCurrentSpaceOnly") }
	}

	/// The switcher layout. `layoutOverride` (set by `--demo`) wins for this run only.
	static var layout: SwitcherStyle {
		get {
			layoutOverride
				?? SwitcherStyle(rawValue: defaults.string(forKey: "windowSwitcherLayout") ?? "") ?? .grouped
		}
		set { defaults.set(newValue.rawValue, forKey: "windowSwitcherLayout") }
	}

	nonisolated(unsafe) static var layoutOverride: SwitcherStyle?

	static var showWindowlessApps: Bool {
		get { flag("windowSwitcherShowWindowlessApps", default: false) }
		set { defaults.set(newValue, forKey: "windowSwitcherShowWindowlessApps") }
	}

	static var includeHiddenWindows: Bool {
		get { flag("windowSwitcherIncludeHiddenWindows", default: true) }
		set { defaults.set(newValue, forKey: "windowSwitcherIncludeHiddenWindows") }
	}

	/// Delay before the panel appears; a quicker tap-and-release switches without it
	/// (DockDoor's `WindowSwitcherPreviewTiming.fastTap`).
	static var panelDelay: TimeInterval {
		get { defaults.object(forKey: "windowSwitcherPanelDelay") as? Double ?? 0.12 }
		set { defaults.set(newValue, forKey: "windowSwitcherPanelDelay") }
	}
}
