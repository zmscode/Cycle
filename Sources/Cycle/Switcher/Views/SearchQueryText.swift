import SwiftUI

/// The typed query with a caret after it, or a placeholder before anything is typed.
struct SearchQueryText: View {
	let query: String

	var body: some View {
		HStack(spacing: 1) {
			if query.isEmpty {
				Text("Search windows").foregroundStyle(.secondary)
			} else {
				Text(query).foregroundStyle(.primary)
			}
			Capsule()
				.fill(Theme.Colors.selection)
				.frame(width: 2, height: 20)
				.accessibilityHidden(true)
		}
		.font(.title3)
		.frame(maxWidth: .infinity, alignment: .leading)
	}
}
