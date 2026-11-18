import CoreGraphics

/// Sizes for the current layout, computed up front so the panel can be sized exactly.
struct SwitcherLayout {
	let style: SwitcherStyle
	/// Grid: card indexes per row. Grouped: unused.
	let rows: [[Int]]
	/// Grouped: groups per row.
	let groupRows: [[WindowGroup]]
	let card: CGSize
	let thumb: CGSize
	/// The content area under the search bar.
	let bodySize: CGSize
	let panelSize: CGSize
	let scrolls: Bool
	/// The top row's height: the full search bar, or a slim strip with just the gear.
	var headerHeight: CGFloat = Theme.Panel.searchHeight
	var showsSearchBar: Bool { headerHeight == Theme.Panel.searchHeight }

	static let empty = SwitcherLayout(
		style: .grid, rows: [], groupRows: [], card: .zero, thumb: .zero,
		bodySize: .zero, panelSize: .zero, scrolls: false)

	static func metrics(
		for windows: [SwitcherWindow], style: SwitcherStyle, maxSize: CGSize, showsSearchBar: Bool
	) -> SwitcherLayout {
		let header = showsSearchBar ? Theme.Panel.searchHeight : Theme.Panel.compactHeaderHeight
		let maxBody = CGSize(width: maxSize.width, height: maxSize.height - header)
		var layout: SwitcherLayout
		switch style {
		case .grid: layout = grid(count: windows.count, maxBody: maxBody)
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

	// MARK: Grid

	private static func grid(count: Int, maxBody: CGSize) -> SwitcherLayout {
		// Shrink thumbnails until everything fits, but never below a readable size.
		for height in stride(from: Theme.Card.maxThumbHeight, through: Theme.Card.minThumbHeight, by: -6) {
			let layout = buildGrid(count, thumbHeight: height, maxBody: maxBody, scrolls: false)
			if layout.bodySize.height <= maxBody.height { return layout }
		}
		return buildGrid(count, thumbHeight: Theme.Card.minThumbHeight, maxBody: maxBody, scrolls: true)
	}

	private static func buildGrid(_ count: Int, thumbHeight: CGFloat, maxBody: CGSize, scrolls: Bool) -> SwitcherLayout {
		let padding = Theme.Panel.padding
		let spacing = Theme.Panel.spacing
		let inset = Theme.Card.inset
		let thumb = CGSize(width: (thumbHeight * Theme.Card.thumbAspect).rounded(), height: thumbHeight)
		let card = CGSize(
			width: thumb.width + inset * 2,
			height: inset + thumb.height + Theme.Card.labelGap + Theme.Card.labelHeight + inset / 2)
		let perRow = max(1, Int((maxBody.width - padding * 2 + spacing) / (card.width + spacing)))
		let columns = min(perRow, max(count, 1))
		let rows = stride(from: 0, to: count, by: perRow).map { Array($0..<min($0 + perRow, count)) }
		let width = max(
			CGFloat(columns) * card.width + CGFloat(columns - 1) * spacing + padding * 2,
			Theme.Panel.minWidth)
		var height = CGFloat(rows.count) * card.height + CGFloat(max(rows.count - 1, 0)) * spacing + padding * 2
		if scrolls { height = min(height, maxBody.height) }
		return SwitcherLayout(
			style: .grid, rows: rows, groupRows: [], card: card, thumb: thumb,
			bodySize: CGSize(width: width, height: height),
			panelSize: CGSize(width: width, height: height + Theme.Panel.searchHeight),
			scrolls: scrolls)
	}

	// MARK: List

	private static func list(count: Int, maxBody: CGSize) -> SwitcherLayout {
		let rowsHeight = CGFloat(count) * Theme.List.rowHeight + Theme.Panel.padding * 2
		let maxRows = CGFloat(Theme.List.maxVisibleRows) * Theme.List.rowHeight + Theme.Panel.padding * 2
		let height = min(max(rowsHeight, Theme.List.minHeight), min(maxRows, maxBody.height))
		let width = min(Theme.List.listWidth + Theme.List.previewWidth, maxBody.width)
		let previewThumb = CGSize(
			width: Theme.List.previewWidth - Theme.Panel.padding * 2,
			height: ((Theme.List.previewWidth - Theme.Panel.padding * 2) / Theme.Card.thumbAspect).rounded())
		return SwitcherLayout(
			style: .list, rows: [], groupRows: [], card: .zero, thumb: previewThumb,
			bodySize: CGSize(width: width, height: height),
			panelSize: CGSize(width: width, height: height + Theme.Panel.searchHeight),
			scrolls: rowsHeight > height)
	}

	// MARK: Grouped

	private static func grouped(_ windows: [SwitcherWindow], maxBody: CGSize) -> SwitcherLayout {
		let groups = WindowGroup.groups(for: windows)
		for height in stride(from: Theme.Group.maxThumbHeight, through: Theme.Group.minThumbHeight, by: -6) {
			let layout = buildGrouped(groups, thumbHeight: height, maxBody: maxBody, scrolls: false)
			if layout.bodySize.height <= maxBody.height { return layout }
		}
		return buildGrouped(groups, thumbHeight: Theme.Group.minThumbHeight, maxBody: maxBody, scrolls: true)
	}

	/// Width of a group: its window tiles side by side, inside the group's padding.
	static func groupWidth(_ group: WindowGroup, thumb: CGSize) -> CGFloat {
		let count = CGFloat(max(group.indices.count, 1))
		let tiles = count * (thumb.width + Theme.Card.inset * 2) + (count - 1) * Theme.Group.tileSpacing
		return max(tiles, Theme.Group.minWidth) + Theme.Group.padding * 2
	}

	static func groupHeight(thumb: CGSize) -> CGFloat {
		Theme.Group.padding + Theme.Group.headerHeight + Theme.Group.headerGap
			+ Theme.Card.inset + thumb.height + Theme.Card.labelGap + Theme.Group.labelHeight
			+ Theme.Card.inset / 2 + Theme.Group.padding
	}

	private static func buildGrouped(
		_ groups: [WindowGroup], thumbHeight: CGFloat, maxBody: CGSize, scrolls: Bool
	) -> SwitcherLayout {
		let padding = Theme.Panel.padding
		let spacing = Theme.Panel.spacing * 2
		let thumb = CGSize(width: (thumbHeight * Theme.Card.thumbAspect).rounded(), height: thumbHeight)
		let available = maxBody.width - padding * 2
		var rows: [[WindowGroup]] = [[]]
		var rowWidth: CGFloat = 0
		var widest: CGFloat = 0
		for group in groups {
			let width = groupWidth(group, thumb: thumb)
			let added = rows[rows.count - 1].isEmpty ? width : width + spacing
			if rowWidth + added > available, !rows[rows.count - 1].isEmpty {
				widest = max(widest, rowWidth)
				rows.append([group])
				rowWidth = width
			} else {
				rows[rows.count - 1].append(group)
				rowWidth += added
			}
		}
		widest = max(widest, rowWidth)
		let rowHeight = groupHeight(thumb: thumb)
		let width = max(widest + padding * 2, Theme.Panel.minWidth)
		var height = CGFloat(rows.count) * rowHeight + CGFloat(max(rows.count - 1, 0)) * spacing + padding * 2
		if scrolls { height = min(height, maxBody.height) }
		return SwitcherLayout(
			style: .grouped, rows: [], groupRows: rows, card: .zero, thumb: thumb,
			bodySize: CGSize(width: width, height: height),
			panelSize: CGSize(width: width, height: height + Theme.Panel.searchHeight),
			scrolls: scrolls)
	}
}
