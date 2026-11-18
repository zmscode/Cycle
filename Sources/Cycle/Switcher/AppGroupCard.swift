import SwiftUI

/// An app's group: a large icon, its name and window count, and its windows as tiles.
/// The group brightens while one of its windows is selected.
struct AppGroupCard: View {
	let group: WindowGroup
	let state: SwitcherState
	let metrics: SwitcherLayout
	let selection: Namespace.ID
	let controller: SwitcherController

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Group.radius) }

	private var windows: [SwitcherWindow] {
		group.indices.compactMap { $0 < state.windows.count ? state.windows[$0] : nil }
	}

	private var containsSelection: Bool {
		windows.contains { $0.id == state.selectedID }
	}

	var body: some View {
		VStack(alignment: .leading, spacing: Theme.Group.headerGap) {
			if let first = windows.first {
				AppGroupHeader(window: first, windowCount: windows.filter { !$0.isWindowless }.count)
			}
			HStack(spacing: Theme.Group.tileSpacing) {
				ForEach(windows) { window in
					GroupWindowTile(
						window: window,
						image: state.images[window.id],
						isSelected: window.id == state.selectedID,
						thumb: metrics.thumb,
						selection: selection,
						controller: controller)
					.id(window.id)
				}
			}
		}
		.padding(Theme.Group.padding)
		.frame(
			width: SwitcherLayout.groupWidth(group, thumb: metrics.thumb),
			height: SwitcherLayout.groupHeight(thumb: metrics.thumb),
			alignment: .topLeading)
		.insetSurface(cornerRadius: Theme.Group.radius, isHighlighted: containsSelection)
		.overlay {
			// The app being switched to gets a faint blue ring.
			shape.strokeBorder(Theme.Colors.selection.opacity(containsSelection ? 0.55 : 0), lineWidth: 1.5)
		}
		.accessibilityElement(children: .contain)
	}
}
