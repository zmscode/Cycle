import SwiftUI

/// A preset's slots as small rounded blocks, as on the tiling board's chips and the
/// settings panel's preset toggles. One slot can be lit (the one under the pointer).
struct PresetThumbnail: View {
	let preset: TilingPreset
	let mainShare: Double
	var highlightedSlot: Int?
	var isEnabled = true

	var body: some View {
		Canvas { context, size in
			let frames = TilingBoard.chipFrames(
				preset, in: CGRect(origin: .zero, size: size), mainShare: mainShare)
			for (slot, frame) in frames {
				let path = Path(roundedRect: frame, cornerRadius: 3)
				let lit = slot == highlightedSlot
				context.fill(
					path,
					with: .color(
						lit ? Theme.Colors.selection : .white.opacity(isEnabled ? 0.28 : 0.1)))
				if lit {
					context.stroke(path, with: .color(.white.opacity(0.6)), lineWidth: 1)
				}
			}
		}
		.accessibilityHidden(true)
	}
}
