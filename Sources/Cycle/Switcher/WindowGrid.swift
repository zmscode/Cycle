import SwiftUI

/// Rows of windows. The selection plate is one shape that slides between cards
/// (`matchedGeometryEffect`), as the system switcher's highlight does.
struct WindowGrid: View {
	let state: SwitcherState
	let controller: SwitcherController
	let metrics: SwitcherLayout

	@Namespace private var selection
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		ScrollViewReader { proxy in
			ScrollView(.vertical) {
				VStack(alignment: .leading, spacing: Theme.Panel.spacing) {
					ForEach(metrics.rows, id: \.self) { row in
						HStack(spacing: Theme.Panel.spacing) {
							ForEach(row, id: \.self) { index in
								if index < state.windows.count {
									let window = state.windows[index]
									WindowCard(
										window: window,
										image: state.images[window.id],
										isSelected: window.id == state.selectedID,
										thumbSize: metrics.thumb(at: index),
										slot: CGSize(width: metrics.slotWidth(at: index), height: metrics.boxHeight),
										cardSize: CGSize(width: metrics.cardWidth(at: index), height: metrics.cardHeight),
										selection: selection,
										controller: controller)
									.id(window.id)
								}
							}
						}
					}
				}
				.padding([.horizontal, .top], Theme.Panel.padding)
				.padding(.bottom, Theme.Panel.padding)
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
