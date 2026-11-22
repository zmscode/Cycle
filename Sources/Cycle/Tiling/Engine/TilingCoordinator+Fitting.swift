import AppKit
import RiftCore

/// Windows that won't fit their slot: some apps have a minimum size, or round a resize up.
/// After placing, a window that came out bigger than its slot has its app's minimum size
/// remembered. A small overrun (up to `Theme.Tiling.fitTolerance` of the slot) moves the
/// neighbouring divider to make room and places the windows once more; a larger one is
/// left where the app put it and shown with a warning outline on the board. Layouts made
/// later take the remembered sizes into account straight away.
extension TilingCoordinator {
	/// `board` with its dividers moved to make room for windows whose apps are known to
	/// need more space than their slot gives; nil when nothing needs to change.
	func fitted(_ board: TilingBoard, windows: [SwitcherWindow]) -> RiftLayout<CGWindowID>? {
		guard !minimumSizes.isEmpty else { return nil }
		let byID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
		var needs: [CGWindowID: CGSize] = [:]
		for id in board.frames.keys {
			guard let bundleID = byID[id]?.bundleID, let minimum = minimumSizes[bundleID]
			else { continue }
			needs[id] = minimum
		}
		return making(room: needs, on: board)
	}

	/// Compares where windows landed with where they were sent. Windows that overran their
	/// slot a little get room made for them and are placed again (once: `retry` is false
	/// the second time); the rest are marked as not fitting.
	func checkFit(
		_ placed: [CGWindowID: CGRect], on board: TilingBoard, display: String,
		windows: [SwitcherWindow], retry: Bool
	) {
		let targets = board.frames
		let byID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
		var needs: [CGWindowID: CGSize] = [:]
		var tooBig: Set<CGWindowID> = []
		for (id, actual) in placed {
			guard let target = targets[id] else { continue }
			let over = CGSize(
				width: actual.width - target.width, height: actual.height - target.height)
			guard over.width > Self.slack || over.height > Self.slack else {
				unfit.remove(id)
				continue
			}
			let need = CGSize(
				width: over.width > Self.slack ? actual.width : 0,
				height: over.height > Self.slack ? actual.height : 0)
			if let bundleID = byID[id]?.bundleID { rememberMinimum(need, for: bundleID) }
			let tolerance = Theme.Tiling.fitTolerance
			if retry, over.width <= target.width * tolerance,
				over.height <= target.height * tolerance
			{
				needs[id] = need
			} else {
				tooBig.insert(id)
			}
		}
		unfit.formUnion(tooBig)
		if let layout = making(room: needs, on: board), let screen = NSScreen.screen(uuid: display) {
			store.save(layout, for: display, windows: windows)
			let refitted = TilingBoard.offscreen(on: screen, layout: store.layout(for: display))
			onLayoutChanged?(display, refitted.layout)
			place(refitted, windows: windows, animated: false, display: display, retry: false)
		} else {
			unfit.formUnion(needs.keys)
		}
		onUnfitChanged?(unfit)
	}

	/// The layout with each window in `needs` given at least that size (a zero side is no
	/// need), by moving the nearest divider across each side that's too small; nil when
	/// nothing changes. A divider never goes past 10% from either end.
	private func making(room needs: [CGWindowID: CGSize], on board: TilingBoard)
		-> RiftLayout<CGWindowID>?
	{
		guard var layout = board.layout, !needs.isEmpty else { return nil }
		let original = layout
		for (id, need) in needs.sorted(by: { $0.key < $1.key }) {
			for axis in [RiftAxis.horizontal, .vertical] {
				let geometry = layout.geometry(in: board.tileArea, metrics: board.metrics)
				guard let frame = geometry.paneFrames[id] else { continue }
				let have = axis == .horizontal ? frame.width : frame.height
				let wanted = axis == .horizontal ? need.width : need.height
				let short = wanted - have
				guard short > Self.slack, have > 0,
					short <= have * Theme.Tiling.fitTolerance * 1.5,
					let step = layout.path(to: id)?.last(where: { $0.split.axis == axis }),
					let divider = geometry.dividers.first(where: { $0.splitID == step.split.id }),
					divider.available > 0
				else { continue }
				let side =
					step.inFirst ? divider.leadingLength : divider.available - divider.leadingLength
				// The window may share its side with others along the same axis: the side
				// grows by enough for the window's own share to cover the shortfall.
				let share = min(max(have / max(side, 1), 0.01), 1)
				let grown = (side + short / share) / divider.available
				let position = step.inFirst ? grown : 1 - grown
				layout =
					layout.settingPosition(min(max(position, 0.1), 0.9), ofSplit: step.split.id)
					?? layout
			}
		}
		return layout == original ? nil : layout
	}

	private func rememberMinimum(_ size: CGSize, for bundleID: String) {
		let known = minimumSizes[bundleID] ?? .zero
		minimumSizes[bundleID] = CGSize(
			width: max(known.width, size.width), height: max(known.height, size.height))
	}

	/// Overruns up to this many points are an app rounding its size, not a minimum.
	private static let slack: CGFloat = 6
}
