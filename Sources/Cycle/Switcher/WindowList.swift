import SwiftUI

/// The list layout: windows as rows with large app icons on the left, a big preview of
/// the highlighted window on the right — like a launcher's results with a detail pane.
struct WindowList: View {
	let state: SwitcherState
	let controller: SwitcherController
	let metrics: SwitcherLayout

	@Namespace private var selection
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		HStack(spacing: 0) {
			ScrollViewReader { proxy in
				ScrollView(.vertical) {
					VStack(spacing: 0) {
						ForEach(state.windows) { window in
							WindowListRow(
								window: window,
								isSelected: window.id == state.selectedID,
								selection: selection,
								controller: controller)
							.id(window.id)
						}
					}
					.padding(Theme.Panel.padding / 2)
					.animation(reduceMotion ? nil : Theme.Motion.selection, value: state.selectedID)
				}
				.scrollDisabled(!metrics.scrolls)
				.scrollIndicators(.never)
				.onChange(of: state.selectedID) { _, id in
					scroll(proxy, to: id)
				}
			}
			.frame(width: Theme.List.listWidth)
			Divider()
			WindowPreviewPane(
				window: state.selected,
				image: state.selectedID.flatMap { state.images[$0] },
				previewBox: metrics.previewBox,
				controller: controller)
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
