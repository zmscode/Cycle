import SwiftUI

/// Shared sizes, colours and timings for the switcher and setup window, so every view
/// draws from one set of values.
enum Theme {
	enum Panel {
		static let radius: CGFloat = 30
		static let padding: CGFloat = 16
		static let spacing: CGFloat = 6
		static let searchHeight: CGFloat = 44
		/// The top row with the search bar turned off: just room for the settings button.
		static let compactHeaderHeight: CGFloat = 38
		static let minWidth: CGFloat = 420
	}

	enum Card {
		/// Padding between the selection plate's edge and the thumbnail.
		static let inset: CGFloat = 10
		static let plateRadius: CGFloat = 20
		static let labelGap: CGFloat = 8
		static let labelHeight: CGFloat = 36
		static let thumbAspect: CGFloat = 1.6
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
	}

	enum Group {
		static let padding: CGFloat = 10
		static let radius: CGFloat = 26
		static let headerHeight: CGFloat = 40
		static let headerGap: CGFloat = 4
		static let iconSize: CGFloat = 40
		static let tileSpacing: CGFloat = 4
		static let labelHeight: CGFloat = 18
		static let maxThumbHeight: CGFloat = 120
		static let minThumbHeight: CGFloat = 80
		static let minWidth: CGFloat = 200
	}

	enum Controls {
		static let diameter: CGFloat = 12
		static let spacing: CGFloat = 6
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
		static let selection = Animation.smooth(duration: 0.2)
		static let fade = Animation.easeOut(duration: 0.15)
	}
}
