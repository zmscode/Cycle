import SwiftUI

/// The search field in the panel's top row: the query (or a hint), then the window count
/// and the search key.
struct SearchBar: View {
	let isSearching: Bool
	let query: String
	let windowCount: Int
	let previewsAllowed: Bool

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: "magnifyingglass")
				.font(.title3)
				.foregroundStyle(isSearching ? .primary : .secondary)
				.accessibilityHidden(true)
			if isSearching {
				SearchQueryText(query: query)
			} else {
				Text("Switch windows")
					.font(.title3)
					.foregroundStyle(.secondary)
					.frame(maxWidth: .infinity, alignment: .leading)
			}
			if !previewsAllowed {
				// Without Screen Recording the cards fall back to app icons; say why.
				Label("Previews off", systemImage: "eye.slash")
					.font(.callout)
					.foregroundStyle(.secondary)
					.help("Allow Screen Recording for window previews")
			}
			Text("^[\(windowCount) window](inflect: true)")
				.font(.callout)
				.foregroundStyle(.tertiary)
				.monospacedDigit()
			if !isSearching {
				KeyCap(key: ",", label: "Comma to search")
			}
		}
		.lineLimit(1)
	}
}
