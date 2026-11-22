import RiftCore

/// `layouts.json`: each display's remembered layout, keyed by the display's UUID.
struct LayoutFile: Codable {
	var version = 1
	var displays: [String: RiftLayout<RememberedSlot>] = [:]
}
