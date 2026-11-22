import Observation

/// The settings the settings panel edits, observable so tiles update as they change.
/// Each property writes through to `Settings` (UserDefaults) and reports the change, so an
/// open switcher can redraw at once.
@Observable
@MainActor
final class MenuSettings {
	@ObservationIgnored var onChange: (() -> Void)?

	var layout = Settings.layout {
		didSet {
			Settings.layout = layout
			onChange?()
		}
	}

	var modifier = Settings.modifier {
		didSet {
			Settings.modifier = modifier
			onChange?()
		}
	}

	var keepOpenUntilReturn = Settings.activationMode == .onConfirmation {
		didSet {
			Settings.activationMode = keepOpenUntilReturn ? .onConfirmation : .onKeyRelease
			onChange?()
		}
	}

	var currentSpaceOnly = Settings.currentSpaceOnly {
		didSet {
			Settings.currentSpaceOnly = currentSpaceOnly
			onChange?()
		}
	}

	var includeHiddenWindows = Settings.includeHiddenWindows {
		didSet {
			Settings.includeHiddenWindows = includeHiddenWindows
			onChange?()
		}
	}

	var showWindowlessApps = Settings.showWindowlessApps {
		didSet {
			Settings.showWindowlessApps = showWindowlessApps
			onChange?()
		}
	}

	var tilingGap = Settings.tilingGap {
		didSet {
			Settings.tilingGap = tilingGap
			onChange?()
		}
	}

	var tilingMargin = Settings.tilingMargin {
		didSet {
			Settings.tilingMargin = tilingMargin
			onChange?()
		}
	}

	var tilingMainShare = Settings.tilingMainShare {
		didSet {
			Settings.tilingMainShare = tilingMainShare
			onChange?()
		}
	}

	var tilingPresets = Settings.tilingPresets {
		didSet {
			Settings.tilingPresets = tilingPresets
			onChange?()
		}
	}
}
