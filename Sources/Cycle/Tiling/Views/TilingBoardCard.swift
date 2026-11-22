import SwiftUI

/// The board on its glass card: a small copy of the screen with the windows already tiled
/// on it (and any empty preset slots), and the presets in a row underneath. With a drop
/// lined up, the board shows the layout the drop would make: every window slides to its
/// new place and the dragged ones are outlined where they'll land.
struct TilingBoardCard: View {
	let board: TilingBoard
	/// The window being dragged over it, if any (otherwise the board just shows the layout,
	/// with grips on its dividers).
	let drag: WindowDrag?
	let state: SwitcherState

	@Environment(\.accessibilityReduceMotion) private var reduceMotion
	@Environment(\.colorSchemeContrast) private var contrast

	private var placement: BoardPlacement { board.placement }

	var body: some View {
		ZStack(alignment: .topLeading) {
			Color.clear
				.frame(width: placement.card.width, height: placement.card.height)
				.glassSheet(cornerRadius: Theme.Tiling.boardRadius)
				.offset(x: placement.card.minX, y: placement.card.minY)
			Label(caption, systemImage: "rectangle.split.2x1")
				.font(.caption.weight(.medium))
				.foregroundStyle(.secondary)
				.contentTransition(.opacity)
				.lineLimit(1)
				.frame(width: captionWidth, alignment: .leading)
				.offset(
					x: placement.screen.minX,
					y: placement.card.minY + Theme.Tiling.boardPadding)
			ForEach(placement.displays) { chip in
				displayChip(chip)
			}
			screen
				.offset(x: board.rect.minX, y: board.rect.minY)
			ForEach(placement.chips) { chip in
				chipView(chip)
			}
		}
		.animation(reduceMotion ? nil : Theme.Motion.fade, value: drag?.target)
		.animation(reduceMotion ? nil : Theme.Motion.fade, value: drag?.slotOffset)
		.environment(\.colorScheme, .dark)
	}

	/// The header's width left of the display chips.
	private var captionWidth: CGFloat {
		guard let first = placement.displays.first else { return placement.screen.width }
		return max(first.rect.minX - placement.screen.minX - 8, 40)
	}

	/// A display in the header: the one the board shows is lit; the one being rested on
	/// is outlined until the board switches to it.
	private func displayChip(_ chip: DisplayChip) -> some View {
		let shown = (drag?.screen.displayUUID ?? currentDisplay) == chip.display
		let hovered = drag?.hoveredDisplay == chip.display
		let shape = RoundedRectangle(cornerRadius: 3)
		return shape
			.fill(shown ? Theme.Colors.mark.opacity(0.55) : .white.opacity(0.1))
			// The shown display has a heavier edge and number, not just a colour.
			.strokeBorder(
				hovered ? .white : shown ? .white.opacity(0.9) : .white.opacity(0.3),
				lineWidth: hovered || shown ? 2 : 1
			)
			.overlay {
				Text(chip.number, format: .number)
					.font(
						.system(size: 10, weight: shown ? .heavy : .medium).monospacedDigit()
					)
					.foregroundStyle(shown ? .white : .secondary)
			}
			.frame(width: chip.rect.width, height: chip.rect.height)
			.scaleEffect(hovered ? 1.15 : 1)
			.offset(x: chip.rect.minX, y: chip.rect.minY)
			.animation(reduceMotion ? nil : Theme.Motion.fade, value: hovered)
			.accessibilityHidden(true)
	}

	/// The display the board pictures when nothing is dragged: the switcher's.
	private var currentDisplay: String? {
		NSScreen.screens.first {
			$0.visibleFrameTopLeft == board.visible
		}?.displayUUID
	}

	private var caption: String {
		guard let drag else {
			let count = board.frames.count
			return count == 1 ? "1 window tiled" : "\(count) windows tiled"
		}
		let count = drag.windowIDs.count
		var text =
			count > 1
			? (drag.target == nil
				? "\(count) windows" : "\(count) windows · \(action)")
			: action
		let displaced = drag.displaced
		if displaced > 0 { text += " · \(displaced) left untiled" }
		if drag.rotatesSlots { text += " · scroll to rotate" }
		return text
	}

