import AppKit
import RiftCore
import SwiftUI

/// A divider in the editor: a pill grip on the split line. Drag it to move the split (it
/// snaps to the middle with a tick), double-click it to even the split up.
struct PresetCanvasDivider: View {
	let divider: RiftDividerPlacement
	let coordinateSpace: String
	let onChange: (Double) -> Void
	let onReset: () -> Void

	@State private var isHovered = false
	@State private var isDragging = false
	@State private var isSnapped = false

	private var horizontal: Bool { divider.axis == .horizontal }

	var body: some View {
		let hit = divider.hitRect(thickness: 12)
		let active = isHovered || isDragging
		Capsule()
			.fill(active ? Theme.Colors.mark : .white.opacity(0.9))
			.frame(
				width: horizontal ? (active ? 4 : 3) : (active ? 30 : 18),
				height: horizontal ? (active ? 30 : 18) : (active ? 4 : 3)
			)
			.shadow(color: .black.opacity(0.45), radius: 2)
			.frame(width: hit.width, height: hit.height)
			.contentShape(Rectangle())
			.position(x: hit.midX, y: hit.midY)
			.onHover { hovering in
				isHovered = hovering
				if hovering {
					(horizontal ? NSCursor.resizeLeftRight : NSCursor.resizeUpDown).push()
				} else {
					NSCursor.pop()
				}
			}
			.gesture(drag)
			.simultaneousGesture(TapGesture(count: 2).onEnded(onReset))
			.animation(.snappy(duration: 0.15), value: active)
			.accessibilityElement()
			.accessibilityLabel(horizontal ? "Vertical divider" : "Horizontal divider")
			.accessibilityValue(divider.position.formatted(.percent.precision(.fractionLength(0))))
			.accessibilityAdjustableAction { direction in
				let step = direction == .increment ? 0.05 : -0.05
				onChange(divider.position + step)
			}
	}

	private var drag: some Gesture {
		DragGesture(minimumDistance: 1, coordinateSpace: .named(coordinateSpace))
			.onChanged { value in
				isDragging = true
				let container = divider.container
				let length = horizontal ? container.width : container.height
				guard length > 0 else { return }
				let offset =
					horizontal ? value.location.x - container.minX : value.location.y - container.minY
				var position = offset / length
				let snapping = abs(position - 0.5) < 0.03
				if snapping {
					position = 0.5
					if !isSnapped {
						NSHapticFeedbackManager.defaultPerformer.perform(
							.alignment, performanceTime: .now)
					}
				}
				isSnapped = snapping
				onChange(position)
			}
			.onEnded { _ in
				isDragging = false
				isSnapped = false
			}
	}
}
