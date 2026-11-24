import AppKit

/// How windows glide into place: off when the setting is off or Reduce Motion is on.
struct WindowAnimation: Sendable {
	let duration: TimeInterval

	/// The animation the settings ask for right now, or nil for none.
	@MainActor
	static var current: WindowAnimation? {
		guard Settings.tilingAnimates,
			!NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
		else { return nil }
		return WindowAnimation(duration: Settings.tilingAnimationDuration)
	}

	/// Steps at about 60 a second, a few at least and not too many for slow apps.
	var steps: Int { min(max(Int(duration * 60), 3), 24) }

	/// A strong ease-out: most of the way there in the first few frames, so a move feels
	/// immediate, then a short settle.
	func progress(atStep step: Int) -> Double {
		let t = Double(step) / Double(steps)
		return 1 - pow(1 - t, 5)
	}
}
