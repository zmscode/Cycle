import SwiftUI

/// The dimmed screen with a hole over System Settings, and its caption.
struct SpotlightView: View {
	/// The Settings window in this view's coordinates (bottom-left origin).
	let hole: CGRect
	let size: CGSize
	let showsCaption: Bool

	private var holeTopLeft: CGRect {
		CGRect(x: hole.minX, y: size.height - hole.maxY, width: hole.width, height: hole.height)
	}

	var body: some View {
		let shape = RoundedRectangle(cornerRadius: 26, style: .continuous)
		ZStack(alignment: .topLeading) {
			Rectangle()
				.fill(.black.opacity(0.35))
				.reverseMask {
					shape.frame(width: holeTopLeft.width, height: holeTopLeft.height)
						.offset(x: holeTopLeft.minX, y: holeTopLeft.minY)
				}
			shape
				.strokeBorder(Theme.Colors.selection, lineWidth: 4)
				.shadow(color: Theme.Colors.selection.opacity(0.8), radius: 16)
				.frame(width: holeTopLeft.width, height: holeTopLeft.height)
				.offset(x: holeTopLeft.minX, y: holeTopLeft.minY)
			if showsCaption {
				Label("Drop Cycle into the list to allow it", systemImage: "arrow.down.app")
					.font(.system(size: 14, weight: .semibold))
					.padding(.horizontal, 16)
					.padding(.vertical, 10)
					.glassEffect(.regular, in: .capsule)
					.fixedSize()
					.frame(width: holeTopLeft.width)
					.offset(x: holeTopLeft.minX, y: max(holeTopLeft.minY - 54, 8))
			}
		}
		.frame(width: size.width, height: size.height, alignment: .topLeading)
		.ignoresSafeArea()
	}
}

extension View {
	fileprivate func reverseMask<Mask: View>(@ViewBuilder _ mask: () -> Mask) -> some View {
		self.mask {
			Rectangle()
				.overlay(alignment: .topLeading) { mask().blendMode(.destinationOut) }
				.compositingGroup()
		}
	}
}
