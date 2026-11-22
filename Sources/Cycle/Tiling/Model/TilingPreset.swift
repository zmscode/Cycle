import CoreGraphics
import RiftCore

/// A ready-made arrangement, as a Rift tree of numbered slots. Dropping a window on a slot
/// lays the screen out this way: the window takes that slot, windows already tiled fill
/// the others (most important slot first), and any slot left over stays empty for a later
/// drop.
enum TilingPreset: String, CaseIterable, Identifiable {
	case halves, thirds, quarters, mainStack, centre, rows, full

	var id: String { rawValue }

	var title: String {
		switch self {
		case .halves: "Halves"
		case .thirds: "Thirds"
		case .quarters: "Quarters"
		case .mainStack: "Main + Stack"
		case .centre: "Centre"
		case .rows: "Rows"
		case .full: "Full"
		}
	}

	/// Shown when settings has never been changed.
	static let defaultEnabled: [TilingPreset] = [.halves, .thirds, .quarters, .mainStack, .full]

	/// The slot tree. `mainShare` is the main window's share of the width in Main + Stack
	/// and Centre.
	func layout(mainShare: Double) -> RiftLayout<Int> {
		let main = min(max(mainShare, 0.3), 0.8)
		switch self {
		case .full:
			return .pane(0)
		case .halves:
			return Self.split(.horizontal, 0.5, .pane(0), .pane(1))
		case .rows:
			return Self.split(.vertical, 0.5, .pane(0), .pane(1))
		case .thirds:
			return Self.split(
				.horizontal, 1.0 / 3, .pane(0), Self.split(.horizontal, 0.5, .pane(1), .pane(2)))
		case .quarters:
			return Self.split(
				.vertical, 0.5,
				Self.split(.horizontal, 0.5, .pane(0), .pane(1)),
				Self.split(.horizontal, 0.5, .pane(2), .pane(3)))
		case .mainStack:
			return Self.split(
				.horizontal, main, .pane(0), Self.split(.vertical, 0.5, .pane(1), .pane(2)))
		case .centre:
			let side = (1 - main) / 2
			return Self.split(
				.horizontal, side, .pane(0),
				Self.split(.horizontal, main / (main + side), .pane(1), .pane(2)))
		}
	}

	/// Slots in the order existing windows fill them: the main one first.
	func slotOrder(mainShare: Double) -> [Int] {
		self == .centre ? [1, 0, 2] : layout(mainShare: mainShare).paneIDs
	}

	private static func split(
		_ axis: RiftAxis, _ position: Double, _ first: RiftLayout<Int>, _ second: RiftLayout<Int>
	) -> RiftLayout<Int> {
		.split(RiftSplit(axis: axis, position: position, first: first, second: second))
	}
}
