import SwiftUI

/// The glass capsule a window-state badge is drawn in.
struct StateBadgeLabel: View {
	let title: LocalizedStringKey
	let systemImage: String

	var body: some View {
		Label(title, systemImage: systemImage)
			.font(.caption.bold())
			.padding(.horizontal, 8)
			.padding(.vertical, 4)
			.glassEffect(.regular, in: .capsule)
	}
}
