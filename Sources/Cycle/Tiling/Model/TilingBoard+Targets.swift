import CoreGraphics
import RiftCore

/// Where a drop would land: the preset chips, the screen's edges, a window's edges or
/// middle, or the whole screen.
extension TilingBoard {
	/// The target under `point` (overlay coordinates) for dragging `ids`, or nil when the
	/// pointer is off the board or over one of the dragged windows' own tiles.
	func target(at point: CGPoint, dragging ids: [CGWindowID]) -> TileTarget? {
		for chip in placement.chips where chip.rect.insetBy(dx: -4, dy: -4).contains(point) {
			let slots = Self.chipFrames(chip.preset, in: chip.rect, mainShare: mainShare)
			guard let slot = Self.nearest(point, in: slots) else { continue }
			return .preset(chip.preset, slot: slot)
		}

		let slack = Theme.Tiling.boardSlack
		guard rect.insetBy(dx: -slack, dy: -slack).contains(point) else { return nil }
		let clamped = CGPoint(
			x: min(max(point.x, rect.minX), rect.maxX), y: min(max(point.y, rect.minY), rect.maxY))
		let real = toScreen(clamped)
		let dragged = Set(ids)
		// Nothing else tiled here (empty slots aside): the dragged windows take the screen.
		guard let layout, layout.paneIDs.contains(where: { !dragged.contains($0) }) else {
			return .fill
		}

		// Near the screen's edge: a full-height or full-width slot beside everything.
		if layout.paneCount > 1 {
			let band = min(tileArea.width, tileArea.height) * Theme.Tiling.outerBand
			if real.x < tileArea.minX + band { return .edge(.left) }
			if real.x > tileArea.maxX - band { return .edge(.right) }
			if real.y < tileArea.minY + band { return .edge(.top) }
			if real.y > tileArea.maxY - band { return .edge(.bottom) }
		}

		let frames = allFrames
		guard let pane = Self.nearest(real, in: frames), let frame = frames[pane] else {
			return .fill
		}
		guard !dragged.contains(pane) else { return nil }
		// An empty slot is simply filled.
		if TilingSlot.isPlaceholder(pane) { return .pane(pane, .center) }
		return .pane(pane, RiftDropZone.classify(real, in: frame))
	}

	/// The highlight for `target`, on the board: the area the window will take.
	func indicator(for target: TileTarget) -> CGRect {
		let area: CGRect
		switch target {
		case .fill:
			area = tileArea
		case .edge(let edge):
			area = RiftDropZone(edge: edge).indicatorRect(in: tileArea, inset: 0)
		case .pane(let pane, let zone):
			area = zone.indicatorRect(in: allFrames[pane] ?? tileArea, inset: 0)
		case .preset(let preset, let slot):
			area =
				preset.layout(mainShare: mainShare).geometry(in: tileArea, metrics: metrics)
				.paneFrames[slot] ?? tileArea
		}
		return toBoard(area)
	}

	/// The key whose frame is nearest `point` (zero inside it).
	fileprivate static func nearest<Key>(_ point: CGPoint, in frames: [Key: CGRect]) -> Key? {
		frames.min { distance(point, $0.value) < distance(point, $1.value) }?.key
	}

	fileprivate static func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
		let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
		let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
		return hypot(dx, dy)
	}
}
