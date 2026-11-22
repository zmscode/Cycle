import CoreGraphics
import RiftCore

/// Each screen's tiling layout, kept for the life of the app so later sessions can add to
/// it. A window counts as tiled only while it stays where Cycle put it: one that's been
/// closed, moved or resized since drops out of the layout the next time it's read.
@MainActor
final class TilingStore {
	private var layouts: [CGDirectDisplayID: RiftLayout<CGWindowID>] = [:]
	/// Where each tiled window actually ended up (apps can round or clamp a frame).
	private var placed: [CGWindowID: CGRect] = [:]

	/// `display`'s layout, without windows that are gone or have moved (empty preset slots
	/// stay).
	func layout(for display: CGDirectDisplayID, windows: [SwitcherWindow])
		-> RiftLayout<CGWindowID>?
	{
		guard var layout = layouts[display] else { return nil }
		let bounds = Dictionary(
			windows.map { ($0.id, $0.bounds) }, uniquingKeysWith: { first, _ in first })
		for id in layout.paneIDs where !TilingSlot.isPlaceholder(id) {
			if let now = bounds[id], let then = placed[id], Self.matches(now, then) { continue }
			placed[id] = nil
			guard let rest = layout.removing(.pane(id))?.remaining else {
				layouts[display] = nil
				return nil
			}
			layout = rest
		}
		layouts[display] = layout
		return layout
	}

	/// Saves `layout` for `display`, taking its windows out of every other screen's layout.
	func save(_ layout: RiftLayout<CGWindowID>, for display: CGDirectDisplayID) {
		let ids = Set(layout.paneIDs)
		for (other, otherLayout) in layouts where other != display {
			var rest: RiftLayout<CGWindowID>? = otherLayout
			for id in otherLayout.paneIDs where ids.contains(id) {
				rest = rest?.removing(.pane(id))?.remaining
			}
			layouts[other] = rest
		}
		if let previous = layouts[display] {
			for id in previous.paneIDs where !ids.contains(id) { placed[id] = nil }
		}
		layouts[display] = layout
	}

	func recordPlacement(_ id: CGWindowID, frame: CGRect) {
		placed[id] = frame
	}

	private static func matches(_ a: CGRect, _ b: CGRect) -> Bool {
		let tolerance = Theme.Tiling.movedTolerance
		return abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
			&& abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
	}
}
