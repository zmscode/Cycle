import SwiftUI

/// The panel's top row: the settings button, then the search bar when it's turned on (or
/// while searching).
struct SwitcherHeader: View {
	let state: SwitcherState
	let controller: SwitcherController
	let metrics: SwitcherLayout

	var body: some View {
		HStack(spacing: 12) {
			SettingsButton(isOpen: state.isShowingSettings, onToggle: controller.toggleSettings)
			if metrics.showsSearchBar {
				SearchBar(
					isSearching: state.isSearching,
					query: state.searchQuery,
					windowCount: state.windows.count,
					previewsAllowed: Permissions.shared.screenRecording)
			} else {
				Spacer()
			}
		}
		.padding(.horizontal, Theme.Panel.padding)
		.frame(height: metrics.headerHeight)
	}
}
