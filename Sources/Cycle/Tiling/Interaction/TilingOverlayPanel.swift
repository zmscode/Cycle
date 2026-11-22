import AppKit
import SwiftUI

/// A click-through window over the switcher's screen while a window is dragged: it shows
/// the tiling board under the switcher and the dragged window following the pointer. It
/// ignores the mouse, so the drag stays with the switcher panel, where it began.
@MainActor
final class TilingOverlayPanel {
	private let state: SwitcherState
	private var panel: NSPanel?
	/// The screen the overlay covers, in AppKit coordinates.
	private var screenFrame: CGRect = .zero

	init(state: SwitcherState) {
		self.state = state
	}

	/// Covers `screen` and returns where the board and its preset chips go, in overlay
	/// coordinates: under the switcher, else above it, else along the bottom of the screen.
	func show(on screen: NSScreen, below switcher: CGRect, presets: [TilingPreset])
		-> BoardPlacement
	{
		screenFrame = screen.frame
		let panel = self.panel ?? makePanel()
		self.panel = panel
		panel.setFrame(screen.frame, display: false)
		panel.orderFrontRegardless()
		return Self.placement(
			frame: screen.frame, visible: screen.visibleFrame, switcher: switcher, presets: presets)
	}

	func hide() {
		panel?.orderOut(nil)
	}

	/// A window-server point (top-left of the main screen, y down) in the overlay's
	/// coordinates.
	func local(windowServer point: CGPoint) -> CGPoint {
		let height = NSScreen.screens.first?.frame.height ?? 0
		return local(CGPoint(x: point.x, y: height - point.y))
	}

	/// A rectangle in the overlay's coordinates on the screen (AppKit coordinates).
	func global(_ rect: CGRect) -> CGRect {
		CGRect(
			x: screenFrame.minX + rect.minX, y: screenFrame.maxY - rect.maxY, width: rect.width,
			height: rect.height)
	}

	/// A screen point (AppKit, bottom-left origin) in the overlay's coordinates.
	func local(_ point: CGPoint) -> CGPoint {
		CGPoint(x: point.x - screenFrame.minX, y: screenFrame.maxY - point.y)
	}

	/// The board's layout for a screen with `frame` and `visible` area (AppKit coordinates)
	/// and the switcher at `switcher`.
	static func placement(
		frame: CGRect, visible: CGRect, switcher: CGRect, presets: [TilingPreset]
	) -> BoardPlacement {
		let width = min(Theme.Tiling.boardWidth, visible.width * 0.4)
		let aspect = visible.height / max(visible.width, 1)
		let height = width * aspect
		let padding = Theme.Tiling.boardPadding
		let header = Theme.Tiling.boardHeaderHeight

		// Preset chips: a row of small screens under the board, each with its name.
		let spacing = Theme.Tiling.chipSpacing
		let count = CGFloat(presets.count)
		let chipWidth =
			count > 0 ? min(Theme.Tiling.chipMaxWidth, (width - spacing * (count - 1)) / count) : 0
		let chipHeight = chipWidth * aspect
		let chipsHeight =
			presets.isEmpty ? 0 : Theme.Tiling.chipsGap + chipHeight + Theme.Tiling.chipLabelHeight

		let cardSize = CGSize(
			width: width + padding * 2, height: header + height + chipsHeight + padding * 2)
		let offset = Theme.Tiling.boardOffset
		// Overlay coordinates: top-left of the screen, y down.
		let top = frame.maxY - switcher.maxY
		let bottom = frame.maxY - switcher.minY
		let visibleTop = frame.maxY - visible.maxY
		let visibleBottom = frame.maxY - visible.minY
		let cardY: CGFloat
		if bottom + offset + cardSize.height <= visibleBottom - offset {
			cardY = bottom + offset
		} else if top - offset - cardSize.height >= visibleTop + offset {
			cardY = top - offset - cardSize.height
		} else {
			cardY = visibleBottom - offset - cardSize.height
		}
		let midX = switcher.midX - frame.minX
		let cardX = min(
			max(midX - cardSize.width / 2, visible.minX - frame.minX + offset),
			visible.maxX - frame.minX - offset - cardSize.width)
		let card = CGRect(origin: CGPoint(x: cardX, y: cardY), size: cardSize)
		let board = CGRect(
			x: card.minX + padding, y: card.minY + padding + header, width: width, height: height)

		let rowWidth = chipWidth * count + spacing * max(count - 1, 0)
		var x = board.midX - rowWidth / 2
		let chipY = board.maxY + Theme.Tiling.chipsGap
		let chips = presets.map { preset in
			defer { x += chipWidth + spacing }
			return PresetChip(
				preset: preset, rect: CGRect(x: x, y: chipY, width: chipWidth, height: chipHeight))
		}
		return BoardPlacement(card: card, screen: board, chips: chips)
	}

	private func makePanel() -> NSPanel {
		let panel = NSPanel(
			contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
			backing: .buffered, defer: false)
		// Above the switcher and its gear.
		panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
		panel.collectionBehavior = [
			.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle,
		]
		panel.isOpaque = false
		panel.backgroundColor = .clear
		panel.hasShadow = false
		panel.ignoresMouseEvents = true
		panel.animationBehavior = .none
		let host = NSHostingView(rootView: TilingOverlayView(state: state))
		host.sizingOptions = []
		panel.contentView = host
		return panel
	}
}
