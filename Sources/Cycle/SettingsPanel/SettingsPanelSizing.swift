import CoreGraphics
import Observation

/// How tall the settings panel may be where it's opening: the space on its screen below
/// where it's anchored. Past that, its tiles scroll under a fixed header.
@Observable
@MainActor
final class SettingsPanelSizing {
	var maxHeight: CGFloat = .greatestFiniteMagnitude
}
