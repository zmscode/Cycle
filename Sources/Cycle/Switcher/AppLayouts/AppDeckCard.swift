import SwiftUI

/// A closed deck card: the app's icon and name, the front window's controls and title,
/// and its windows stacked with the front one on top. The front window is the one
/// selected in this app (or last selected there).
struct AppDeckCard: View {
	let group: WindowGroup
	let state: SwitcherState
	let metrics: SwitcherLayout
	let selection: Namespace.ID
	let controller: SwitcherController

	@State private var isHovering = false

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Group.radius) }

	private var windows: [SwitcherWindow] {
		group.indices.compactMap { $0 < state.windows.count ? state.windows[$0] : nil }
	}

	private var isCurrentApp: Bool { windows.contains { $0.id == state.selectedID } }

	/// Front first, then the rest in order.
	private var stack: [SwitcherWindow] {
		let frontID = windows.first { $0.id == state.selectedID }?.id
			?? state.lastInApp[group.id].flatMap { id in windows.first { $0.id == id }?.id }
			?? windows.first?.id
		guard let front = windows.first(where: { $0.id == frontID }) else { return windows }
		return [front] + windows.filter { $0.id != front.id }
	}

	var body: some View {
		let ordered = stack
		VStack(alignment: .leading, spacing: Theme.Group.headerGap) {
			if let first = windows.first {
				AppGroupHeader(window: first, windowCount: windows.filter { !$0.isWindowless }.count)
			}
			if let front = ordered.first {
				DeckFrontRow(
					window: front, position: (windows.firstIndex { $0.id == front.id } ?? 0) + 1,
					count: windows.count, isActive: isCurrentApp || isHovering, isSelected: isCurrentApp,
					onAction: { controller.perform($0, on: front.id) })
				DeckStack(
					windows: Array(ordered.prefix(Theme.Deck.layers)), state: state, metrics: metrics,
					isSelected: isCurrentApp)
			}
		}
		.padding(Theme.Group.padding)
		.frame(width: metrics.deckCard.width, height: metrics.deckCard.height, alignment: .topLeading)
		.background {
			if isCurrentApp {
				SelectionPlate(cornerRadius: Theme.Group.radius)
					.matchedGeometryEffect(id: "selection", in: selection)
			}
		}
		.insetSurface(cornerRadius: Theme.Group.radius, isHighlighted: isCurrentApp)
		.contentShape(shape)
		.onHover(perform: hoverChanged)
		.onTapGesture(perform: select)
		.accessibilityElement(children: .contain)
		.accessibilityLabel(windows.first?.appName ?? "")
		.accessibilityAddTraits(isCurrentApp ? [.isButton, .isSelected] : .isButton)
	}

	private var frontID: CGWindowID? { stack.first?.id }

	private func hoverChanged(_ inside: Bool) {
		isHovering = inside
		if inside, let frontID { controller.hover(frontID) }
	}

	private func select() {
		if let frontID { controller.click(frontID) }
	}
}
