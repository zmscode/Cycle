import SwiftUI

/// "Accessibility · Allowed" with a green or orange status dot.
struct PermissionStatusRow: View {
	let title: LocalizedStringKey
	let granted: Bool

	var body: some View {
		HStack(spacing: 8) {
			Circle()
				.fill(granted ? .green : .orange)
				.frame(width: 8, height: 8)
				.accessibilityHidden(true)
			Text(title).font(.callout)
			Spacer()
			Text(granted ? "Allowed" : "Not Allowed")
				.font(.caption)
				.foregroundStyle(.secondary)
		}
	}
}
