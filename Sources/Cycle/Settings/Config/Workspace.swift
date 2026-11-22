import Foundation
import RiftCore

/// A named set of windows and where they go, across every display: the remembered layouts
/// as they were when it was saved, keyed by display UUID. Applying it lays those displays
/// out again, opening apps that aren't running and tiling their windows as they appear.
struct Workspace: Codable, Equatable, Identifiable {
	var id: String
	var name: String
	var displays: [String: RiftLayout<RememberedSlot>]

	init(name: String, displays: [String: RiftLayout<RememberedSlot>]) {
		id = "workspace-" + UUID().uuidString.lowercased()
		self.name = name
		self.displays = displays
	}

	/// Every window it lays out.
	var windows: [RememberedWindow] {
		displays.values.flatMap(\.paneIDs).compactMap { slot in
			if case .window(let window) = slot { window } else { nil }
		}
	}

	/// The apps it needs, by bundle id.
	var bundleIDs: Set<String> {
		Set(windows.map(\.bundleID).filter { !$0.isEmpty })
	}
}
