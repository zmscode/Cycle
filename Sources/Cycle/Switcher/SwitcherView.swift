import AppKit
import SwiftUI

/// Row breaks and sizes, computed up front so the panel can be sized exactly (DockDoor keeps
/// the same thing as `panelRowLayout: [[PreviewPanelRowLayoutItem]]`). Cards share one size:
/// a header with the window controls and names, and a thumbnail fitted below it.
struct SwitcherLayout {
	let rows: [[Int]]
	let card: CGSize
	let thumb: CGSize
	let stripSize: CGSize
	let panelSize: CGSize
	let scrolls: Bool

	static let empty = SwitcherLayout(rows: [], card: .zero, thumb: .zero, stripSize: .zero, panelSize: .zero, scrolls: false)

	static let padding: CGFloat = 12
	static let trayRadius: CGFloat = 30
	static let cardRadius: CGFloat = 18
	static let spacing: CGFloat = 12
	static let cardInset: CGFloat = 6
	static let headerHeight: CGFloat = 36
	static let searchHeight: CGFloat = 34
	static let searchGap: CGFloat = 10
	static let thumbAspect: CGFloat = 1.68

	static func metrics(for count: Int, maxSize: CGSize) -> SwitcherLayout {
		let maxStrip = CGSize(width: maxSize.width, height: maxSize.height - searchHeight - searchGap)
		// Shrink cards until everything fits, but never below a readable size.
		for height in stride(from: CGFloat(150), through: 96, by: -6) {
			let layout = build(count, thumbHeight: height, maxStrip: maxStrip, scrolls: false)
			if layout.stripSize.height <= maxStrip.height { return layout }
		}
		return build(count, thumbHeight: 96, maxStrip: maxStrip, scrolls: true)
	}

	private static func build(_ count: Int, thumbHeight: CGFloat, maxStrip: CGSize, scrolls: Bool) -> SwitcherLayout {
		let thumb = CGSize(width: (thumbHeight * thumbAspect).rounded(), height: thumbHeight)
		let card = CGSize(width: thumb.width + cardInset * 2, height: thumb.height + headerHeight + cardInset)
		let perRow = max(1, Int((maxStrip.width - padding * 2 + spacing) / (card.width + spacing)))
		let columns = min(perRow, max(count, 1))
		let rows = stride(from: 0, to: count, by: perRow).map { Array($0..<min($0 + perRow, count)) }
		let width = CGFloat(columns) * card.width + CGFloat(columns - 1) * spacing + padding * 2
		var height = CGFloat(rows.count) * card.height + CGFloat(max(rows.count - 1, 0)) * spacing + padding * 2
		if scrolls { height = min(height, maxStrip.height) }
		let strip = CGSize(width: width, height: height)
		return SwitcherLayout(
			rows: rows, card: card, thumb: thumb, stripSize: strip,
			panelSize: CGSize(width: max(width, 320), height: height + searchHeight + searchGap),
			scrolls: scrolls)
	}
}

struct SwitcherView: View {
	let state: SwitcherState
	let controller: SwitcherController
	let metrics: SwitcherLayout

	var body: some View {
		VStack(spacing: SwitcherLayout.searchGap) {
			SearchPill(isSearching: state.isSearching, query: state.searchQuery)
			strip
		}
		.frame(width: metrics.panelSize.width, height: metrics.panelSize.height, alignment: .top)
	}

