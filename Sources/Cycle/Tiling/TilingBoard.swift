import CoreGraphics
import RiftCore

/// One screen's tiling layout and its scaled-down picture under the switcher. The layout is
/// a Rift tree of window ids (with placeholder ids for empty preset slots); Rift lays it out
/// in the screen's visible area and classifies the pointer into drop zones, the same way
/// Rift panes are dragged onto one another.
///
/// Real frames are in window-server coordinates (top-left origin, y down), which is what
/// both Rift and the Accessibility position attribute use.
struct TilingBoard {
	var layout: RiftLayout<CGWindowID>?
	/// The screen's visible area (no menu bar or Dock).
	let visible: CGRect
	/// `visible` inside the margin: where tiles go.
	let tileArea: CGRect
	let placement: BoardPlacement
	let metrics: RiftMetrics
	let mainShare: Double

	init(
		layout: RiftLayout<CGWindowID>?, visible: CGRect, placement: BoardPlacement,
		displayScale: CGFloat
	) {
		self.layout = layout
		self.visible = visible
		self.placement = placement
		let margin = max(Settings.tilingMargin, 0)
		tileArea = visible.insetBy(dx: margin, dy: margin)
		metrics = RiftMetrics(
			dividerThickness: max(Settings.tilingGap, 0),
			minimumPaneSize: Theme.Tiling.minimumTileSize, displayScale: displayScale)
		mainShare = Settings.tilingMainShare
	}

	/// The small copy of the screen, in the overlay's coordinates; it pictures `visible`.
	var rect: CGRect { placement.screen }

	private var scale: CGFloat { visible.width > 0 ? rect.width / visible.width : 1 }

	/// Every slot's frame on screen, empty preset slots included.
	var allFrames: [CGWindowID: CGRect] {
		layout?.geometry(in: tileArea, metrics: metrics).paneFrames ?? [:]
	}

	/// Every tiled window's frame on screen.
	var frames: [CGWindowID: CGRect] {
		allFrames.filter { !TilingSlot.isPlaceholder($0.key) }
	}

	/// A real frame on the board.
	func toBoard(_ frame: CGRect) -> CGRect {
		CGRect(
			x: rect.minX + (frame.minX - visible.minX) * scale,
			y: rect.minY + (frame.minY - visible.minY) * scale,
			width: frame.width * scale, height: frame.height * scale)
	}

	private func toScreen(_ point: CGPoint) -> CGPoint {
		CGPoint(
			x: visible.minX + (point.x - rect.minX) / scale,
			y: visible.minY + (point.y - rect.minY) / scale)
	}

	/// A preset's slots drawn in `rect` (a chip, or the settings panel's icons).
	static func chipFrames(_ preset: TilingPreset, in rect: CGRect, mainShare: Double) -> [Int:
		CGRect]
	{
		preset.layout(mainShare: mainShare)
			.geometry(
				in: rect,
				metrics: RiftMetrics(
					dividerThickness: Theme.Tiling.chipGap, minimumPaneSize: .zero)
			)
			.paneFrames
	}

	// MARK: Targets

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

	// MARK: Dropping

	/// The layout after dropping `ids` (the window picked up first) on `target`; nil when
	/// nothing changes. Several windows go side by side, or stacked along a screen edge or
	/// a split's edge, sharing the space evenly.
	func dropping(_ ids: [CGWindowID], on target: TileTarget) -> RiftLayout<CGWindowID>? {
		guard let first = ids.first else { return nil }
		if case .preset(let preset, let slot) = target {
			return applying(preset, putting: ids, from: slot)
		}
		if ids.count == 1 { return dropping(first, on: target) }

		let dragged = Set(ids)
		var rest = layout
		for id in ids where rest?.contains(id) == true {
			rest = rest?.removing(.pane(id))?.remaining
		}
		switch target {
		case .fill, .preset:
			return Self.row(ids, along: .horizontal)
		case .edge(let edge):
			let group = Self.row(ids, along: edge.axis.cross)
			return rest?.wrapping(group, edge: edge) ?? Self.row(ids, along: .horizontal)
		case .pane(let pane, let zone):
			guard !dragged.contains(pane), let rest else { return nil }
			guard let edge = zone.edge else {
				return rest.replacing(.pane(pane)) { _ in Self.row(ids, along: .horizontal) }
			}
			return rest.inserting(
				Self.row(ids, along: edge.axis.cross), at: .pane(pane), edge: edge)
		}
	}

	private func dropping(_ id: CGWindowID, on target: TileTarget) -> RiftLayout<CGWindowID>? {
		guard let layout, layout.paneIDs != [id] else { return .pane(id) }
		switch target {
		case .fill, .preset:
			return .pane(id)
		case .edge(let edge):
			guard let rest = layout.contains(id) ? layout.removing(.pane(id))?.remaining : layout
			else { return .pane(id) }
			return rest.wrapping(.pane(id), edge: edge)
		case .pane(let pane, let zone):
			guard pane != id else { return nil }
			if layout.contains(id) {
				// Rift's own pane move: beside the target, or swapped with it.
				return layout.moving(id, to: pane, zone: zone)
			}
			guard let edge = zone.edge else {
				// Dropped in the middle: it takes that window's (or empty slot's) place.
				return layout.replacing(.pane(pane)) { _ in .pane(id) }
			}
			return layout.splitting(pane, with: id, edge: edge)
		}
	}

	/// `preset` with the first of `ids` in `slot` and the rest of them in the following
	/// slots (main slot first), then the windows already tiled, then placeholders in any
	/// left over. Windows that don't fit stay where they are, untiled.
	private func applying(_ preset: TilingPreset, putting ids: [CGWindowID], from slot: Int)
		-> RiftLayout<CGWindowID>
	{
		let dragged = Set(ids)
		let tiled = (layout?.paneIDs ?? []).filter {
			!dragged.contains($0) && !TilingSlot.isPlaceholder($0)
		}
		var waiting = Array(ids.dropFirst()) + tiled
		var assigned: [Int: CGWindowID] = [:]
		if let first = ids.first { assigned[slot] = first }
		for other in preset.slotOrder(mainShare: mainShare) where other != slot {
			guard !waiting.isEmpty else { break }
			assigned[other] = waiting.removeFirst()
		}
		return preset.layout(mainShare: mainShare).mapPanes {
			assigned[$0] ?? TilingSlot.placeholder($0)
		}
	}

	/// `ids` side by side along `axis`, sharing it evenly.
	private static func row(_ ids: [CGWindowID], along axis: RiftAxis) -> RiftLayout<CGWindowID> {
		guard let first = ids.first else { preconditionFailure("an empty row") }
		guard ids.count > 1 else { return .pane(first) }
		return .split(
			RiftSplit(
				axis: axis, position: 1 / Double(ids.count), first: .pane(first),
				second: row(Array(ids.dropFirst()), along: axis)))
	}

	/// The key whose frame is nearest `point` (zero inside it).
	private static func nearest<Key>(_ point: CGPoint, in frames: [Key: CGRect]) -> Key? {
		frames.min { distance(point, $0.value) < distance(point, $1.value) }?.key
	}

	private static func distance(_ point: CGPoint, _ rect: CGRect) -> CGFloat {
		let dx = max(rect.minX - point.x, 0, point.x - rect.maxX)
		let dy = max(rect.minY - point.y, 0, point.y - rect.maxY)
		return hypot(dx, dy)
	}
}
