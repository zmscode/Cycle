import Observation

/// The settings the settings panel edits, observable so tiles update as they change.
/// Each property writes through to `Settings` (`cycle.config`) and reports the change, so an
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

	var tilingCustomPresets = Settings.tilingCustomPresets {
		didSet {
			Settings.tilingCustomPresets = tilingCustomPresets
			onChange?()
		}
	}

	/// A name field (the preset editor's, or a new workspace's) has the keyboard: the switcher lets keys through.
	@ObservationIgnored var isEditingText = false

	var tilingFillsGaps = Settings.tilingFillsGaps {
		didSet {
			Settings.tilingFillsGaps = tilingFillsGaps
			onChange?()
		}
	}

	var tilingRestoresLayouts = Settings.tilingRestoresLayouts {
		didSet {
			Settings.tilingRestoresLayouts = tilingRestoresLayouts
			onChange?()
		}
	}

	var tilingShowsDividers = Settings.tilingShowsDividers {
		didSet {
			Settings.tilingShowsDividers = tilingShowsDividers
			onChange?()
		}
	}

	var tilingAnimates = Settings.tilingAnimates {
		didSet {
			Settings.tilingAnimates = tilingAnimates
			onChange?()
		}
	}

	var tilingAnimationDuration = Settings.tilingAnimationDuration {
		didSet {
			Settings.tilingAnimationDuration = tilingAnimationDuration
			onChange?()
		}
	}

	var showPreviews = Settings.showPreviews {
		didSet {
			Settings.showPreviews = showPreviews
			onChange?()
		}
	}

	var showMenuBarIcon = Settings.showMenuBarIcon {
		didSet {
			Settings.showMenuBarIcon = showMenuBarIcon
			onChange?()
		}
	}

	var haptics = Settings.haptics {
		didSet {
			Settings.haptics = haptics
			onChange?()
		}
	}

	var tilingRightClickUndo = Settings.tilingRightClickUndo {
		didSet {
			Settings.tilingRightClickUndo = tilingRightClickUndo
			onChange?()
		}
	}

	var tilingRightClickMenu = Settings.tilingRightClickMenu {
		didSet {
			Settings.tilingRightClickMenu = tilingRightClickMenu
			onChange?()
		}
	}

	var tilingShowsNotes = Settings.tilingShowsNotes {
		didSet {
			Settings.tilingShowsNotes = tilingShowsNotes
			onChange?()
		}
	}

	var tilingWorkspaces = Settings.tilingWorkspaces {
		didSet {
			Settings.tilingWorkspaces = tilingWorkspaces
			onChange?()
		}
	}

	/// Picks up settings changed outside the panel (`cycle.config` edited by hand).
	func reload() {
		func sync<T: Equatable>(_ path: ReferenceWritableKeyPath<MenuSettings, T>, _ value: T) {
			if self[keyPath: path] != value { self[keyPath: path] = value }
		}
		sync(\.layout, Settings.layout)
		sync(\.modifier, Settings.modifier)
		sync(\.keepOpenUntilReturn, Settings.activationMode == .onConfirmation)
		sync(\.currentSpaceOnly, Settings.currentSpaceOnly)
		sync(\.includeHiddenWindows, Settings.includeHiddenWindows)
		sync(\.showWindowlessApps, Settings.showWindowlessApps)
		sync(\.tilingGap, Settings.tilingGap)
		sync(\.tilingMargin, Settings.tilingMargin)
		sync(\.tilingMainShare, Settings.tilingMainShare)
		sync(\.tilingCustomPresets, Settings.tilingCustomPresets)
		sync(\.tilingPresets, Settings.tilingPresets)
		sync(\.tilingFillsGaps, Settings.tilingFillsGaps)
		sync(\.tilingRestoresLayouts, Settings.tilingRestoresLayouts)
		sync(\.tilingShowsDividers, Settings.tilingShowsDividers)
		sync(\.tilingAnimates, Settings.tilingAnimates)
		sync(\.tilingAnimationDuration, Settings.tilingAnimationDuration)
		sync(\.tilingWorkspaces, Settings.tilingWorkspaces)
		sync(\.haptics, Settings.haptics)
		sync(\.showPreviews, Settings.showPreviews)
		sync(\.showMenuBarIcon, Settings.showMenuBarIcon)
		sync(\.tilingRightClickUndo, Settings.tilingRightClickUndo)
		sync(\.tilingRightClickMenu, Settings.tilingRightClickMenu)
		sync(\.tilingShowsNotes, Settings.tilingShowsNotes)
	}
}
