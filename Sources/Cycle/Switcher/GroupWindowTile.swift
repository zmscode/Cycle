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
			WindowThumbnail(window: window, image: image, size: thumb, isSelected: isSelected)
				// A narrow (portrait or small) preview centres the controls along its top.
				.overlay(alignment: thumb.width < Theme.Controls.capsuleWidth + 16 ? .top : .topLeading) {
					if !window.isWindowless && (isSelected || isHovering) {
						WindowControls(onAction: perform)
							.padding(6)
							.transition(.opacity)
					}
				}
				.frame(width: slot.width, height: slot.height)
			Text(window.isWindowless ? "Open App" : window.displayTitle)
				.font(.caption)
				.bold(isSelected)
				.foregroundStyle(isSelected ? .primary : .secondary)
				.lineLimit(1)
				.truncationMode(.middle)
				.frame(width: slot.width, height: Theme.Group.labelHeight)
		}
		.padding([.horizontal, .top], Theme.Card.inset)
		.padding(.bottom, Theme.Card.inset / 2)
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
	}

	private func perform(_ action: CardAction) {
		controller.perform(action, on: window.id)
	}

	private func hoverChanged(_ inside: Bool) {
		isHovering = inside
		if inside { controller.hover(window.id) }
	}

	private func select() {
		controller.click(window.id)
	}
}
