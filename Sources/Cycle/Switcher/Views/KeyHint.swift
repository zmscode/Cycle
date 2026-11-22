import SwiftUI

/// A keycap with what the key does beside it.
struct KeyHint: View {
	let key: String
	let label: LocalizedStringKey

	var body: some View {
		HStack(spacing: 5) {
			KeyCap(key: key, label: label)
			Text(label)
		}
	}
}
