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
	}

	/// The floating settings button in the screen's top-right corner.
	enum Gear {
		static let diameter: CGFloat = 40
		static let gap: CGFloat = 10
		/// Inset from the screen's top-right corner.
		static let margin: CGFloat = 16
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
