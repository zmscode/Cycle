import AppKit
import ApplicationServices
import SwiftUI

/// Live state of the two grants Cycle needs, polled while anything is missing.
/// (DockDoor keeps the same pair in `SystemPermissions` / `PermissionState`.)
@Observable
@MainActor
final class Permissions {
	static let shared = Permissions()

	private(set) var accessibility = AXIsProcessTrusted()
	private(set) var screenRecording = CGPreflightScreenCaptureAccess()
	/// Screen Recording was granted while Cycle was running; captures only start
	/// working after a relaunch.
	private(set) var needsRelaunch = false

	var allGranted: Bool { accessibility && screenRecording }

	/// The setup steps, in order. Accessibility comes first: without it there is no ⌘Tab.
	enum Step: Equatable {
		case accessibility, screenRecording

		var pane: String {
			switch self {
			case .accessibility: "Privacy_Accessibility"
			case .screenRecording: "Privacy_ScreenCapture"
			}
		}
	}

	/// The first permission still missing.
	var step: Step? {
		if !accessibility { return .accessibility }
		if !screenRecording { return .screenRecording }
		return nil
	}

	/// Called after a refresh that changed a grant.
	var onChange: (() -> Void)?

	private var timer: Timer?
	private let launchedWithScreenRecording = CGPreflightScreenCaptureAccess()

	func startPolling() {
		guard timer == nil else { return }
		timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
			MainActor.assumeIsolated { self?.refresh() }
		}
	}

	func refresh() {
		let before = (accessibility, screenRecording)
		accessibility = AXIsProcessTrusted()
		screenRecording = CGPreflightScreenCaptureAccess()
		needsRelaunch = screenRecording && !launchedWithScreenRecording
		if before != (accessibility, screenRecording) { onChange?() }
		if allGranted && !needsRelaunch {
			timer?.invalidate()
			timer = nil
		}
	}

	func requestAccessibility() {
		let prompt = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
		if !AXIsProcessTrustedWithOptions([prompt: true] as CFDictionary) {
			openSettings("Privacy_Accessibility")
		}
		startPolling()
	}

	func requestScreenRecording() {
		// The system prompt appears only the first time; after that the user has to switch it
		// on in Settings, so open the pane as well.
		if !CGRequestScreenCaptureAccess() {
			openSettings("Privacy_ScreenCapture")
		}
		startPolling()
	}

	func openSettings(_ pane: String) {
		if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)")
		{
			NSWorkspace.shared.open(url)
		}
	}

	/// Starts a fresh copy once this one has exited, then quits.
	func relaunch() {
		let path = Bundle.main.bundlePath
		let task = Process()
		task.executableURL = URL(fileURLWithPath: "/bin/sh")
		task.arguments = ["-c", "sleep 0.5; /usr/bin/open -n \"$0\"", path]
		try? task.run()
		NSApp.terminate(nil)
	}
}
