import SwiftUI

/// One app's column: its icon and name, then each window's controls, title and preview,
/// stacked. Every preview is fitted to the column width, so the column is only as tall
/// as its own windows.
struct AppColumn: View {
	let group: WindowGroup
	let state: SwitcherState
	let metrics: SwitcherLayout
	let height: CGFloat
	let selection: Namespace.ID
	let controller: SwitcherController

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Group.radius) }

	private var windows: [SwitcherWindow] {
		group.indices.compactMap { $0 < state.windows.count ? state.windows[$0] : nil }
	}

	private var containsSelection: Bool { windows.contains { $0.id == state.selectedID } }

	var body: some View {
		VStack(alignment: .leading, spacing: Theme.Group.headerGap) {
			if let first = windows.first {
				AppGroupHeader(window: first, windowCount: windows.filter { !$0.isWindowless }.count)
			}
			VStack(spacing: Theme.Group.tileSpacing) {
				ForEach(group.indices, id: \.self) { index in
					if index < state.windows.count {
						let window = state.windows[index]
						GroupWindowTile(
							window: window, image: state.images[window.id],
							isSelected: window.id == state.selectedID,
							thumb: metrics.thumb(at: index),
							slot: CGSize(width: metrics.slotWidth(at: index), height: metrics.slotHeight(at: index)),
							selection: selection, controller: controller)
						.id(window.id)
					}
				}
			}
		}
		.padding(Theme.Group.padding)
		.frame(width: metrics.columnWidth, height: height, alignment: .topLeading)
		.insetSurface(cornerRadius: Theme.Group.radius, isHighlighted: containsSelection)
		.overlay {
			shape.strokeBorder(Theme.Colors.selection.opacity(containsSelection ? 0.55 : 0), lineWidth: 1.5)
		}
		.accessibilityElement(children: .contain)
	}
}
