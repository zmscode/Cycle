import CoreGraphics

/// Sizes for the current layout, computed up front so the panel can be sized exactly.
/// Every window's preview takes its window's aspect ratio and is scaled by its size
/// relative to the largest window, so a portrait window gets a portrait preview and a
/// small window looks smaller. Cards in a row share one preview-area height, so their
/// labels line up.
struct SwitcherLayout {
	let style: SwitcherStyle
	/// Grid: card indexes per row.
	let rows: [[Int]]
	/// Grouped: groups per row.
	let groupRows: [[WindowGroup]]
	/// Each window's preview size, by index into the session's window list.
	let thumbs: [CGSize]
	/// Each window's card content width (at least the preview, never too narrow for a
	/// label), by index.
	let slots: [CGFloat]
	/// The preview area's height: the tallest a preview can be.
	let boxHeight: CGFloat
	/// Each window's preview-area height, by index: the tallest preview in its row, so a
	/// row of small windows takes less room. Cards in one row share it, keeping labels
	/// and controls aligned.
	var slotHeights: [CGFloat] = []
	/// List: the detail pane's preview box.
	let previewBox: CGSize
	/// The content area under the top row.
	let bodySize: CGSize
	let scrolls: Bool
	/// The top row's height: the query row while filtering, otherwise nothing.
	var headerHeight: CGFloat = Theme.Panel.searchHeight
	var showsSearchBar: Bool { headerHeight == Theme.Panel.searchHeight }

	static let empty = SwitcherLayout(
		style: .grid, rows: [], groupRows: [], thumbs: [], slots: [], boxHeight: 0,
		previewBox: .zero, bodySize: .zero, scrolls: false)

	static func metrics(
		for windows: [SwitcherWindow], style: SwitcherStyle, maxSize: CGSize, showsSearchBar: Bool
	) -> SwitcherLayout {
		let header = showsSearchBar ? Theme.Panel.searchHeight : Theme.Panel.compactHeaderHeight
		let maxBody = CGSize(width: maxSize.width, height: maxSize.height - header)
		var layout: SwitcherLayout
		switch style {
		case .grid: layout = grid(windows, maxBody: maxBody)
		case .list: layout = list(count: windows.count, maxBody: maxBody)
		case .grouped: layout = grouped(windows, maxBody: maxBody)
		}
		layout.headerHeight = header
		return layout
	}

	/// The whole panel: the body plus the top row.
	var fullSize: CGSize {
		CGSize(width: bodySize.width, height: bodySize.height + headerHeight)
	}

	func thumb(at index: Int) -> CGSize {
		thumbs.indices.contains(index)
			? thumbs[index] : CGSize(width: boxHeight * 1.3, height: boxHeight)
	}

	func slotHeight(at index: Int) -> CGFloat {
		slotHeights.indices.contains(index) ? slotHeights[index] : boxHeight
	}

	func slotWidth(at index: Int) -> CGFloat {
		slots.indices.contains(index) ? slots[index] : boxHeight * 1.3
	}

	/// A grid card: the slot plus the selection plate's inset.
	func cardWidth(at index: Int) -> CGFloat {
		slotWidth(at: index) + Theme.Card.inset * 2
	}

	func cardHeight(at index: Int) -> CGFloat {
		Self.cardHeight(box: slotHeight(at: index))
	}

	static func cardHeight(box: CGFloat) -> CGFloat {
		Theme.Card.inset + box + Theme.Card.labelGap + Theme.Card.labelHeight + Theme.Card.inset
	}

	/// The tallest preview among `indices`: the shared preview-area height for a row.
	static func rowBox(_ indices: [Int], thumbs: [CGSize]) -> CGFloat {
		indices.map { thumbs.indices.contains($0) ? thumbs[$0].height : 0 }.max() ?? 0
	}

	/// Each index's row box height.
	private static func slotHeights(rows: [[Int]], thumbs: [CGSize]) -> [CGFloat] {
		var heights = [CGFloat](repeating: 0, count: thumbs.count)
		for row in rows {
			let box = rowBox(row, thumbs: thumbs)
			for index in row where heights.indices.contains(index) { heights[index] = box }
		}
		return heights
	}

	// MARK: Preview sizes

	/// A window's aspect ratio, kept within limits so very thin windows stay legible.
	static func aspect(of window: SwitcherWindow) -> CGFloat {
		guard !window.isWindowless, window.bounds.width > 0, window.bounds.height > 0 else {
			return 1.3
		}
		return min(
			max(window.bounds.width / window.bounds.height, Theme.Card.minAspect),
			Theme.Card.maxAspect)
	}

	/// The largest size with `aspect` that fits in `box`.
	static func fit(aspect: CGFloat, in box: CGSize) -> CGSize {
		let width = min(box.width, box.height * aspect)
		return CGSize(width: width.rounded(), height: (width / aspect).rounded())
	}

