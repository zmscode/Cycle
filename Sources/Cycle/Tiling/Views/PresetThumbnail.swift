import SwiftUI

/// A preset's slots as small rounded blocks, as on the tiling board's chips and the
/// settings panel's preset toggles. Slots can be lit: the one under the pointer, or the
/// ones a group of marked windows will fill.
struct PresetThumbnail: View {
	let preset: TilingPreset
	let mainShare: Double
	var highlightedSlots: Set<Int> = []
	/// Numbers drawn in slots: which marked window goes where.
	var slotNumbers: [Int: Int] = [:]
	var isEnabled = true

	@Environment(\.colorSchemeContrast) private var contrast

	var body: some View {
		Canvas { context, size in
			let frames = TilingBoard.chipFrames(
				preset, in: CGRect(origin: .zero, size: size), mainShare: mainShare)
			for (slot, frame) in frames {
				let path = Path(roundedRect: frame, cornerRadius: 3)
				let lit = highlightedSlots.contains(slot)
				let increased = contrast == .increased
				context.fill(
					path,
					with: .color(
						lit
							? Theme.Colors.mark
							: .white.opacity(isEnabled ? (increased ? 0.5 : 0.28) : (increased ? 0.22 : 0.1))))
				if increased, !lit {
					context.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 0.5)
				}
				if lit {
					context.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 1)
				}
				if let number = slotNumbers[slot] {
					context.draw(
						Text(number, format: .number)
							.font(.system(size: 10, weight: .bold).monospacedDigit())
							.foregroundStyle(.white),
						at: CGPoint(x: frame.midX, y: frame.midY))
				}
			}
		}
		.accessibilityHidden(true)
	}
}
