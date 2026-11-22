import SwiftUI

/// One list row: a large app icon, the window title over the app name, and the window's
/// state on the right. The highlight slides between rows.
struct WindowListRow: View {
	let window: SwitcherWindow
	let isSelected: Bool
	let selection: Namespace.ID
	let controller: SwitcherController

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 12) }

	var body: some View {
		HStack(spacing: 12) {
			if let icon = window.icon {
				Image(nsImage: icon)
					.resizable()
					.frame(width: Theme.List.iconSize, height: Theme.List.iconSize)
					.accessibilityHidden(true)
					.markBadge(controller.state.markNumber(window.id))
			}
			VStack(alignment: .leading, spacing: 1) {
				Text(window.displayTitle)
					.font(.body)
					.bold(isSelected)
				if !window.isWindowless {
					Text(window.appName)
						.font(.callout)
						.foregroundStyle(.secondary)
				}
			}
			.lineLimit(1)
			.truncationMode(.middle)
			Spacer(minLength: 8)
			WindowStateBadge(window: window)
		}
		.padding(.horizontal, 10)
		.frame(height: Theme.List.rowHeight)
		.background {
			if isSelected {
				shape
					.fill(Theme.Colors.selection.opacity(0.55))
					.matchedGeometryEffect(id: "selection", in: selection)
			}
		}
		.contentShape(shape)
		.onHover(perform: hoverChanged)
		.onTapGesture(perform: select)
		.accessibilityElement(children: .combine)
		.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
		.tilingAccessibilityActions(window.id, controller: controller)
	}

	private func hoverChanged(_ inside: Bool) {
		if inside { controller.hover(window.id) } else { controller.hoverEnded(window.id) }
	}

	private func select() {
		controller.click(window.id)
	}
}
