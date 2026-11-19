import SwiftUI

/// One app in the shelf's strip: a large icon with its window count as a badge, and its
/// name. The highlight slides between apps.
struct AppIconTile: View {
	let group: WindowGroup
	let state: SwitcherState
	let isSelected: Bool
	let width: CGFloat
	let selection: Namespace.ID
	let controller: SwitcherController

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Card.plateRadius) }

	private var windows: [SwitcherWindow] {
		group.indices.compactMap { $0 < state.windows.count ? state.windows[$0] : nil }
	}

	/// The window this app opens to: its selected or last selected window, else its first.
	private var targetID: CGWindowID? {
		let ids = windows.map(\.id)
		if let current = state.selectedID, ids.contains(current) { return current }
		if let last = state.lastInApp[group.id], ids.contains(last) { return last }
		return ids.first
	}

	var body: some View {
		let iconSize = min(Theme.Shelf.iconSize, width - 24)
		VStack(spacing: 4) {
			if let icon = windows.first?.icon {
				Image(nsImage: icon)
					.resizable()
					.frame(width: iconSize, height: iconSize)
					.shadow(color: .black.opacity(0.3), radius: 3, y: 2)
					.overlay(alignment: .topTrailing) {
						if windows.count > 1 {
							Text(windows.count, format: .number)
								.font(.caption2.bold().monospacedDigit())
								.foregroundStyle(.white)
								.padding(.horizontal, 5)
								.padding(.vertical, 1)
								.background(Theme.Colors.selection, in: .capsule)
								.offset(x: 6, y: -4)
						}
					}
					.accessibilityHidden(true)
			}
			Text(windows.first?.appName ?? "")
				.font(.caption)
				.bold(isSelected)
				.foregroundStyle(isSelected ? .primary : .secondary)
				.lineLimit(1)
				.truncationMode(.tail)
		}
		.padding(.horizontal, 6)
		.frame(width: width, height: width)
		.background {
			if isSelected {
				SelectionPlate(cornerRadius: Theme.Card.plateRadius)
					.matchedGeometryEffect(id: "app", in: selection)
			}
		}
		.contentShape(shape)
		.onHover(perform: hoverChanged)
		.onTapGesture(perform: select)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(windows.first?.appName ?? "")
		.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
	}

	private func hoverChanged(_ inside: Bool) {
		if inside, let targetID { controller.hover(targetID) }
	}

	private func select() {
		if let targetID { controller.click(targetID) }
	}
}
