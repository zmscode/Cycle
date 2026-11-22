import SwiftUI

/// One window: a header row (controls, app icon, title) over its preview, which is
/// centred in the space below. When selected it sits on the sliding highlight plate with
/// a ring on the preview.
struct WindowCard: View {
	let window: SwitcherWindow
	let image: NSImage?
	let isSelected: Bool
	/// The preview's own size, from the window's shape and relative size.
	let thumbSize: CGSize
	/// The area the preview is centred in; shared height across the row so labels align.
	let slot: CGSize
	let cardSize: CGSize
	let selection: Namespace.ID
	let controller: SwitcherController

	@State private var isHovering = false
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private var plate: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Card.plateRadius) }

	var body: some View {
		VStack(spacing: Theme.Card.labelGap) {
			WindowCardHeader(
				window: window, isActive: isSelected || isHovering, isSelected: isSelected,
				onAction: perform
			)
			.frame(width: slot.width, height: Theme.Card.labelHeight)
			WindowThumbnail(window: window, image: image, size: thumbSize, isSelected: isSelected)
				.markBadge(controller.state.markNumber(window.id))
				.frame(width: slot.width, height: slot.height)
		}
		.padding([.horizontal, .top], Theme.Card.inset)
		.padding(.bottom, Theme.Card.inset)
		.frame(width: cardSize.width, height: cardSize.height, alignment: .top)
		.background {
			if isSelected {
				SelectionPlate(cornerRadius: Theme.Card.plateRadius)
					.matchedGeometryEffect(id: "selection", in: selection)
			}
		}
		.animation(reduceMotion ? nil : Theme.Motion.fade, value: isHovering)
		.contentShape(plate)
		.onHover(perform: hoverChanged)
		// A Button can't hold the control buttons inside it, so the card takes the tap
		// itself and declares the button trait for VoiceOver.
		.onTapGesture(perform: select)
		.accessibilityElement(children: .contain)
		.accessibilityLabel("\(window.appName), \(window.displayTitle)")
		.accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
		.accessibilityAction(named: "Switch to Window", select)
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
