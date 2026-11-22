import CoreGraphics
import RiftCore

/// The layout a drop produces.
extension TilingBoard {
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

	/// `preset` with `ids` in it, then the windows already tiled (main slot first), then
	/// placeholders in any slots left over. One window goes in `slot`, the one under the
	/// pointer. Several (marked) windows go in reading order, left to right and top to
	/// bottom, so window 1 takes the first slot, window 2 the next, and so on. Windows that
	/// don't fit stay where they are, untiled.
	private func applying(_ preset: TilingPreset, putting ids: [CGWindowID], from slot: Int)
		-> RiftLayout<CGWindowID>
	{
		let dragged = Set(ids)
		let tiled = (layout?.paneIDs ?? []).filter {
			!dragged.contains($0) && !TilingSlot.isPlaceholder($0)
		}
		var assigned: [Int: CGWindowID] = [:]
		if ids.count > 1 {
			for (slot, id) in zip(preset.readingOrder(mainShare: mainShare), ids) {
				assigned[slot] = id
			}
		} else if let first = ids.first {
			assigned[slot] = first
		}
		var waiting = tiled
		for other in preset.slotOrder(mainShare: mainShare) where assigned[other] == nil {
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

	/// The current layout with `ids` in its empty slots (main slot first), when it's already
	/// laid out as `preset` and has room for all of them that aren't tiled yet; nil
	/// otherwise. Picking the preset that's already on screen adds to it rather than
	/// reshuffling it.
	func filling(_ preset: TilingPreset, with ids: [CGWindowID]) -> RiftLayout<CGWindowID>? {
		guard let layout, Self.sameShape(layout, preset.layout(mainShare: mainShare)) else {
			return nil
		}
		let incoming = ids.filter { !layout.contains($0) }
		let order =
			incomingCount(ids, in: layout) > 1
			? preset.readingOrder(mainShare: mainShare) : preset.slotOrder(mainShare: mainShare)
		let empty = order.filter { layout.contains(TilingSlot.placeholder($0)) }
		guard !incoming.isEmpty, empty.count >= incoming.count else { return nil }
		var result = layout
		for (slot, id) in zip(empty, incoming) {
			result =
				result.replacing(.pane(TilingSlot.placeholder(slot))) { _ in .pane(id) } ?? result
		}
		return result
	}

	private func incomingCount(_ ids: [CGWindowID], in layout: RiftLayout<CGWindowID>) -> Int {
		ids.filter { !layout.contains($0) }.count
	}

	/// Whether two layouts split the same way, whatever their panes.
	private static func sameShape<A, B>(_ a: RiftLayout<A>, _ b: RiftLayout<B>) -> Bool {
		switch (a, b) {
		case (.pane, .pane):
			return true
		case (.split(let x), .split(let y)):
			return x.axis == y.axis && abs(x.position - y.position) < 0.01
				&& sameShape(x.first, y.first) && sameShape(x.second, y.second)
		default:
			return false
		}
	}
}