	private var strip: some View {
		ScrollViewReader { proxy in
			ScrollView(.vertical) {
				// Each card is its own glass. (Inside a GlassEffectContainer the cards merge
				// into one glass layer and the selection ring overlay is lost.)
				Group {
					VStack(alignment: .leading, spacing: SwitcherLayout.spacing) {
						ForEach(Array(metrics.rows.enumerated()), id: \.offset) { _, row in
							HStack(spacing: SwitcherLayout.spacing) {
								ForEach(row, id: \.self) { index in
									if index < state.windows.count {
										let window = state.windows[index]
										WindowCard(
											window: window,
											image: state.images[window.id],
											tint: state.tints[window.id],
											isSelected: window.id == state.selectedID,
											metrics: metrics,
											onAction: { controller.perform($0, on: window.id) }
										)
										.id(window.id)
										.onHover { inside in if inside { controller.hover(window.id) } }
										.onTapGesture { controller.click(window.id) }
									}
								}
							}
						}
					}
				}
				.padding(SwitcherLayout.padding)
			}
			.scrollDisabled(!metrics.scrolls)
			.scrollIndicators(.never)
			.scrollClipDisabled()
			.onChange(of: state.selectedID) { _, id in
				guard metrics.scrolls, let id else { return }
				withAnimation(.smooth(duration: 0.2)) { proxy.scrollTo(id, anchor: .center) }
			}
		}
		.frame(width: metrics.stripSize.width, height: metrics.stripSize.height)
		// The tray: clear glass behind the cards, so the desktop shows through and the
		// tinted cards sit on it.
		.background {
			ConcentricRectangle(corners: .fixed(SwitcherLayout.trayRadius), isUniform: true)
				.fill(.clear)
				.glassEffect(.clear, in: RoundedRectangle(cornerRadius: SwitcherLayout.trayRadius, style: .continuous))
		}
	}
}

/// "Press , to search windows", or the live query once search is open.
struct SearchPill: View {
	let isSearching: Bool
	let query: String

	var body: some View {
		HStack(spacing: 7) {
			Image(systemName: "magnifyingglass")
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(.secondary)
			if isSearching {
				HStack(spacing: 1) {
					Text(query.isEmpty ? "Search windows" : query)
						.foregroundStyle(query.isEmpty ? .secondary : .primary)
					Rectangle().fill(Color.accentColor).frame(width: 1.5, height: 14)
				}
			} else if !Permissions.shared.screenRecording {
				// Without Screen Recording the cards fall back to app icons; say why.
				Text("Allow Screen Recording for previews").foregroundStyle(.secondary)
			} else {
				Text("Press , to search windows").foregroundStyle(.secondary)
			}
		}
		.font(.system(size: 12))
		.lineLimit(1)
		.padding(.horizontal, 12)
		.frame(width: 270, height: SwitcherLayout.searchHeight, alignment: .leading)
		.glassEffect(.regular, in: .capsule)
		.animation(.smooth(duration: 0.2), value: isSearching)
	}
}

struct WindowCard: View {
	let window: SwitcherWindow
	let image: NSImage?
	let tint: NSColor?
	let isSelected: Bool
	let metrics: SwitcherLayout
	let onAction: (CardAction) -> Void

	private var isDimmed: Bool { window.isMinimized || window.isAppHidden }
	private var tintColor: Color { Color(nsColor: tint ?? .gray) }
	private let shape = RoundedRectangle(cornerRadius: SwitcherLayout.cardRadius, style: .continuous)
	static let selectionBlue = Color(red: 0.22, green: 0.52, blue: 1.0)

	var body: some View {
		VStack(spacing: 0) {
			header
			thumbnail
				.frame(width: metrics.thumb.width, height: metrics.thumb.height)
				.padding(.bottom, SwitcherLayout.cardInset)
		}
		.frame(width: metrics.card.width, height: metrics.card.height)
		// Each card is a piece of glass tinted with its window's colour, blue when selected.
		// Not `.interactive()`: that glass stretches toward the pointer on hover while the
		// ring overlay stays put, which showed as a bump on the card's top edge.
		.glassEffect(
			.regular.tint(isSelected ? Self.selectionBlue.opacity(0.6) : tintColor.opacity(0.5)),
			in: shape
		)
		.overlay {
			shape.strokeBorder(
				isSelected
					? AnyShapeStyle(LinearGradient(
						colors: [.white.opacity(0.95), Self.selectionBlue],
						startPoint: .top, endPoint: .bottom))
					: AnyShapeStyle(Color.white.opacity(0.0)),
				lineWidth: 2)
		}
		.shadow(color: isSelected ? Self.selectionBlue.opacity(0.55) : .black.opacity(0.18), radius: isSelected ? 14 : 6, y: 3)
		.zIndex(isSelected ? 1 : 0)
		.animation(.smooth(duration: 0.18), value: isSelected)
		.contentShape(shape)
	}

