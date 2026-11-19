import CoreGraphics

/// Sizing for the three per-app layouts: deck, shelf and columns.
extension SwitcherLayout {
	// MARK: Deck

	/// Cards per app in rows; a closed card holds a stack of its windows, a fanned one is
	/// as wide as its windows side by side.
	static func deck(_ windows: [SwitcherWindow], maxBody: CGSize, fannedAppID: String?) -> SwitcherLayout {
		let groups = WindowGroup.groups(for: windows)
		for height in stride(from: Theme.Card.maxThumbHeight, through: Theme.Card.minThumbHeight, by: -6) {
			let layout = buildDeck(windows, groups, boxHeight: height, maxBody: maxBody, fannedAppID: fannedAppID, scrolls: false)
			if layout.bodySize.height <= maxBody.height { return layout }
		}
		return buildDeck(windows, groups, boxHeight: Theme.Card.minThumbHeight, maxBody: maxBody, fannedAppID: fannedAppID, scrolls: true)
	}

	private static func buildDeck(
		_ windows: [SwitcherWindow], _ groups: [WindowGroup], boxHeight: CGFloat, maxBody: CGSize,
		fannedAppID: String?, scrolls: Bool
	) -> SwitcherLayout {
		let padding = Theme.Panel.padding
		let spacing = Theme.Panel.spacing * 2
		let (thumbs, slots) = previewSizes(windows, boxHeight: boxHeight)
		let peek = Theme.Deck.peek * CGFloat(Theme.Deck.layers - 1)
		let card = CGSize(
			width: (boxHeight * Theme.Card.boxAspect).rounded() + Theme.Card.inset * 2 + peek + Theme.Group.padding * 2,
			height: groupHeight(box: boxHeight) + peek)
		let widths = groups.map { $0.id == fannedAppID ? max(groupWidth($0, slots: slots), card.width) : card.width }
		let rows = flow(widths, spacing: spacing, available: maxBody.width - padding * 2)
		let widest = rows.map { rowWidth($0.map { widths[$0] }, spacing: spacing) }.max() ?? 0
		var height = CGFloat(rows.count) * card.height + CGFloat(max(rows.count - 1, 0)) * spacing + padding * 2
		if scrolls { height = min(height, maxBody.height) }
		var layout = SwitcherLayout(
			style: .deck, rows: [], groupRows: rows.map { $0.map { groups[$0] } }, thumbs: thumbs, slots: slots,
			boxHeight: boxHeight, previewBox: .zero,
			bodySize: CGSize(width: max(widest + padding * 2, Theme.Panel.minWidth), height: height), scrolls: scrolls)
		layout.deckCard = card
		layout.fannedAppID = fannedAppID
		return layout
	}

	// MARK: Shelf

	/// A row of app icons, and below it a shelf as wide as the app with the widest set of
	/// windows, so the panel doesn't change size as the highlighted app changes.
	static func shelf(_ windows: [SwitcherWindow], maxBody: CGSize) -> SwitcherLayout {
		let groups = WindowGroup.groups(for: windows)
		let padding = Theme.Panel.padding
		let available = maxBody.width - padding * 2
		let count = CGFloat(max(groups.count, 1))
		let tile = min(Theme.Shelf.iconTile, ((available - (count - 1) * Theme.Panel.spacing) / count).rounded(.down))
		let strip = count * tile + (count - 1) * Theme.Panel.spacing
		var chosen: SwitcherLayout?
		for height in stride(from: Theme.Card.maxThumbHeight, through: Theme.Card.minThumbHeight, by: -6) {
			let (thumbs, slots) = previewSizes(windows, boxHeight: height)
			let shelfWidths = groups.map { group in
				rowWidth(group.indices.map { slots[$0] + Theme.Card.inset * 2 }, spacing: Theme.Group.tileSpacing)
			}
			let shelf = shelfWidths.max() ?? 0
			let shelfHeight = Theme.Card.inset + Theme.Group.labelHeight + Theme.Card.labelGap + height + Theme.Card.inset
			let bodyHeight = padding + tile + Theme.Shelf.gap + shelfHeight + padding
			var layout = SwitcherLayout(
				style: .shelf, rows: [], groupRows: [groups], thumbs: thumbs, slots: slots, boxHeight: height,
				previewBox: .zero,
				bodySize: CGSize(width: max(max(strip, shelf) + padding * 2, Theme.Panel.minWidth), height: bodyHeight),
				scrolls: false)
			layout.iconTile = tile
			chosen = layout
			if shelf <= available, bodyHeight <= maxBody.height { break }
		}
		return chosen ?? .empty
	}

