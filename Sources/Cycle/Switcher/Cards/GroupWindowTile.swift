import SwiftUI

/// One window inside an app group: its thumbnail and title, with the sliding highlight
/// and window controls when selected or hovered.
struct GroupWindowTile: View {
	let window: SwitcherWindow
	let image: NSImage?
	let isSelected: Bool
	/// The preview's own size, from the window's shape and relative size.
	let thumb: CGSize
	/// The area the preview is centred in; shared height across the row so titles align.
	let slot: CGSize
	let selection: Namespace.ID
	let controller: SwitcherController

	@State private var isHovering = false
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private var plate: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Card.plateRadius) }

	var body: some View {
		VStack(spacing: Theme.Card.labelGap) {
			// The app's icon and name are in the group header; each tile's row has the
			// window's controls and title, aligned across every tile.
			HStack(spacing: 8) {
				if !window.isWindowless {
					WindowControls(isActive: isSelected || isHovering, onAction: perform)
				}
				Text(window.isWindowless ? "Open App" : window.displayTitle)
					.font(.caption)
					.bold(isSelected)
					.foregroundStyle(isSelected ? .primary : .secondary)
					.lineLimit(1)
					.truncationMode(.middle)
				Spacer(minLength: 0)
			}
			.frame(width: slot.width, height: Theme.Group.labelHeight)
			WindowThumbnail(window: window, image: image, size: thumb, isSelected: isSelected)
				.markBadge(controller.state.markNumber(window.id))
				.frame(width: slot.width, height: slot.height)
		}
		.padding([.horizontal, .top], Theme.Card.inset)
		.padding(.bottom, Theme.Card.inset)
		.background {
			if isSelected {
				SelectionPlate(cornerRadius: Theme.Card.plateRadius)
					.matchedGeometryEffect(id: "selection", in: selection)
			}
		}
		.animation(reduceMotion ? nil : Theme.Motion.fade, value: isHovering)
		.contentShape(plate)
		.onHover(perform: hoverChanged)
		.onTapGesture(perform: select)
		.accessibilityElement(children: .contain)
		.accessibilityLabel("\(window.appName), \(window.displayTitle)")
		.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
		.tilingAccessibilityActions(window.id, controller: controller)
	}

	private func perform(_ action: CardAction) {
		controller.perform(action, on: window.id)
	}

	private func hoverChanged(_ inside: Bool) {
		isHovering = inside
		if inside { controller.hover(window.id) } else { controller.hoverEnded(window.id) }
	}

	private func select() {
		controller.click(window.id)
	}
}
