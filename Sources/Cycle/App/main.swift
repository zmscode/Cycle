import AppKit

// `Cycle --dump` prints what a session would show, then exits (no tap, no panel).
if CommandLine.arguments.contains("--dump") {
	MainActor.assumeIsolated { Diagnostics.dump() }
	exit(0)
}

// `--workspace <name>` and `--settings` (from the `cycle` command): with Cycle already
// running they go to it and this copy exits; otherwise this copy starts up and does them
// once it's going (see AppDelegate).
RemoteRequest.forwardIfRunning(CommandLine.arguments)

#if DEBUG
	// `Cycle --render-board <folder>` renders the tiling board for scripted drags, then exits.
	if let index = CommandLine.arguments.firstIndex(of: "--render-board"),
		CommandLine.arguments.indices.contains(index + 1)
	{
		MainActor.assumeIsolated {
			BoardRenderHarness.run(into: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
		}
		exit(0)
	}
#endif

MainActor.assumeIsolated {
	let app = NSApplication.shared
	let delegate = AppDelegate()
	app.delegate = delegate
	app.setActivationPolicy(.accessory)
	withExtendedLifetime(delegate) { app.run() }
}

@MainActor
enum Diagnostics {
	static func dump() {
		print(
			"accessibility trusted: \(AXIsProcessTrusted())  screen capture: \(CGPreflightScreenCaptureAccess())"
		)
		let mru = MRUTracker()
		mru.start()
		let start = Date()
		let windows = WindowEnumerator.snapshot(
			order: mru, includeWindowless: Settings.showWindowlessApps)
		print(
			String(
				format: "snapshot: %d windows in %.0f ms", windows.count,
				Date().timeIntervalSince(start) * 1000))
		for w in windows {
			var flags: [String] = []
			if w.isMinimized { flags.append("min") }
			if w.isAppHidden { flags.append("hidden") }
			if w.isOnOtherSpace { flags.append("other-space") }
			if w.isWindowless { flags.append("windowless") }
			if w.axElement != nil { flags.append("ax") }
			print(
				"  \(w.id)\t\(w.appName) — \(w.displayTitle.prefix(50))\t\(Int(w.bounds.width))x\(Int(w.bounds.height))\t[\(flags.joined(separator: ","))]"
			)
			if !w.isWindowless { print("      capture: \(ThumbnailCache.inspect(w.id))") }
		}
		let cache = ThumbnailCache()
		let ids = windows.filter { !$0.isWindowless }.map(\.id)
		var captured = 0
		let captureStart = Date()
		cache.capture(ids, best: false, maxAge: 0) { _, _ in captured += 1 }
		let deadline = Date().addingTimeInterval(3)
		while captured < ids.count, Date() < deadline {
			RunLoop.main.run(until: Date().addingTimeInterval(0.02))
		}
		print(
			String(
				format: "captured %d/%d thumbnails in %.0f ms", captured, ids.count,
				Date().timeIntervalSince(captureStart) * 1000))
	}
}