	// MARK: Columns

	/// One column per app, each window's preview fitted to the column width and stacked,
	/// so a column is only as tall as its own windows.
	static func columns(_ windows: [SwitcherWindow], maxBody: CGSize) -> SwitcherLayout {
		let groups = WindowGroup.groups(for: windows)
		let padding = Theme.Panel.padding
		let spacing = Theme.Panel.spacing * 2
		let available = maxBody.width - padding * 2
		let count = CGFloat(max(groups.count, 1))
		let width = min(max(((available - (count - 1) * spacing) / count).rounded(.down), Theme.Columns.minWidth), Theme.Columns.maxWidth)
		let inner = width - Theme.Group.padding * 2 - Theme.Card.inset * 2
		for boxHeight in stride(from: Theme.Columns.maxPreviewHeight, through: Theme.Columns.minPreviewHeight, by: -6) {
			let layout = buildColumns(
				windows, groups, width: width, inner: inner, boxHeight: boxHeight, maxBody: maxBody, scrolls: false)
			if layout.bodySize.height <= maxBody.height { return layout }
		}
		return buildColumns(
			windows, groups, width: width, inner: inner, boxHeight: Theme.Columns.minPreviewHeight, maxBody: maxBody,
			scrolls: true)
	}

	/// A column's height: header, then each window's title row and preview.
	static func columnHeight(_ group: WindowGroup, thumbs: [CGSize]) -> CGFloat {
		let tiles = group.indices.map { index in
			Theme.Card.inset + Theme.Group.labelHeight + Theme.Card.labelGap + thumbs[index].height + Theme.Card.inset
		}
		return Theme.Group.padding + Theme.Group.headerHeight + Theme.Group.headerGap
			+ tiles.reduce(0, +) + CGFloat(max(tiles.count - 1, 0)) * Theme.Group.tileSpacing + Theme.Group.padding
	}

	private static func buildColumns(
		_ windows: [SwitcherWindow], _ groups: [WindowGroup], width: CGFloat, inner: CGFloat, boxHeight: CGFloat,
		maxBody: CGSize, scrolls: Bool
	) -> SwitcherLayout {
		let padding = Theme.Panel.padding
		let spacing = Theme.Panel.spacing * 2
		let box = CGSize(width: inner, height: boxHeight)
		let (scaled, _) = previewSizes(windows, boxHeight: boxHeight)
		let thumbs: [CGSize] = windows.enumerated().map { index, window in
			// The window's shape fitted to the column, at the same relative size.
			let fitted = fit(aspect: aspect(of: window), in: box)
			let full = fit(aspect: aspect(of: window), in: CGSize(width: boxHeight * Theme.Card.boxAspect, height: boxHeight))
			let scale = full.width > 0 ? min(scaled[index].width / full.width, 1) : 1
			return CGSize(width: (fitted.width * scale).rounded(), height: (fitted.height * scale).rounded())
		}
		let slots = windows.map { _ in inner }
		let rows = flow(groups.map { _ in width }, spacing: spacing, available: maxBody.width - padding * 2)
		let rowHeights = rows.map { $0.map { columnHeight(groups[$0], thumbs: thumbs) }.max() ?? 0 }
		let widest = rows.map { rowWidth($0.map { _ in width }, spacing: spacing) }.max() ?? 0
		var height = rowHeights.reduce(0, +) + CGFloat(max(rows.count - 1, 0)) * spacing + padding * 2
		if scrolls { height = min(height, maxBody.height) }
		var layout = SwitcherLayout(
			style: .columns, rows: [], groupRows: rows.map { $0.map { groups[$0] } }, thumbs: thumbs, slots: slots,
			boxHeight: boxHeight, previewBox: .zero,
			bodySize: CGSize(width: max(widest + padding * 2, Theme.Panel.minWidth), height: height), scrolls: scrolls)
		layout.columnWidth = width
		layout.rowHeights = rowHeights
		layout.slotHeights = thumbs.map(\.height)
		return layout
	}
}
