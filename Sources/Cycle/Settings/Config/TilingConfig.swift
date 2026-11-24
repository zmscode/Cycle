import Foundation

/// Tiling's settings in `cycle.config`.
struct TilingConfig: Codable, Equatable {
	/// Points between tiled windows.
	var gap = 10.0
	/// Points between tiled windows and the screen's edges.
	var margin = 10.0
	/// The main window's share of the width in Main + Stack and Centre (0.5–0.75).
	var mainShare = 0.6
	/// The presets on the board, by name, in the order ⌘1, ⌘2… pick them.
	var presets = TilingPreset.defaultEnabled.map(\.id)
	/// Presets made in the editor.
	var customPresets: [CustomPreset] = []
	/// Close gaps when a tiled window closes or its app quits.
	var fillGaps = true
	/// Put remembered layouts back when Cycle starts and when a tiled app reopens.
	var restoreLayouts = true
	/// Grips in the gaps between tiled windows, for resizing them.
	var showDividers = true
	/// Windows glide into place rather than jumping (off when Reduce Motion is on).
	var animate = true
	/// How long the glide takes, in seconds.
	var animationDuration = 0.12
	/// A right-click outside the switcher undoes the last tiling change (off: right-clicks
	/// reach the app underneath as usual).
	var rightClickUndo = false
	/// A right-click on a card opens the tiling menu (off: it marks the window, and
	/// Option-right-click opens the menu).
	var rightClickMenu = false
	/// A note with Undo at the foot of the switcher after each tiling change.
	var showNotes = true
	/// Saved workspaces: named layouts across every display.
	var workspaces: [Workspace] = []

	init() {}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let defaults = TilingConfig()
		gap = container.value(.gap, default: defaults.gap)
		margin = container.value(.margin, default: defaults.margin)
		mainShare = container.value(.mainShare, default: defaults.mainShare)
		presets = container.value(.presets, default: defaults.presets)
		customPresets = container.value(.customPresets, default: defaults.customPresets)
		fillGaps = container.value(.fillGaps, default: defaults.fillGaps)
		restoreLayouts = container.value(.restoreLayouts, default: defaults.restoreLayouts)
		showDividers = container.value(.showDividers, default: defaults.showDividers)
		animate = container.value(.animate, default: defaults.animate)
		animationDuration = container.value(
			.animationDuration, default: defaults.animationDuration)
		workspaces = container.value(.workspaces, default: defaults.workspaces)
		rightClickUndo = container.value(.rightClickUndo, default: defaults.rightClickUndo)
		rightClickMenu = container.value(.rightClickMenu, default: defaults.rightClickMenu)
		showNotes = container.value(.showNotes, default: defaults.showNotes)
	}
}