	/// Where the drop goes, in words.
	private var action: String {
		switch drag?.target {
		case nil where drag?.untiles == true: "Remove from layout"
		case nil where drag?.hoveredDisplay != nil:
			displayName(drag?.hoveredDisplay) ?? "Another display"
		case nil: drag.map { name(of: $0.windowID) } ?? ""
		case .fill?: "Fill the screen"
		case .edge(.left)?: "Full height on the left"
		case .edge(.right)?: "Full height on the right"
		case .edge(.top)?: "Full width along the top"
		case .edge(.bottom)?: "Full width along the bottom"
		case .pane(let id, _)? where TilingSlot.isPlaceholder(id): "Fill this slot"
		case .pane(let id, .center)?:
			drag.map { isTiled($0.windowID) && $0.windowIDs.count == 1 } ?? false
				? "Swap with \(name(of: id))" : "Replace \(name(of: id))"
		case .pane(let id, .left)?: "Left of \(name(of: id))"
		case .pane(let id, .right)?: "Right of \(name(of: id))"
		case .pane(let id, .top)?: "Above \(name(of: id))"
		case .pane(let id, .bottom)?: "Below \(name(of: id))"
		case .preset(let preset, _)?: preset.title
		}
	}

	private func displayName(_ display: String?) -> String? {
		display.flatMap { NSScreen.screen(uuid: $0)?.localizedName }
	}

	private func name(of id: CGWindowID) -> String {
		(state.windows.first { $0.id == id } ?? state.recentOrder.first { $0.id == id })?.appName
			?? "this window"
	}

	private func isTiled(_ id: CGWindowID) -> Bool {
		board.layout?.contains(id) ?? false
	}

	private var screen: some View {
		ZStack(alignment: .topLeading) {
			RoundedRectangle(cornerRadius: Theme.Tiling.tileRadius + 2)
				.fill(.black.opacity(contrast == .increased ? 0.6 : 0.35))
				.strokeBorder(.white.opacity(contrast == .increased ? 0.5 : 0.12))
			ForEach(sorted(shownFrames), id: \.key) { id, frame in
				if let stand = standIn(for: id) {
					tile(stand, frame: frame, role: .resting)
				} else {
					tile(id, frame: frame, role: role(of: id))
				}
			}
			// Over the board: the dragged windows on top, where they'd land.
			if !showsWholePreview {
				ForEach(sorted(landingFrames), id: \.key) { id, frame in
					tile(id, frame: frame, role: incomingRole(of: id))
				}
				.transition(.opacity)
			}
			if let drag, drag.preview == nil, let target = drag.target {
				let rect = local(board.indicator(for: target))
				DropHighlight()
					.frame(width: rect.width, height: rect.height)
					.offset(x: rect.minX, y: rect.minY)
			}
		}
		.frame(width: board.rect.width, height: board.rect.height, alignment: .topLeading)
		.accessibilityElement(children: .ignore)
		.accessibilityLabel(caption)
	}

	private var showsWholePreview: Bool { drag?.showsWholePreview ?? false }

	/// Over a preset chip, the layout the drop would make; otherwise the current one.
	private var shownFrames: [CGWindowID: CGRect] {
		showsWholePreview ? board.frames(of: drag?.preview) : board.allFrames
	}

	/// Where each dragged window would land.
	private var landingFrames: [CGWindowID: CGRect] {
		guard let drag, drag.preview != nil else { return [:] }
		let dragged = Set(drag.windowIDs)
		return board.frames(of: drag.preview).filter { dragged.contains($0.key) }
	}

