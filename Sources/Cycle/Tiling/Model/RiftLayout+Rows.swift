import RiftCore

/// Rows: a run of nested splits along one axis reads as one row of windows (Thirds is a
/// split of a split). Removing a window from a row shares its space among the others in
/// proportion, so an even row stays even, instead of Rift's default of handing it all to
/// the neighbour.
extension RiftLayout {
	/// The layout without `pane`, its row closing up proportionally; nil when it was the
	/// only pane. Unchanged when `pane` isn't in it.
	func removingProportionally(_ pane: PaneID) -> RiftLayout? {
		switch self {
		case .pane(let id):
			return id == pane ? nil : self
		case .split(let split):
			var items = Self.row(of: self, along: split.axis, share: 1)
			guard let index = items.firstIndex(where: { $0.node.contains(pane) }) else {
				return self
			}
			if case .pane(pane) = items[index].node {
				items.remove(at: index)
			} else if let rest = items[index].node.removingProportionally(pane) {
				items[index].node = rest
			} else {
				items.remove(at: index)
			}
			return Self.build(items, along: split.axis)
		}
	}

	/// The row `node` heads along `axis`: each item with its share of the row.
	private static func row(of node: RiftLayout, along axis: RiftAxis, share: Double)
		-> [(node: RiftLayout, share: Double)]
	{
		guard case .split(let split) = node, split.axis == axis else { return [(node, share)] }
		return row(of: split.first, along: axis, share: share * split.position)
			+ row(of: split.second, along: axis, share: share * (1 - split.position))
	}

	/// A row of items, nested like the presets build them, sharing the space in proportion
	/// to their shares.
	private static func build(_ items: [(node: RiftLayout, share: Double)], along axis: RiftAxis)
		-> RiftLayout?
	{
		guard let first = items.first else { return nil }
		guard items.count > 1 else { return first.node }
		let total = items.reduce(0) { $0 + max($1.share, 0.0001) }
		let rest = Array(items.dropFirst())
		guard let second = build(rest, along: axis) else { return first.node }
		return .split(
			RiftSplit(
				axis: axis, position: max(first.share, 0.0001) / total, first: first.node,
				second: second))
	}
}
