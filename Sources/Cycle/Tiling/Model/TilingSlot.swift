import CoreGraphics

/// Empty slots live in a window layout as placeholder ids at the very top of the window id
/// range, which real windows never reach.
enum TilingSlot {
	static func placeholder(_ slot: Int) -> CGWindowID { CGWindowID.max - CGWindowID(slot) }

	static func isPlaceholder(_ id: CGWindowID) -> Bool { id > CGWindowID.max - 64 }
}
