import SwiftUI

/// The app-strip-and-shelf layout: a row of app icons like the system's ⌘Tab, and below
/// it a shelf with the highlighted app's windows. ← → and Tab change app; ↑ ↓ move along
/// the shelf.
struct ShelfView: View {
	let state: SwitcherState
	let controller: SwitcherController
	let metrics: SwitcherLayout

	@Namespace private var appSelection
	@Namespace private var windowSelection
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private var groups: [WindowGroup] { metrics.groupRows.first ?? [] }

	private var currentApp: WindowGroup? {
		guard let index = state.windows.firstIndex(where: { $0.id == state.selectedID }) else { return groups.first }
		return groups.first { $0.indices.contains(index) }
	}

	var body: some View {
		VStack(spacing: Theme.Shelf.gap) {
			HStack(spacing: Theme.Panel.spacing) {
				ForEach(groups) { group in
					AppIconTile(
						group: group, state: state, isSelected: group.id == currentApp?.id,
						width: metrics.iconTile, selection: appSelection, controller: controller)
				}
			}
			.frame(height: metrics.iconTile)
			if let app = currentApp {
				HStack(spacing: Theme.Group.tileSpacing) {
					ForEach(app.indices, id: \.self) { index in
						if index < state.windows.count {
							let window = state.windows[index]
							GroupWindowTile(
								window: window, image: state.images[window.id],
								isSelected: window.id == state.selectedID,
								thumb: metrics.thumb(at: index),
								slot: CGSize(width: metrics.slotWidth(at: index), height: metrics.boxHeight),
								selection: windowSelection, controller: controller)
						}
					}
				}
				.id(app.id)
				.transition(.opacity)
				.frame(maxWidth: .infinity)
			}
		}
		.padding(Theme.Panel.padding)
		.frame(width: metrics.bodySize.width, height: metrics.bodySize.height, alignment: .top)
		.animation(reduceMotion ? nil : Theme.Motion.selection, value: state.selectedID)
	}
}
