import SwiftUI

/// A small glass label on the thumbnail for windows that aren't plainly on screen:
/// minimized, hidden, or on another Space.
struct WindowStateBadge: View {
	let window: SwitcherWindow

	var body: some View {
		if window.isMinimized {
			StateBadgeLabel(title: "Minimized", systemImage: "minus.circle.fill")
		} else if window.isAppHidden {
			StateBadgeLabel(title: "Hidden", systemImage: "eye.slash.fill")
		} else if window.isOnOtherSpace {
			StateBadgeLabel(title: "Other Space", systemImage: "square.on.square")
		}
	}
}
