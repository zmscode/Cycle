import RiftCore
import SwiftUI

/// One slot in the editor: frosted, numbered in the order it will be saved, marked when
/// it's the main slot (the one windows fill first). Hovering shows its actions.
struct PresetSlotTile: View {
	let number: Int
	let isMain: Bool
	let isHovered: Bool
	let canSplit: Bool
	let canRemove: Bool
	let onSplit: (RiftAxis) -> Void
	let onRemove: () -> Void

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 7, style: .continuous) }

	var body: some View {
		GeometryReader { proxy in
			let roomy = proxy.size.width >= 70 && proxy.size.height >= 50
			ZStack {
				shape.fill(
					LinearGradient(
						colors: [
							.white.opacity(isHovered ? 0.30 : 0.20),
							.white.opacity(isHovered ? 0.16 : 0.09),
						],
						startPoint: .top, endPoint: .bottom))
				shape.strokeBorder(
					isHovered ? Theme.Colors.mark : .white.opacity(0.28),
					lineWidth: isHovered ? 1.5 : 1)
				if !(isHovered && !roomy) {
					label
						.offset(y: isHovered ? -10 : 0)
				}
				if isHovered {
					actions
						.frame(maxHeight: .infinity, alignment: roomy ? .bottom : .center)
						.padding(.bottom, roomy ? 6 : 0)
						.transition(.opacity.combined(with: .scale(scale: 0.8)))
				}
			}
			.frame(width: proxy.size.width, height: proxy.size.height)
		}
		.contentShape(shape)
		.animation(.snappy(duration: 0.18), value: isHovered)
		.accessibilityElement(children: .contain)
		.accessibilityLabel(isMain ? "Slot \(number), main" : "Slot \(number)")
	}

	private var label: some View {
		VStack(spacing: 1) {
			Text(number, format: .number)
				.font(.system(size: 15, weight: .semibold, design: .rounded).monospacedDigit())
				.foregroundStyle(.white.opacity(0.9))
			if isMain {
				Text("MAIN")
					.font(.system(size: 7, weight: .heavy))
					.tracking(0.8)
					.foregroundStyle(Theme.Colors.mark)
			}
		}
		.shadow(color: .black.opacity(0.3), radius: 2, y: 1)
	}

	private var actions: some View {
		HStack(spacing: 3) {
			if canSplit {
				PresetSlotAction(
					title: "Split side by side", systemImage: "rectangle.split.2x1"
				) { onSplit(.horizontal) }
				PresetSlotAction(
					title: "Split top and bottom", systemImage: "rectangle.split.1x2"
				) { onSplit(.vertical) }
			}
			if canRemove {
				PresetSlotAction(title: "Remove slot", systemImage: "xmark", action: onRemove)
			}
		}
		.padding(3)
		.background(.black.opacity(0.35), in: .capsule)
	}
}
