import AppKit

// `Cycle --dump` prints what a session would show, then exits (no tap, no panel).
if CommandLine.arguments.contains("--dump") {
	MainActor.assumeIsolated { Diagnostics.dump() }
	exit(0)
}

// `Cycle --demo` shows the switcher over made-up windows (for screenshots) until quit.
if CommandLine.arguments.contains("--demo") {
	MainActor.assumeIsolated {
		let app = NSApplication.shared
		app.setActivationPolicy(.accessory)
		let controller = SwitcherController()
		DispatchQueue.main.async { Demo.run(controller: controller) }
		withExtendedLifetime(controller) { app.run() }
	}
}

// `Cycle --preview` shows the panel for a few seconds without the keyboard tap.
if CommandLine.arguments.contains("--preview") {
	MainActor.assumeIsolated {
		let app = NSApplication.shared
		app.setActivationPolicy(.accessory)
		let controller = SwitcherController()
		DispatchQueue.main.async { controller.preview(seconds: 4) }
		DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { exit(0) }
		withExtendedLifetime(controller) { app.run() }
	}
}

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
