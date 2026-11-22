import AppKit

/// Trackpad haptics, used for what each pattern means (see the HIG's Playing haptics):
/// alignment when something snaps into line, generic for other confirmations. Off when the
/// Haptics setting is.
@MainActor
enum Haptics {
	/// A dragged divider snapped to the middle.
	static func aligned() {
		play(.alignment)
	}

	/// A discrete change took effect: a window marked, the board switched display, marked
	/// windows rotated through a preset's slots.
	static func confirm() {
		play(.generic)
	}

	private static func play(_ pattern: NSHapticFeedbackManager.FeedbackPattern) {
		guard Settings.haptics else { return }
		NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
	}
}