	/// Preview sizes for every window with previews up to `boxHeight` tall. Each window's
	/// shape fits a box `boxHeight` tall and up to `Theme.Card.boxAspect` times as wide,
	/// then shrinks by its area relative to the largest window, gently (a power curve)
	/// and never below `Theme.Card.minScale`.
	static func previewSizes(_ windows: [SwitcherWindow], boxHeight: CGFloat) -> (
		thumbs: [CGSize], slots: [CGFloat]
	) {
		let areas = windows.map { $0.isWindowless ? 0 : $0.bounds.width * $0.bounds.height }
		let largest = max(areas.max() ?? 0, 1)
		let box = CGSize(width: boxHeight * Theme.Card.boxAspect, height: boxHeight)
		var thumbs: [CGSize] = []
		var slots: [CGFloat] = []
		for (window, area) in zip(windows, areas) {
			let fitted = fit(aspect: aspect(of: window), in: box)
			let scale =
				window.isWindowless
				? Theme.Card.windowlessScale
				: min(max(pow(area / largest, Theme.Card.scaleCurve), Theme.Card.minScale), 1)
			let size = CGSize(
				width: (fitted.width * scale).rounded(), height: (fitted.height * scale).rounded())
			thumbs.append(size)
			slots.append(max(size.width, Theme.Card.minSlotWidth))
		}
		return (thumbs, slots)
	}

	// MARK: Grid

	private static func grid(_ windows: [SwitcherWindow], maxBody: CGSize) -> SwitcherLayout {
		// Shrink previews until everything fits, but never below a readable size.
		for height in stride(
			from: Theme.Card.maxThumbHeight, through: Theme.Card.minThumbHeight, by: -6)
		{
			let layout = buildGrid(windows, boxHeight: height, maxBody: maxBody, scrolls: false)
			if layout.bodySize.height <= maxBody.height { return layout }
		}
		return buildGrid(
			windows, boxHeight: Theme.Card.minThumbHeight, maxBody: maxBody, scrolls: true)
	}

	private static func buildGrid(
		_ windows: [SwitcherWindow], boxHeight: CGFloat, maxBody: CGSize, scrolls: Bool
	) -> SwitcherLayout {
		let padding = Theme.Panel.padding
		let spacing = Theme.Panel.spacing
		let (thumbs, slots) = previewSizes(windows, boxHeight: boxHeight)
		let cardWidths = slots.map { $0 + Theme.Card.inset * 2 }
		let rows = flow(cardWidths, spacing: spacing, available: maxBody.width - padding * 2)
		let widest = rows.map { rowWidth($0.map { cardWidths[$0] }, spacing: spacing) }.max() ?? 0
		let width = max(widest + padding * 2, Theme.Panel.minWidth)
		let rowHeights = rows.map { cardHeight(box: rowBox($0, thumbs: thumbs)) }
		var height =
			rowHeights.reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * spacing + padding * 2
		if scrolls { height = min(height, maxBody.height) }
		var layout = SwitcherLayout(
			style: .grid, rows: rows, groupRows: [], thumbs: thumbs, slots: slots,
			boxHeight: boxHeight,
			previewBox: .zero, bodySize: CGSize(width: width, height: height), scrolls: scrolls)
		layout.slotHeights = slotHeights(rows: rows, thumbs: thumbs)
		return layout
	}

	/// Breaks items of the given widths into rows that fit `available`.
	static func flow(_ widths: [CGFloat], spacing: CGFloat, available: CGFloat) -> [[Int]] {
		var rows: [[Int]] = []
		var current: [Int] = []
		var used: CGFloat = 0
		for (index, width) in widths.enumerated() {
			let added = current.isEmpty ? width : width + spacing
			if used + added > available, !current.isEmpty {
				rows.append(current)
				current = [index]
				used = width
			} else {
				current.append(index)
				used += added
			}
		}
		if !current.isEmpty { rows.append(current) }
		return rows
	}

	static func rowWidth(_ widths: [CGFloat], spacing: CGFloat) -> CGFloat {
		widths.reduce(0, +) + CGFloat(max(widths.count - 1, 0)) * spacing
	}

	// MARK: List

	private static func list(count: Int, maxBody: CGSize) -> SwitcherLayout {
		let rowsHeight = CGFloat(count) * Theme.List.rowHeight + Theme.Panel.padding * 2
		let maxRows =
			CGFloat(Theme.List.maxVisibleRows) * Theme.List.rowHeight + Theme.Panel.padding * 2
		let height = min(max(rowsHeight, Theme.List.minHeight), min(maxRows, maxBody.height))
		let width = min(Theme.List.listWidth + Theme.List.previewWidth, maxBody.width)
		// The pane's preview box; each window's shape is fitted into it when shown.
		let boxWidth = Theme.List.previewWidth - Theme.Panel.padding * 2
		let box = CGSize(width: boxWidth, height: min(boxWidth, height - Theme.List.previewChrome))
		return SwitcherLayout(
			style: .list, rows: [], groupRows: [], thumbs: [], slots: [], boxHeight: 0,
			previewBox: box, bodySize: CGSize(width: width, height: height),
			scrolls: rowsHeight > height)
	}

