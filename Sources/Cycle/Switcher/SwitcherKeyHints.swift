import SwiftUI

/// The switcher's main keys, as keycaps with labels.
struct SwitcherKeyHints: View {
	var body: some View {
		HStack(spacing: 14) {
			KeyHint(key: "⇥", label: "Next")
			KeyHint(key: "W", label: "Close")
			KeyHint(key: "M", label: "Minimize")
			KeyHint(key: "Q", label: "Quit")
		}
		.font(.caption)
		.foregroundStyle(.secondary)
	}
}