	private var header: some View {
		HStack(spacing: 8) {
			if !window.isWindowless {
				TrafficLights(onAction: onAction)
			}
			if let icon = window.icon {
				Image(nsImage: icon).resizable().frame(width: 22, height: 22)
			}
			VStack(alignment: .leading, spacing: 0) {
				Text(window.appName)
					.font(.system(size: 11.5, weight: .semibold))
				if !window.isWindowless {
					Text(window.title.isEmpty ? window.appName : window.title)
						.font(.system(size: 10.5))
						.opacity(0.75)
				}
			}
			.foregroundStyle(.white)
			.shadow(color: .black.opacity(0.25), radius: 1, y: 0.5)
			.lineLimit(1)
			.truncationMode(.tail)
			Spacer(minLength: 0)
			badge
		}
		.padding(.horizontal, 10)
		.frame(height: SwitcherLayout.headerHeight)
	}

	@ViewBuilder private var thumbnail: some View {
		ZStack {
			if let image, !window.isWindowless {
				// Fill the card's width and keep the top of the window (title bar,
				// toolbar) in view, cropping the bottom, as the reference cards do.
				Image(nsImage: image)
					.resizable()
					.interpolation(.high)
					.aspectRatio(contentMode: .fill)
					.frame(width: metrics.thumb.width, height: metrics.thumb.height, alignment: .top)
					.clipShape(RoundedRectangle(cornerRadius: SwitcherLayout.cardRadius - SwitcherLayout.cardInset, style: .continuous))
			} else if let icon = window.icon {
				Image(nsImage: icon)
					.resizable()
					.aspectRatio(contentMode: .fit)
					.frame(width: min(metrics.thumb.height * 0.5, 80))
			}
		}
		.opacity(isDimmed ? 0.5 : 1)
	}

	@ViewBuilder private var badge: some View {
		let symbol: String? =
			window.isMinimized ? "minus.circle.fill"
			: window.isAppHidden ? "eye.slash.circle.fill"
			: window.isOnOtherSpace ? "square.on.square" : nil
		if let symbol {
			Image(systemName: symbol)
				.font(.system(size: 11, weight: .semibold))
				.foregroundStyle(.white.opacity(0.8))
		}
	}
}

/// Quit / close / minimize / full screen, drawn as traffic lights whose glyphs appear on
/// hover (DockDoor's `PreviewActionTrafficLightGlyph`).
struct TrafficLights: View {
	let onAction: (CardAction) -> Void
	@State private var hovering = false

	var body: some View {
		HStack(spacing: 6) {
			ForEach(CardAction.trafficLights, id: \.self) { action in
				Button { onAction(action) } label: {
					ZStack {
						Circle().fill(Self.color(action))
						Circle().strokeBorder(.black.opacity(0.18), lineWidth: 0.5)
						if hovering {
							Image(systemName: Self.glyph(action))
								.font(.system(size: 7, weight: .black))
								.foregroundStyle(.black.opacity(0.6))
						}
					}
					.frame(width: 12, height: 12)
				}
				.buttonStyle(.plain)
				.help(Self.label(action))
			}
		}
		.onHover { hovering = $0 }
	}

	static func color(_ action: CardAction) -> Color {
		switch action {
		case .quit: Color(red: 0.86, green: 0.25, blue: 0.45)
		case .close: Color(red: 1.0, green: 0.37, blue: 0.34)
		case .minimize: Color(red: 1.0, green: 0.74, blue: 0.18)
		case .fullScreen: Color(red: 0.16, green: 0.79, blue: 0.25)
		case .hide: Color.gray
		}
	}

	static func glyph(_ action: CardAction) -> String {
		switch action {
		case .quit: "power"
		case .close: "xmark"
		case .minimize: "minus"
		case .fullScreen: "arrow.up.left.and.arrow.down.right"
		case .hide: "eye.slash"
		}
	}

	static func label(_ action: CardAction) -> String {
		switch action {
		case .quit: "Quit App (Q)"
		case .close: "Close Window (W)"
		case .minimize: "Minimize (M)"
		case .fullScreen: "Full Screen (F)"
		case .hide: "Hide App (H)"
		}
	}
}
