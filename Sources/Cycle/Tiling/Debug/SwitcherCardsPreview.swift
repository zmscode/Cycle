#if DEBUG
	import SwiftUI

	/// The switcher's cards without the scroll view around them, for offscreen renders
	/// (ImageRenderer leaves scroll views blank).
	struct SwitcherCardsPreview: View {
		let state: SwitcherState
		let controller: SwitcherController
		let metrics: SwitcherLayout

		@Namespace private var selection

		var body: some View {
			VStack(alignment: .leading, spacing: Theme.Panel.spacing) {
				switch metrics.style {
				case .grouped:
					ForEach(Array(metrics.groupRows.enumerated()), id: \.offset) { _, row in
						HStack(alignment: .top, spacing: Theme.Panel.spacing * 2) {
							ForEach(row) { group in
								AppGroupCard(
									group: group, state: state, metrics: metrics,
									selection: selection, controller: controller)
							}
						}
					}
				default:
					ForEach(metrics.rows, id: \.self) { row in
						HStack(spacing: Theme.Panel.spacing) {
							ForEach(row, id: \.self) { index in
								let window = state.windows[index]
								WindowCard(
									window: window, image: nil,
									isSelected: window.id == state.selectedID,
									thumbSize: metrics.thumb(at: index),
									slot: CGSize(
										width: metrics.slotWidth(at: index),
										height: metrics.slotHeight(at: index)),
									cardSize: CGSize(
										width: metrics.cardWidth(at: index),
										height: metrics.cardHeight(at: index)),
									selection: selection, controller: controller)
							}
						}
					}
				}
			}
			.padding(Theme.Panel.padding)
			.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
		}
	}
#endif