	// MARK: Grouped

	private static func grouped(_ windows: [SwitcherWindow], maxBody: CGSize) -> SwitcherLayout {
		let groups = WindowGroup.groups(for: windows)
		for height in stride(
			from: Theme.Group.maxThumbHeight, through: Theme.Group.minThumbHeight, by: -6)
		{
			let layout = buildGrouped(
				windows, groups, boxHeight: height, maxBody: maxBody, scrolls: false)
			if layout.bodySize.height <= maxBody.height { return layout }
		}
		return buildGrouped(
			windows, groups, boxHeight: Theme.Group.minThumbHeight, maxBody: maxBody, scrolls: true)
	}

	/// A tile inside a group: the slot plus the selection plate's inset.
	func tileWidth(at index: Int) -> CGFloat {
		slotWidth(at: index) + Theme.Card.inset * 2
	}

	/// A group's width: its window tiles side by side, inside the group's padding.
	func groupWidth(_ group: WindowGroup) -> CGFloat {
		Self.groupWidth(group, slots: slots)
	}

	/// A group's height, from its row's shared preview-area height.
	func groupHeight(_ group: WindowGroup) -> CGFloat {
		Self.groupHeight(box: group.indices.first.map { slotHeight(at: $0) } ?? boxHeight)
	}

	static func groupHeight(box: CGFloat) -> CGFloat {
		Theme.Group.padding + Theme.Group.headerHeight + Theme.Group.headerGap
			+ Theme.Card.inset + box + Theme.Card.labelGap + Theme.Group.labelHeight
			+ Theme.Card.inset + Theme.Group.padding
	}

	static func groupWidth(_ group: WindowGroup, slots: [CGFloat]) -> CGFloat {
		let tiles = group.indices.map {
			(slots.indices.contains($0) ? slots[$0] : 0) + Theme.Card.inset * 2
		}
		return max(rowWidth(tiles, spacing: Theme.Group.tileSpacing), Theme.Group.minWidth) + Theme
			.Group.padding * 2
	}

	private static func buildGrouped(
		_ windows: [SwitcherWindow], _ groups: [WindowGroup], boxHeight: CGFloat, maxBody: CGSize,
		scrolls: Bool
	) -> SwitcherLayout {
		let padding = Theme.Panel.padding
		let spacing = Theme.Panel.spacing * 2
		let (thumbs, slots) = previewSizes(windows, boxHeight: boxHeight)
		let widths = groups.map { groupWidth($0, slots: slots) }
		let rows = flow(widths, spacing: spacing, available: maxBody.width - padding * 2).map {
			$0.map { groups[$0] }
		}
		let widest =
			rows.map { rowWidth($0.map { groupWidth($0, slots: slots) }, spacing: spacing) }.max()
			?? 0
		let width = max(widest + padding * 2, Theme.Panel.minWidth)
		// Every window in a visual row of groups shares that row's preview height.
		let indexRows = rows.map { $0.flatMap(\.indices) }
		let rowHeights = indexRows.map { groupHeight(box: rowBox($0, thumbs: thumbs)) }
		var height =
			rowHeights.reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * spacing + padding * 2
		if scrolls { height = min(height, maxBody.height) }
		var layout = SwitcherLayout(
			style: .grouped, rows: [], groupRows: rows, thumbs: thumbs, slots: slots,
			boxHeight: boxHeight,
			previewBox: .zero, bodySize: CGSize(width: width, height: height), scrolls: scrolls)
		layout.slotHeights = slotHeights(rows: indexRows, thumbs: thumbs)
		return layout
	}

	// MARK: Arrow-key movement

	/// Every window as it's drawn: one array per visual row, left to right, with each
	/// card's horizontal centre so up and down can land on the nearest card.
	func navigationRows(windowCount: Int) -> [[NavigationStop]] {
		switch style {
		case .grid:
			return rows.map { row in
				var x: CGFloat = 0
				return row.map { index in
					let width = cardWidth(at: index)
					defer { x += width + Theme.Panel.spacing }
					return NavigationStop(index: index, x: x + width / 2)
				}
			}
		case .list:
			return (0..<windowCount).map { [NavigationStop(index: $0, x: 0)] }
		case .grouped:
			return groupRows.map { row in
				var stops: [NavigationStop] = []
				var groupX: CGFloat = 0
				for group in row {
					var x = groupX + Theme.Group.padding
					for index in group.indices {
						let width = tileWidth(at: index)
						stops.append(NavigationStop(index: index, x: x + width / 2))
						x += width + Theme.Group.tileSpacing
					}
					groupX += groupWidth(group) + Theme.Panel.spacing * 2
				}
				return stops
			}
		}
	}
}
