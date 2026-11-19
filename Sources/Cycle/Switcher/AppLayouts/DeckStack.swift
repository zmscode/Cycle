import SwiftUI

/// An app's windows as a stack: the front preview with up to two more peeking out behind
/// it, each a little smaller and fainter.
struct DeckStack: View {
	let windows: [SwitcherWindow]
	let state: SwitcherState
	let metrics: SwitcherLayout
	let isSelected: Bool

	private var peek: CGFloat { Theme.Deck.peek }

	var body: some View {
		let frontIndex = windows.first.flatMap { front in state.windows.firstIndex { $0.id == front.id } } ?? 0
		let size = metrics.thumb(at: frontIndex)
		ZStack {
			ForEach(Array(windows.enumerated().reversed()), id: \.element.id) { depth, window in
				WindowThumbnail(
					window: window, image: state.images[window.id], size: size,
					isSelected: depth == 0 && isSelected)
				.scaleEffect(1 - CGFloat(depth) * 0.05)
				.offset(x: CGFloat(depth) * peek, y: -CGFloat(depth) * peek)
				.opacity(depth == 0 ? 1 : 0.75 - Double(depth) * 0.15)
				.allowsHitTesting(depth == 0)
			}
		}
		.frame(
			width: metrics.deckCard.width - Theme.Group.padding * 2,
			height: metrics.boxHeight + peek * CGFloat(Theme.Deck.layers - 1) + Theme.Card.inset)
		.offset(y: peek)
	}
}