	/// Over the board, a dragged window's old place shows the window that moves into it
	/// (dropping a tiled window on another's middle swaps them).
	private func standIn(for id: CGWindowID) -> CGWindowID? {
		guard let drag, !drag.showsWholePreview, drag.windowIDs.contains(id), drag.preview != nil,
			let old = board.allFrames[id]
		else { return nil }
		let dragged = Set(drag.windowIDs)
		return board.frames(of: drag.preview).first { other, frame in
			!dragged.contains(other) && !TilingSlot.isPlaceholder(other)
				&& abs(frame.minX - old.minX) < 2 && abs(frame.minY - old.minY) < 2
				&& abs(frame.width - old.width) < 2 && abs(frame.height - old.height) < 2
		}?.key
	}

	private func role(of id: CGWindowID) -> BoardTileRole {
		guard let drag, drag.windowIDs.contains(id) else { return .resting }
		return drag.showsWholePreview ? incomingRole(of: id) : .lifted
	}

	private func incomingRole(of id: CGWindowID) -> BoardTileRole {
		let ids = drag?.windowIDs ?? []
		let index = ids.firstIndex(of: id) ?? 0
		return .incoming(number: ids.count > 1 ? index + 1 : nil)
	}

	/// Frames in a stable order, so tiles keep their stacking from one move to the next.
	private func sorted(_ frames: [CGWindowID: CGRect]) -> [(key: CGWindowID, value: CGRect)] {
		frames.sorted { $0.key < $1.key }
	}

	private func tile(_ id: CGWindowID, frame: CGRect, role: BoardTileRole) -> some View {
		let rect = local(board.toBoard(frame))
		return Group {
			if TilingSlot.isPlaceholder(id) {
				EmptySlot()
			} else {
				BoardTile(
					window: state.windows.first { $0.id == id }
						?? state.recentOrder.first { $0.id == id },
					image: state.images[id], role: role, isUnfit: state.unfitIDs.contains(id))
			}
		}
		.frame(width: rect.width, height: rect.height)
		.offset(x: rect.minX, y: rect.minY)
	}

	/// The slots a drop on `preset` fills: the hovered one for one window; for several,
	/// the ones they'll take (mark order, left to right, rotated by scrolling).
	private func litSlots(of preset: TilingPreset, hovered: Int?) -> Set<Int> {
		guard hovered != nil, let drag else { return [] }
		return Set(drag.slotAssignment.keys)
	}

	/// Each lit slot's window number, when several windows are dragged.
	private func slotNumbers(of preset: TilingPreset, hovered: Int?) -> [Int: Int] {
		guard hovered != nil, let drag, drag.windowIDs.count > 1 else { return [:] }
		return drag.slotAssignment.compactMapValues { id in
			drag.windowIDs.firstIndex(of: id).map { $0 + 1 }
		}
	}

	private func chipView(_ chip: PresetChip) -> some View {
		let slot: Int? =
			if case .preset(chip.preset, let slot)? = drag?.target { slot } else { nil }
		return VStack(spacing: 4) {
			PresetThumbnail(
				preset: chip.preset, mainShare: board.mainShare,
				highlightedSlots: litSlots(of: chip.preset, hovered: slot),
				slotNumbers: slotNumbers(of: chip.preset, hovered: slot)
			)
			.frame(width: chip.rect.width, height: chip.rect.height)
			.overlay(alignment: .topLeading) {
				// Its keyboard shortcut: the modifier and this number.
				if let index = placement.chips.firstIndex(where: { $0.id == chip.id }), index < 9 {
					Text(index + 1, format: .number)
						.font(.system(size: 10, weight: .bold).monospacedDigit())
						.foregroundStyle(.secondary)
						.padding(3)
						.accessibilityHidden(true)
				}
			}
			Text(chip.preset.title)
				.font(.caption2)
				.bold(slot != nil)
				.foregroundStyle(slot != nil ? .primary : .secondary)
				.lineLimit(1)
				.fixedSize()
				.frame(width: chip.rect.width)
		}
		.offset(x: chip.rect.minX, y: chip.rect.minY)
	}

	/// A board rectangle relative to the board's own top-left corner.
	private func local(_ rect: CGRect) -> CGRect {
		rect.offsetBy(dx: -board.rect.minX, dy: -board.rect.minY)
	}
}
