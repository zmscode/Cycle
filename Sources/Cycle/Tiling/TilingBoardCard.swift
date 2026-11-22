import SwiftUI

/// The board on its glass card: a small copy of the screen with the windows already tiled
/// on it (and any empty preset slots), a highlight where the dragged window will go, and
/// the presets in a row underneath.
struct TilingBoardCard: View {
	let drag: WindowDrag
	let state: SwitcherState

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	private var board: TilingBoard { drag.board }
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
				.offset(
					x: placement.screen.minX,
					y: placement.card.minY + Theme.Tiling.boardPadding)
			screen
				.offset(x: board.rect.minX, y: board.rect.minY)
			ForEach(placement.chips) { chip in
				chipView(chip)
			}
		}
		.animation(reduceMotion ? nil : Theme.Motion.fade, value: drag.target)
		.environment(\.colorScheme, .dark)
	}

	private var caption: String {
		let count = drag.windowIDs.count
		guard count > 1 else { return action }
		return drag.target == nil ? "Drag \(count) windows onto a preset" : "\(count) windows · \(action)"
	}

	private var action: String {
		switch drag.target {
		case nil: "Drop on the screen or a preset"
		case .fill?: "Fill the screen"
		case .edge?: "Beside every tiled window"
		case .pane(let id, _)? where TilingSlot.isPlaceholder(id): "Fill this slot"
		case .pane(_, .center)?: "Take this window's place"
		case .pane?: "Split this window"
		case .preset(let preset, _)?: preset.title
		}
	}

	private var screen: some View {
		ZStack(alignment: .topLeading) {
			RoundedRectangle(cornerRadius: Theme.Tiling.tileRadius + 2)
				.fill(.black.opacity(0.35))
				.strokeBorder(.white.opacity(0.12))
			ForEach(Array(board.allFrames), id: \.key) { id, frame in
				let rect = local(board.toBoard(frame))
				Group {
					if TilingSlot.isPlaceholder(id) {
						EmptySlot()
					} else {
						BoardTile(
							window: state.windows.first { $0.id == id }
								?? state.recentOrder.first { $0.id == id },
							image: state.images[id], isDragged: drag.windowIDs.contains(id))
					}
				}
				.frame(width: rect.width, height: rect.height)
				.offset(x: rect.minX, y: rect.minY)
			}
			if let target = drag.target {
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

	private func chipView(_ chip: PresetChip) -> some View {
		let slot: Int? =
			if case .preset(chip.preset, let slot)? = drag.target { slot } else { nil }
		return VStack(spacing: 4) {
			PresetThumbnail(
				preset: chip.preset, mainShare: board.mainShare, highlightedSlot: slot
			)
			.frame(width: chip.rect.width, height: chip.rect.height)
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
