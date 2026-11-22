import Foundation
import RiftCore

/// Keeps the remembered layouts in `layouts.json`, beside `cycle.config`, so they outlive
/// Cycle and restarts.
@MainActor
final class LayoutMemory {
	private let url = ConfigStore.shared.directory.appending(path: "layouts.json")
	private var saveWork: DispatchWorkItem?

	func load() -> [String: RiftLayout<RememberedSlot>] {
		guard let data = try? Data(contentsOf: url),
			let file = try? JSONDecoder().decode(LayoutFile.self, from: data)
		else { return [:] }
		return file.displays
	}

	/// Writes `layouts` shortly (several changes in a row write once).
	func save(_ layouts: [String: RiftLayout<RememberedSlot>]) {
		saveWork?.cancel()
		let work = DispatchWorkItem { [url] in
			let encoder = JSONEncoder()
			encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
			guard let data = try? encoder.encode(LayoutFile(displays: layouts)) else { return }
			try? FileManager.default.createDirectory(
				at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
			try? data.write(to: url, options: .atomic)
		}
		saveWork = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
	}
}
