import SwiftUI

/// The columns-per-app layout: one column per app, its windows stacked underneath. ↑ ↓
/// move within a column, ← → between columns, and Tab walks through everything in order.
struct ColumnsView: View {
	let state: SwitcherState
	let controller: SwitcherController
	let metrics: SwitcherLayout

	@Namespace private var selection
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView(.vertical) {
				VStack(alignment: .leading, spacing: Theme.Panel.spacing * 2) {
					ForEach(Array(metrics.groupRows.enumerated()), id: \.element.first?.id) { rowIndex, row in
						HStack(alignment: .top, spacing: Theme.Panel.spacing * 2) {
							ForEach(row) { group in
								AppColumn(
									group: group, state: state, metrics: metrics,
									height: metrics.rowHeights.indices.contains(rowIndex) ? metrics.rowHeights[rowIndex] : 0,
									selection: selection, controller: controller)
							}
						}
					}
				}
				.padding(Theme.Panel.padding)
				.frame(maxWidth: .infinity)
				.animation(reduceMotion ? nil : Theme.Motion.selection, value: state.selectedID)
			}
			.scrollDisabled(!metrics.scrolls)
			.scrollIndicators(.never)
			.onChange(of: state.selectedID) { _, id in
				guard metrics.scrolls, let id else { return }
				withAnimation(reduceMotion ? nil : Theme.Motion.selection) { proxy.scrollTo(id, anchor: .center) }
			}
		}
		.frame(width: metrics.bodySize.width, height: metrics.bodySize.height)
	}
}
