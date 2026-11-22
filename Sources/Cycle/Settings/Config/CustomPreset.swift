import Foundation
import RiftCore

/// A preset made in the editor, as `cycle.config` keeps it: a name and a Rift tree of
/// slots numbered from 0.
struct CustomPreset: Codable, Equatable, Identifiable {
	/// `custom-<uuid>`, the name the presets list uses for it.
	var id: String
	var name: String
	var layout: RiftLayout<Int>

	static func newID() -> String {
		"custom-" + UUID().uuidString.lowercased()
	}
}
