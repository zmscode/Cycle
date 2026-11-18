import SwiftUI

/// A key drawn as a small keycap, for keyboard hints.
struct KeyCap: View {
	let key: String
	let label: LocalizedStringKey

	var body: some View {
		Text(key)
			.font(.callout.monospaced().bold())
			.foregroundStyle(.secondary)
			.frame(minWidth: 22, minHeight: 22)
			.background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
			.overlay {
				RoundedRectangle(cornerRadius: 6).strokeBorder(.white.opacity(0.15), lineWidth: 0.5)
			}
			.accessibilityLabel(label)
	}
}
