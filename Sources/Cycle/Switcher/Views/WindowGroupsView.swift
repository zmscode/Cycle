import SwiftUI

/// The grouped layout: one glass group per app, each with its windows side by side.
struct WindowGroupsView: View {
	let state: SwitcherState
	let controller: SwitcherController
	let metrics: SwitcherLayout

	@Namespace private var selection
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView(.vertical) {
				VStack(alignment: .leading, spacing: Theme.Panel.spacing * 2) {
					ForEach(metrics.groupRows, id: \.first?.id) { row in
						HStack(alignment: .top, spacing: Theme.Panel.spacing * 2) {
							ForEach(row) { group in
								AppGroupCard(
									group: group,
									state: state,
									metrics: metrics,
									selection: selection,
									controller: controller)
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
				scroll(proxy, to: id)
			}
		}
		.frame(width: metrics.bodySize.width, height: metrics.bodySize.height)
	}

	private func scroll(_ proxy: ScrollViewProxy, to id: CGWindowID?) {
		guard metrics.scrolls, let id else { return }
		withAnimation(reduceMotion ? nil : Theme.Motion.selection) {
			proxy.scrollTo(id, anchor: .center)
		}
	}
}
