import Foundation

/// Settings as Cycle 0.1.4 and earlier kept them, in UserDefaults; read once to create
/// `cycle.config`.
enum LegacyDefaults {
	static func config() -> CycleConfig {
		let defaults = UserDefaults.standard
		var config = CycleConfig()
		func read<T>(_ key: String, into path: WritableKeyPath<CycleConfig, T>) {
			if let value = defaults.object(forKey: key) as? T { config[keyPath: path] = value }
		}
		read("keyboardInitializerModifier", into: \.switcher.modifier)
		read("windowSwitcherActivationMode", into: \.switcher.activationMode)
		read("windowSwitcherLayout", into: \.switcher.layout)
		read("windowSwitcherCurrentSpaceOnly", into: \.switcher.currentSpaceOnly)
		read("windowSwitcherIncludeHiddenWindows", into: \.switcher.includeHiddenWindows)
		read("windowSwitcherShowWindowlessApps", into: \.switcher.showWindowlessApps)
		read("windowSwitcherPanelDelay", into: \.switcher.panelDelay)
		read("tilingGap", into: \.tiling.gap)
		read("tilingMargin", into: \.tiling.margin)
		read("tilingMainShare", into: \.tiling.mainShare)
		read("tilingPresets", into: \.tiling.presets)
		return config
	}
}
