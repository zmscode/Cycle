import SwiftUI

/// Shared sizes, colours and timings for the switcher and setup window, so every view
/// draws from one set of values.
enum Theme {
	enum Panel {
		static let radius: CGFloat = 30
		static let padding: CGFloat = 16
		static let spacing: CGFloat = 6
		static let searchHeight: CGFloat = 44
		/// With nothing typed there's no top row at all.
		static let compactHeaderHeight: CGFloat = 0
		static let minWidth: CGFloat = 420
		/// How much the rest of the screen darkens while the switcher is open.
		static let dimOpacity: CGFloat = 0.18
	}

	enum Card {
		/// Padding between the selection plate's edge and the thumbnail.
		static let inset: CGFloat = 10
		static let plateRadius: CGFloat = 20
		static let labelGap: CGFloat = 8
		static let labelHeight: CGFloat = 36
		static let thumbAspect: CGFloat = 1.6
		/// A preview fits a box this many times wider than it is tall.
		static let boxAspect: CGFloat = 1.9
		/// Window aspect ratios are kept within these, so very thin windows stay legible.
		static let minAspect: CGFloat = 0.45
		static let maxAspect: CGFloat = 2.6
		/// Size relative to the largest window: (area ratio) ^ scaleCurve, at least minScale.
		static let scaleCurve: CGFloat = 0.2
		static let minScale: CGFloat = 0.75
		static let windowlessScale: CGFloat = 0.7
		/// A card is never narrower than this, so its label stays readable.
		/// Wide enough for the header row: controls, icon and a readable name.
		static let minSlotWidth: CGFloat = 214
		static let maxThumbHeight: CGFloat = 150
		static let minThumbHeight: CGFloat = 96
		static let iconSize: CGFloat = 18
		/// With previews off, a grid card is the app's icon over the window's title.
		static let iconCardIcon: CGFloat = 56
		static let iconCardWidth: CGFloat = 132
		/// The controls row above the icon, kept even while the controls are hidden so
		/// nothing moves when they appear.
		static let iconCardControls: CGFloat = 22
		/// Concentric with the plate: its radius minus the inset.
		static var thumbRadius: CGFloat { plateRadius - inset }
	}

	enum List {
		static let rowHeight: CGFloat = 52
		static let iconSize: CGFloat = 34
		static let maxVisibleRows = 9
		static let listWidth: CGFloat = 440
		static let previewWidth: CGFloat = 400
		static let minHeight: CGFloat = 320
		/// Room in the detail pane for the title, app name and key hints under the preview.
		static let previewChrome: CGFloat = 150
	}

	enum Group {
		static let padding: CGFloat = 10
		static let radius: CGFloat = 26
		static let headerHeight: CGFloat = 40
		static let headerGap: CGFloat = 4
		static let iconSize: CGFloat = 40
		static let tileSpacing: CGFloat = 4
		static let labelHeight: CGFloat = 22
		static let maxThumbHeight: CGFloat = 120
		static let minThumbHeight: CGFloat = 80
		static let minWidth: CGFloat = 200
		/// With previews off, each window in a group is a title row this wide.
		static let iconTileWidth: CGFloat = 224
	}

	/// The floating settings button in the screen's top-right corner.
	enum Gear {
		static let diameter: CGFloat = 40
		static let gap: CGFloat = 10
		/// Inset from the screen's top-right corner.
		static let margin: CGFloat = 16
	}

	/// Drag-to-tile: the board under the switcher and the frames it gives windows.
	enum Tiling {
		/// Space between tiled windows, and between them and the screen's edge.
		static let gap: CGFloat = 10
		static let minimumTileSize = CGSize(width: 240, height: 160)
		/// Holding a card this long (or dragging it) picks it up.
		static let holdDelay: TimeInterval = 0.22
		static let dragThreshold: CGFloat = 5
		static let boardWidth: CGFloat = 420
		static let boardPadding: CGFloat = 12
		static let boardHeaderHeight: CGFloat = 22
		static let boardRadius: CGFloat = 24
		static let tileRadius: CGFloat = 6
		/// Space between the switcher and the board.
		static let boardOffset: CGFloat = 16
		/// The pointer still counts as on the board this far outside it.
		static let boardSlack: CGFloat = 24
		/// Near the screen's edge (this fraction of its shorter side), a drop goes along the
		/// whole edge rather than beside one window.
		static let outerBand: CGFloat = 0.05
		/// A tiled window moved or resized by more than this is no longer tiled.
		static let movedTolerance: CGFloat = 24
		static let ghostWidth: CGFloat = 150
		/// How wide the board's divider grips are to grab.
		static let boardGripThickness: CGFloat = 12
		/// Over a drop target the ghost shrinks to this share of its size, its top-left
		/// corner this far down and right of the pointer, clear of the slot being aimed at.
		static let ghostAsideScale: CGFloat = 0.4
		static let ghostAsideGap: CGFloat = 14
		/// Preset chips under the board.
		static let chipMaxWidth: CGFloat = 64
		static let chipSpacing: CGFloat = 10
		static let chipsGap: CGFloat = 12
		static let chipLabelHeight: CGFloat = 18
		/// Space between slots in a preset's small picture.
		static let chipGap: CGFloat = 2
		/// The displays in the board's header, while there's more than one.
		static let displayChipHeight: CGFloat = 18
		/// A window this much bigger than its slot (a share of the slot) gets room made for
		/// it; a bigger one is outlined on the board instead.
		static let fitTolerance: CGFloat = 0.15
		/// How long windows dropped where they can't land take to fade away.
		static let evaporateDuration: TimeInterval = 0.25
		/// Resting on a display chip this long mid-drag switches the board to it.
		static let displayDwell: TimeInterval = 0.4
	}

	enum Controls {
		static let diameter: CGFloat = 12
		static let spacing: CGFloat = 4
	}

	enum Colors {
		/// The system accent colour (System Settings → Appearance). `controlAccentColor` is
		/// dynamic, so it follows changes live, and unlike `Color.accentColor` it doesn't
		/// turn grey in Cycle's panels, which never become the active window.
		static let selection = Color(nsColor: .controlAccentColor)
		/// Tiling's marks, drop highlights and preview outlines: the accent colour, unless
		/// it's Graphite, where grey marks would vanish against grey tiles; then blue.
		static var mark: Color {
			let accent = NSColor.controlAccentColor.usingColorSpace(.deviceRGB)
			return (accent?.saturationComponent ?? 0) < 0.15
				? Color(nsColor: .systemBlue) : Color(nsColor: .controlAccentColor)
		}
		static let close = Color(red: 1.0, green: 0.37, blue: 0.34)
		static let minimize = Color(red: 1.0, green: 0.74, blue: 0.18)
		static let fullScreen = Color(red: 0.16, green: 0.79, blue: 0.25)
		static let quit = Color(red: 0.62, green: 0.40, blue: 0.95)
		static let hide = Color.gray
	}

	enum Motion {
		/// Quick and interruptible, so rapid steps (scrolling, held arrows) flow into one
		/// another instead of queueing.
		static let selection = Animation.snappy(duration: 0.16)
		static let fade = Animation.easeOut(duration: 0.15)
	}
}
