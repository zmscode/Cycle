import AppKit
import RiftCore

/// A window being dragged from the switcher toward the tiling board.
struct WindowDrag {
	/// The window picked up.
	let windowID: CGWindowID
	/// Every window being dragged: the one picked up, or all the marked windows in the
	/// order they were marked (the order they fill a preset, left to right).
	let windowIDs: [CGWindowID]
	/// The screen being tiled: the one the switcher is on, or another display picked from
	/// the board's header.
	var screen: NSScreen
	/// Picked up from the board rather than the switcher: dropping it off the board takes
	/// it out of the layout.
	var fromBoard = false
	/// The display chip the pointer is resting on, about to switch the board to it.
	var hoveredDisplay: String?
	var board: TilingBoard
	/// The pointer, in the overlay's coordinates (top-left of the screen).
	var pointer: CGPoint
	var target: TileTarget? {
		didSet {
			guard target != oldValue else { return }
			// A different preset starts its slots afresh.
			if presetID(target) != presetID(oldValue) { slotOffset = 0 }
			updatePreview()
		}
	}
	/// Over a preset chip with several windows, how far scrolling has rotated them through
	/// the preset's slots (0 is mark order, left to right).
	var slotOffset = 0 {
		didSet {
			guard slotOffset != oldValue else { return }
			updatePreview()
		}
	}
	/// The layout the drop would make. Over a preset chip the board shows it in place of
	/// the current one; over the board itself the tiles stay put (they're what the pointer
	/// is aiming at) and only the dragged windows are drawn where they'd land.
	private(set) var preview: RiftLayout<CGWindowID>?

	/// The layout dropping here makes; nil when nothing changes.
	var result: RiftLayout<CGWindowID>? {
		target.flatMap { board.dropping(windowIDs, on: $0, slotOffset: slotOffset) }
	}

	/// Whether scrolling rotates the windows through slots: several windows over a preset.
	var rotatesSlots: Bool {
		if case .preset? = target { windowIDs.count > 1 } else { false }
	}

	/// The board slot each dragged window takes over the hovered preset chip.
	var slotAssignment: [Int: CGWindowID] {
		guard case .preset(let preset, let slot)? = target else { return [:] }
		return board.assignment(of: preset, putting: windowIDs, from: slot, offset: slotOffset)
	}

	mutating func updatePreview() {
		preview = result
	}

	private func presetID(_ target: TileTarget?) -> String? {
		if case .preset(let preset, _)? = target { preset.id } else { nil }
	}

	/// Whether the board shows the whole preview layout (the pointer is on a preset chip,
	/// off the board, so nothing moves under it).
	var showsWholePreview: Bool {
		if case .preset? = target { preview != nil } else { false }
	}

	/// Letting go now takes the window out of the layout: it came from the board and the
	/// pointer is off the board's card.
	var untiles: Bool {
		let slack = Theme.Tiling.boardSlack
		return fromBoard && target == nil
			&& !board.placement.card.insetBy(dx: -slack, dy: -slack).contains(pointer)
	}

	/// Tiled windows the drop would leave out (a preset with fewer slots than windows).
	var displaced: Int {
		guard let preview else { return 0 }
		let kept = Set(preview.paneIDs)
		return (board.layout?.paneIDs ?? []).filter {
			!TilingSlot.isPlaceholder($0) && !kept.contains($0)
		}.count
	}
}
