import Foundation

/// The switcher's settings in `cycle.config`.
struct SwitcherConfig: Codable, Equatable {
	/// The modifier held with Tab: "command", "option" or "control".
	var modifier = InitializerModifier.command.rawValue
	/// "onKeyRelease" switches when the modifier is let go; "onConfirmation" waits for
	/// Return or a click.
	var activationMode = ActivationMode.onKeyRelease.rawValue
	/// "grouped", "grid" or "list".
	var layout = SwitcherStyle.grouped.rawValue
	var currentSpaceOnly = false
	var includeHiddenWindows = true
	var showWindowlessApps = false
	/// Seconds before the panel appears; a quicker tap-and-release switches without it.
	var panelDelay = 0.12
	/// Window previews (thumbnails). Off: cards show app icons, nothing is captured, and
	/// Screen Recording isn't needed.
	var showPreviews = true
	/// Trackpad haptics (marking, snapping, switching the board's display).
	var haptics = true

	init() {}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		let defaults = SwitcherConfig()
		modifier = container.value(.modifier, default: defaults.modifier)
		activationMode = container.value(.activationMode, default: defaults.activationMode)
		layout = container.value(.layout, default: defaults.layout)
		currentSpaceOnly = container.value(.currentSpaceOnly, default: defaults.currentSpaceOnly)
		includeHiddenWindows = container.value(
			.includeHiddenWindows, default: defaults.includeHiddenWindows)
		showWindowlessApps = container.value(
			.showWindowlessApps, default: defaults.showWindowlessApps)
		panelDelay = container.value(.panelDelay, default: defaults.panelDelay)
		haptics = container.value(.haptics, default: defaults.haptics)
		showPreviews = container.value(.showPreviews, default: defaults.showPreviews)
	}
}
