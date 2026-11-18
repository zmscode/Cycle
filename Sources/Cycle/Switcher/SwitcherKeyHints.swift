import SwiftUI

/// The switcher's main keys, as keycaps with labels.
struct SwitcherKeyHints: View {
	var body: some View {
		HStack(spacing: 14) {
			KeyHint(key: "⇥", label: "Next")
			KeyHint(key: "↑↓", label: "Move")
			KeyHint(key: "⎋", label: "Cancel")
			Text("Type to filter")
		}
		.font(.caption)
		.foregroundStyle(.secondary)
	}
}
