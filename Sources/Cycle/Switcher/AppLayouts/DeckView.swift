import SwiftUI

/// The stacked-deck layout: one card per app with its windows stacked. ← → and Tab move
/// between apps; ↓ fans the current app out into tiles, ↑ closes it again.
struct DeckView: View {
	let state: SwitcherState
	let controller: SwitcherController
	let metrics: SwitcherLayout

	@Namespace private var selection
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		ScrollView(.vertical) {
			VStack(alignment: .leading, spacing: Theme.Panel.spacing * 2) {
				ForEach(metrics.groupRows, id: \.first?.id) { row in
					HStack(alignment: .top, spacing: Theme.Panel.spacing * 2) {
						ForEach(row) { group in
							if group.id == metrics.fannedAppID {
								AppGroupCard(
									group: group, state: state, metrics: metrics, selection: selection,
									controller: controller,
									size: CGSize(
										width: max(metrics.groupWidth(group), metrics.deckCard.width),
										height: metrics.deckCard.height))
							} else {
								AppDeckCard(
									group: group, state: state, metrics: metrics, selection: selection,
									controller: controller)
							}
						}
					}
				}
			}
			.padding(Theme.Panel.padding)
			.frame(maxWidth: .infinity)
			.animation(reduceMotion ? nil : Theme.Motion.selection, value: state.selectedID)
			.animation(reduceMotion ? nil : Theme.Motion.selection, value: state.fannedAppID)
		}
		.scrollDisabled(!metrics.scrolls)
		.scrollIndicators(.never)
		.frame(width: metrics.bodySize.width, height: metrics.bodySize.height)
	}
}
