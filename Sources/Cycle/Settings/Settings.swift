import Foundation

/// User settings, kept in `cycle.config` (see `ConfigStore`).
enum Settings {
	private static var store: ConfigStore { .shared }
	private static var switcher: SwitcherConfig { store.config.switcher }
	private static var tiling: TilingConfig { store.config.tiling }

	static var modifier: InitializerModifier {
		get { InitializerModifier(rawValue: switcher.modifier) ?? .command }
		set { store.update { $0.switcher.modifier = newValue.rawValue } }
	}

	static var activationMode: ActivationMode {
		get { ActivationMode(rawValue: switcher.activationMode) ?? .onKeyRelease }
		set { store.update { $0.switcher.activationMode = newValue.rawValue } }
	}

	static var currentSpaceOnly: Bool {
		get { switcher.currentSpaceOnly }
		set { store.update { $0.switcher.currentSpaceOnly = newValue } }
	}

	/// The switcher layout.
	static var layout: SwitcherStyle {
		get { SwitcherStyle(rawValue: switcher.layout) ?? .grouped }
		set { store.update { $0.switcher.layout = newValue.rawValue } }
	}

	static var showWindowlessApps: Bool {
		get { switcher.showWindowlessApps }
		set { store.update { $0.switcher.showWindowlessApps = newValue } }
	}

	static var includeHiddenWindows: Bool {
		get { switcher.includeHiddenWindows }
		set { store.update { $0.switcher.includeHiddenWindows = newValue } }
	}

	/// Delay before the panel appears; a quicker tap-and-release switches without it
	/// (DockDoor's `WindowSwitcherPreviewTiming.fastTap`).
	static var panelDelay: TimeInterval {
		get { max(switcher.panelDelay, 0) }
		set { store.update { $0.switcher.panelDelay = newValue } }
	}

	/// Space between tiled windows, in points.
	static var tilingGap: Double {
		get { max(tiling.gap, 0) }
		set { store.update { $0.tiling.gap = newValue } }
	}

	/// Space between tiled windows and the screen's edges, in points.
	static var tilingMargin: Double {
		get { max(tiling.margin, 0) }
		set { store.update { $0.tiling.margin = newValue } }
	}

	/// The main window's share of the width in the Main + Stack and Centre presets.
	static var tilingMainShare: Double {
		get { min(max(tiling.mainShare, 0.3), 0.8) }
		set { store.update { $0.tiling.mainShare = newValue } }
	}

	/// The presets shown on the tiling board, in the order ⌘1, ⌘2… apply them. Unknown
	/// names are skipped.
	static var tilingPresets: [TilingPreset] {
		get {
			var seen = Set<String>()
			let customs = tiling.customPresets
			return tiling.presets.compactMap { TilingPreset.named($0, customs: customs) }.filter {
				seen.insert($0.id).inserted
			}
		}
		set { store.update { $0.tiling.presets = newValue.map(\.id) } }
	}

	/// Presets made in the editor (shown on the board only once turned on in `tilingPresets`).
	static var tilingCustomPresets: [CustomPreset] {
		get { tiling.customPresets }
		set { store.update { $0.tiling.customPresets = newValue } }
	}

	/// Close gaps when a tiled window closes or its app quits.
	static var tilingFillsGaps: Bool {
		get { tiling.fillGaps }
		set { store.update { $0.tiling.fillGaps = newValue } }
	}

	/// Put remembered layouts back when Cycle starts and when a tiled app reopens.
	static var tilingRestoresLayouts: Bool {
		get { tiling.restoreLayouts }
		set { store.update { $0.tiling.restoreLayouts = newValue } }
	}

	/// Grips in the gaps between tiled windows, for resizing them.
	static var tilingShowsDividers: Bool {
		get { tiling.showDividers }
		set { store.update { $0.tiling.showDividers = newValue } }
	}

	/// Windows glide into place rather than jumping.
	static var tilingAnimates: Bool {
		get { tiling.animate }
		set { store.update { $0.tiling.animate = newValue } }
	}

	/// How long windows take to glide into place, in seconds (0.05–0.5).
	static var tilingAnimationDuration: Double {
		get { min(max(tiling.animationDuration, 0.05), 0.5) }
		set { store.update { $0.tiling.animationDuration = newValue } }
	}
}
