import AppKit

/// Reads and writes `cycle.config` (in `$XDG_CONFIG_HOME/cycle`, else `~/.config/cycle`).
/// Changes made in the app are written back shortly after; edits made to the file by hand
/// are picked up while Cycle runs. On first run the file is created from the settings
/// Cycle used to keep in UserDefaults.
final class ConfigStore: @unchecked Sendable {
	static let shared = ConfigStore()

	/// The folder holding `cycle.config` and Cycle's other files (remembered layouts).
	let directory: URL
	let url: URL
	/// Called on main after the file was changed by something other than Cycle.
	var onExternalChange: (@MainActor () -> Void)?

	private let lock = NSLock()
	private var current: CycleConfig
	/// The bytes last read or written, so Cycle's own writes aren't taken for edits.
	private var lastData: Data?
	private var saveWork: DispatchWorkItem?
	private var directorySource: DispatchSourceFileSystemObject?
	private var fileSource: DispatchSourceFileSystemObject?

	var config: CycleConfig {
		lock.withLock { current }
	}

	private init() {
		let base =
			ProcessInfo.processInfo.environment["XDG_CONFIG_HOME"].map {
				URL(fileURLWithPath: $0, isDirectory: true)
			}
			?? FileManager.default.homeDirectoryForCurrentUser.appending(path: ".config")
		directory = base.appending(path: "cycle", directoryHint: .isDirectory)
		url = directory.appending(path: "cycle.config")
		if let data = try? Data(contentsOf: url) {
			current = Self.decode(data) ?? CycleConfig()
			lastData = data
		} else {
			current = LegacyDefaults.config()
			writeNow()
		}
	}

	/// Changes the config and saves it shortly (a slider being dragged writes once).
	func update(_ change: (inout CycleConfig) -> Void) {
		let changed: Bool = lock.withLock {
			var next = current
			change(&next)
			guard next != current else { return false }
			current = next
			return true
		}
		guard changed else { return }
		DispatchQueue.main.async { [self] in scheduleSave() }
	}

	/// Starts watching the file for edits made outside Cycle. Call once, on main.
	func watch() {
		guard directorySource == nil else { return }
		directorySource = source(for: directory) { [weak self] in self?.reload() }
		watchFile()
	}

	/// Opens the file in the app registered for it, else TextEdit (".config" usually has
	/// no owner).
	@MainActor
	func openInEditor() {
		// Anything waiting to be saved goes in first.
		if let saveWork, !saveWork.isCancelled {
			saveWork.cancel()
			writeNow()
		}
		let workspace = NSWorkspace.shared
		if workspace.urlForApplication(toOpen: url) != nil {
			workspace.open(url)
		} else if let editor = workspace.urlForApplication(
			withBundleIdentifier: "dev.zed.Zed")
		{
			workspace.open(
				[url], withApplicationAt: editor, configuration: NSWorkspace.OpenConfiguration())
		}
	}

	// MARK: Saving

	private func scheduleSave() {
		saveWork?.cancel()
		let work = DispatchWorkItem { [weak self] in self?.writeNow() }
		saveWork = work
		DispatchQueue.main.asyncAfter(deadline: .now() + 0.3, execute: work)
	}

	private func writeNow() {
		saveWork = nil
		let encoder = JSONEncoder()
		encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
		guard let data = try? encoder.encode(config) else { return }
		lock.withLock { lastData = data }
		do {
			try FileManager.default.createDirectory(
				at: directory, withIntermediateDirectories: true)
			try data.write(to: url, options: .atomic)
		} catch {
			FileHandle.standardError.write(
				Data("Cycle: couldn't save \(url.path): \(error)\n".utf8))
		}
		// An atomic write replaces the file, so the old one's watcher is stale.
		watchFile()
	}

	// MARK: Watching

	private func watchFile() {
		guard directorySource != nil else { return }
		fileSource?.cancel()
		fileSource = source(for: url) { [weak self] in self?.reload() }
	}

	private func reload() {
		guard let data = try? Data(contentsOf: url) else { return }
		let isNew: Bool = lock.withLock {
			guard data != lastData else { return false }
			lastData = data
			return true
		}
		watchFile()
		guard isNew else { return }
		guard let config = Self.decode(data) else {
			FileHandle.standardError.write(
				Data("Cycle: \(url.path) isn't valid JSON; keeping the current settings\n".utf8))
			return
		}
		let changed: Bool = lock.withLock {
			guard config != current else { return false }
			current = config
			return true
		}
		if changed { MainActor.assumeIsolated { onExternalChange?() } }
	}

	private func source(for url: URL, onChange: @escaping () -> Void)
		-> DispatchSourceFileSystemObject?
	{
		let descriptor = open(url.path, O_EVTONLY)
		guard descriptor >= 0 else { return nil }
		let source = DispatchSource.makeFileSystemObjectSource(
			fileDescriptor: descriptor, eventMask: [.write, .rename, .delete, .extend],
			queue: .main)
		source.setEventHandler(handler: onChange)
		source.setCancelHandler { close(descriptor) }
		source.resume()
		return source
	}

	private static func decode(_ data: Data) -> CycleConfig? {
		try? JSONDecoder().decode(CycleConfig.self, from: data)
	}
}
