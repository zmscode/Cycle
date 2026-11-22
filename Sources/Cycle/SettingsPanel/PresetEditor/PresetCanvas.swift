import RiftCore
import SwiftUI

/// The editor's canvas: the draft laid out on a little screen. Hover a slot to split or
/// remove it; drag a divider to move it.
struct PresetCanvas: View {
	@Binding var draft: PresetDraft

	@State private var hovered: Int?
	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private static let space = "presetCanvas"
	private static let inset: CGFloat = 6

	var body: some View {
		GeometryReader { proxy in
			let area = CGRect(
				x: Self.inset, y: PresetCanvasScreen.menuBarHeight + Self.inset - 2,
				width: proxy.size.width - Self.inset * 2,
				height: proxy.size.height - PresetCanvasScreen.menuBarHeight - Self.inset * 2 + 2)
			let geometry = draft.layout.geometry(
				in: area,
				metrics: RiftMetrics(
					dividerThickness: 5, minimumPaneSize: CGSize(width: 18, height: 14)))
			let numbers = Self.readingOrder(geometry.paneFrames)
			let main = TilingPreset(id: "", title: "", shape: .custom(draft.layout))
				.slotOrder(mainShare: 0.6).first
			ZStack(alignment: .topLeading) {
				PresetCanvasScreen()
				ForEach(geometry.paneFrames.sorted { $0.key < $1.key }, id: \.key) { slot, frame in
					PresetSlotTile(
						number: numbers[slot] ?? 0, isMain: slot == main && draft.slotCount > 1,
						isHovered: hovered == slot, canSplit: draft.canSplit,
						canRemove: draft.canRemove,
						onSplit: { axis in change { draft.split(slot, along: axis) } },
						onRemove: { change { draft.remove(slot) } }
					)
					.frame(width: frame.width, height: frame.height)
					.offset(x: frame.minX, y: frame.minY)
					.onHover { inside in
						if inside {
							hovered = slot
						} else if hovered == slot {
							hovered = nil
						}
					}
					.transition(.scale(scale: 0.6).combined(with: .opacity))
				}
				ForEach(geometry.dividers, id: \.splitID) { divider in
					PresetCanvasDivider(
						divider: divider, coordinateSpace: Self.space,
						onChange: { draft.setPosition($0, ofSplit: divider.splitID) },
						onReset: { change { draft.setPosition(0.5, ofSplit: divider.splitID) } })
				}
			}
			.coordinateSpace(name: Self.space)
		}
		.aspectRatio(16 / 10, contentMode: .fit)
	}

	/// Splits and removals spring into place; divider drags follow the pointer directly.
	private func change(_ edit: () -> Void) {
		withAnimation(reduceMotion ? nil : .spring(duration: 0.32, bounce: 0.2), edit)
	}

	/// Each slot's number, from 1, top to bottom and left to right (as it will be saved).
	private static func readingOrder(_ frames: [Int: CGRect]) -> [Int: Int] {
		let order = frames.sorted { a, b in
			abs(a.value.minY - b.value.minY) > 1
				? a.value.minY < b.value.minY : a.value.minX < b.value.minX
		}
		return Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1.key, $0 + 1) })
	}
}
