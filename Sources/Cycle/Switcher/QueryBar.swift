import SwiftUI

/// What's been typed to filter the windows, shown at the top of the switcher only while
/// there's a query, with how many windows still match.
struct QueryBar: View {
	let query: String
	let matchCount: Int

	var body: some View {
		HStack(spacing: 10) {
			Image(systemName: "magnifyingglass")
				.font(.title3)
				.foregroundStyle(.secondary)
				.accessibilityHidden(true)
			SearchQueryText(query: query)
			Text("^[\(matchCount) window](inflect: true)")
				.font(.callout)
				.foregroundStyle(.tertiary)
				.monospacedDigit()
		}
		.lineLimit(1)
	}
}
