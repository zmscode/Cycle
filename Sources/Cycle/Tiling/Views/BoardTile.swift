import SwiftUI

/// A window on the board, in its place now or where the drop would put it.
struct BoardTile: View {
	let window: SwitcherWindow?
	let image: NSImage?
	let role: BoardTileRole
	/// The window is bigger than its slot (its app won't go smaller).
	var isUnfit = false

	@Environment(\.colorSchemeContrast) private var contrast

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: Theme.Tiling.tileRadius) }

	var body: some View {
		// The shape takes the tile's size; the picture fills it and is cut to it, whatever
		// the window's shape (a wide window in a narrow slot mustn't spill out).
		shape
			.fill(.white.opacity(0.08))
			.overlay(alignment: .top) {
				// Pinned to the top, like the switcher's cards: the title bar stays in view.
				if let image {
					Image(nsImage: image)
						.resizable()
						.interpolation(.medium)
						.aspectRatio(contentMode: .fill)
				} else if let icon = window?.icon {
					Image(nsImage: icon)
						.resizable()
						.aspectRatio(contentMode: .fit)
						.frame(maxWidth: 28, maxHeight: 28)
				}
			}
			.clipShape(shape)
			.overlay {
				if case .incoming = role {
					DropHighlight()
				} else if isUnfit {
					shape.strokeBorder(Theme.Colors.minimize, lineWidth: 1.5)
				} else {
					shape.strokeBorder(.white.opacity(contrast == .increased ? 0.6 : 0.18))
				}
			}
			.overlay(alignment: .bottomLeading) {
				if isUnfit, role.isResting {
					Image(systemName: "exclamationmark.triangle.fill")
						.font(.system(size: 11, weight: .bold))
						.foregroundStyle(Theme.Colors.minimize)
						.shadow(color: .black.opacity(0.5), radius: 2)
						.padding(3)
						.help("This window won't shrink to fit its slot")
				}
			}
			.overlay(alignment: .topTrailing) {
				if let number {
					BoardTileNumber(number: number).padding(3)
				}
			}
			.opacity(opacity)
			.accessibilityLabel(window?.appName ?? "Window")
			.accessibilityValue(isUnfit ? "Doesn't fit its slot" : "")
	}

	private var number: Int? {
		if case .incoming(let number) = role { number } else { nil }
	}

	private var opacity: Double {
		switch role {
		case .resting: 0.85
		case .lifted: 0.35
		case .incoming: 1
		}
	}
}
