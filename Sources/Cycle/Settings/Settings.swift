import Foundation

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

	/// The switcher layout.
	static var layout: SwitcherStyle {
		get {
			SwitcherStyle(rawValue: defaults.string(forKey: "windowSwitcherLayout") ?? "")
				?? .grouped
		}
		set { defaults.set(newValue.rawValue, forKey: "windowSwitcherLayout") }
	}

	static var showWindowlessApps: Bool {
		get { flag("windowSwitcherShowWindowlessApps", default: false) }
		set { defaults.set(newValue, forKey: "windowSwitcherShowWindowlessApps") }
	}

	static var includeHiddenWindows: Bool {
		get { flag("windowSwitcherIncludeHiddenWindows", default: true) }
		set { defaults.set(newValue, forKey: "windowSwitcherIncludeHiddenWindows") }
	}

	/// Space between tiled windows, in points.
	static var tilingGap: Double {
		get { defaults.object(forKey: "tilingGap") as? Double ?? 10 }
		set { defaults.set(newValue, forKey: "tilingGap") }
	}

	/// Space between tiled windows and the screen's edges, in points.
	static var tilingMargin: Double {
		get { defaults.object(forKey: "tilingMargin") as? Double ?? 10 }
		set { defaults.set(newValue, forKey: "tilingMargin") }
	}

	/// The main window's share of the width in the Main + Stack and Centre presets.
	static var tilingMainShare: Double {
		get { defaults.object(forKey: "tilingMainShare") as? Double ?? 0.6 }
		set { defaults.set(newValue, forKey: "tilingMainShare") }
	}

	/// The presets shown on the tiling board, in their usual order.
	static var tilingPresets: [TilingPreset] {
		get {
			guard let names = defaults.stringArray(forKey: "tilingPresets") else {
				return TilingPreset.defaultEnabled
			}
			let enabled = Set(names)
			return TilingPreset.allCases.filter { enabled.contains($0.rawValue) }
		}
		set { defaults.set(newValue.map(\.rawValue), forKey: "tilingPresets") }
	}

	/// Delay before the panel appears; a quicker tap-and-release switches without it
	/// (DockDoor's `WindowSwitcherPreviewTiming.fastTap`).
	static var panelDelay: TimeInterval {
		get { defaults.object(forKey: "windowSwitcherPanelDelay") as? Double ?? 0.12 }
		set { defaults.set(newValue, forKey: "windowSwitcherPanelDelay") }
	}
}
