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

	func toScreen(_ point: CGPoint) -> CGPoint {
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
}
