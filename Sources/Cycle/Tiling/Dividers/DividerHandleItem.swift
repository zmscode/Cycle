import CoreGraphics
import Foundation
import RiftCore

/// One grip to show: the split it moves, which way, and where (AppKit screen coordinates).
struct DividerHandleItem: Equatable {
	let display: String
	let splitID: UUID
	let axis: RiftAxis
	let frame: CGRect
	/// Real-screen grips sit just above this window, the frontmost tiled one, so a window
	/// in front of the layout covers them as it covers the layout.
	var above: CGWindowID?
}
