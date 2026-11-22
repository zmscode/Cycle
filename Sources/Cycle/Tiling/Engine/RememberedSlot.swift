/// A pane in a remembered layout: a window, or a preset slot nothing's been dropped in.
enum RememberedSlot: Codable, Hashable, Sendable {
	case window(RememberedWindow)
	case empty(slot: Int)
}
