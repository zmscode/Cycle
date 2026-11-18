import SwiftUI

/// The panel: what's been typed along the top (only while filtering) and the windows below, on one sheet of dark glass, like the system's own switcher.
struct SwitcherView: View {
	let state: SwitcherState
	let controller: SwitcherController
	let metrics: SwitcherLayout

	var body: some View {
		VStack(spacing: 0) {
			if metrics.showsSearchBar {
				QueryBar(query: state.searchQuery, matchCount: state.windows.count)
				.padding(.horizontal, Theme.Panel.padding + 4)
				.frame(height: metrics.headerHeight)
				Divider()
					.padding(.horizontal, Theme.Panel.padding)
			}
			switch metrics.style {
			case .grid:
				WindowGrid(state: state, controller: controller, metrics: metrics)
			case .list:
				WindowList(state: state, controller: controller, metrics: metrics)
			case .grouped:
				WindowGroupsView(state: state, controller: controller, metrics: metrics)
			}
		}
		.frame(width: metrics.fullSize.width, height: metrics.fullSize.height, alignment: .top)
		.glassSheet()
	}
}
