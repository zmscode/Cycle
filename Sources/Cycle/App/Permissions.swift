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
		if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") {
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

/// The setup window: one row per permission, live status, and a draggable Cycle icon to
/// drop into System Settings' list. While Settings is open the window docks beside it.
@MainActor
final class PermissionsWindow {
	static let shared = PermissionsWindow()
	private var window: NSWindow?
	private let sidecar = SettingsSidecar()
	let dropGuide = DropGuide()

	/// The step whose Settings pane was opened last, so each pane opens once per step.
	private var openedStep: Permissions.Step?

	func show() {
		Permissions.shared.onChange = { [weak self] in self?.advance() }
		Permissions.shared.refresh()
		Permissions.shared.startPolling()
		if window == nil {
			let window = NSWindow(
				contentRect: NSRect(x: 0, y: 0, width: 440, height: 530),
				styleMask: [.titled, .closable, .fullSizeContentView],
				backing: .buffered, defer: false)
			window.titlebarAppearsTransparent = true
			window.titleVisibility = .hidden
			window.isMovableByWindowBackground = true
			window.isReleasedWhenClosed = false
			window.contentView = NSHostingView(rootView: PermissionsView(permissions: .shared, owner: self))
			window.center()
			self.window = window
		}
		NSApp.activate()
		window?.makeKeyAndOrderFront(nil)
		advance()
	}

	/// Opens System Settings at the current step's list: Accessibility first, then, once
	/// Cycle is detected there, Screen Recording. Finishing undocks the window.
	func advance() {
		if Permissions.shared.step == nil, CommandLine.arguments.contains("--setup"), openedStep == nil {
			openedStep = .accessibility
			openPane(Permissions.Step.accessibility.pane)
			return
		}
		guard let step = Permissions.shared.step else {
			openedStep = nil
			sidecar.stop()
			window?.level = .normal
			if window?.isVisible == true {
				NSApp.activate()
				window?.makeKeyAndOrderFront(nil)
			}
			return
		}
		guard step != openedStep else { return }
		openedStep = step
		openPane(step.pane)
	}

	/// Opens the pane for `pane` and docks beside System Settings, floating so the window
	/// (and the icon to drag) stays visible over it.
	func openPane(_ pane: String) {
		Permissions.shared.openSettings(pane)
		guard let window else { return }
		window.level = .floating
		sidecar.follow(with: window)
	}

	func iconDrag(_ phase: DraggableAppIcon.Phase) {
		switch phase {
		case .began:
			if let settings = SystemSettingsWindow.find() { dropGuide.show(target: settings) }
		case .ended:
			dropGuide.hide()
			Permissions.shared.refresh()
		}
	}
}

struct PermissionsView: View {
	let permissions: Permissions
	let owner: PermissionsWindow

	private func rowState(_ step: Permissions.Step, granted: Bool) -> PermissionRow.State {
		if granted { return .granted }
		return permissions.step == step ? .current : .next
	}

	var body: some View {
		VStack(alignment: .leading, spacing: 18) {
			VStack(alignment: .leading, spacing: 4) {
				Text("Set up Cycle").font(.system(size: 22, weight: .bold))
				Text("Cycle needs two permissions to replace ⌘Tab with window previews.")
					.foregroundStyle(.secondary)
			}

			VStack(spacing: 10) {
				PermissionRow(
					symbol: "keyboard", title: "Accessibility",
					detail: "Catch ⌘Tab, list windows, and switch, close or minimize them.",
					state: rowState(.accessibility, granted: permissions.accessibility),
					onDrag: owner.iconDrag,
					onOpen: { owner.openPane(Permissions.Step.accessibility.pane) })
				PermissionRow(
					symbol: "rectangle.dashed.badge.record", title: "Screen Recording",
					detail: "Draw live window previews and read window titles.",
					state: rowState(.screenRecording, granted: permissions.screenRecording),
					onDrag: owner.iconDrag,
					onOpen: { owner.openPane(Permissions.Step.screenRecording.pane) })
			}
			.animation(.smooth(duration: 0.25), value: permissions.step)

			if !permissions.accessibility || !permissions.screenRecording {
				// A grant is tied to the build that was in the list when it was switched on;
				// an entry left from an older build shows as on but doesn't count.
				Label {
					Text("Cycle already on in the list but not detected? Select it, remove it with −, and drag it in again. (On macOS 27, Accessibility is listed as Device Control and Data Access.)")
						.fixedSize(horizontal: false, vertical: true)
				} icon: {
					Image(systemName: "info.circle")
				}
				.font(.footnote)
				.foregroundStyle(.secondary)
			}

			Spacer(minLength: 0)

			HStack {
				if permissions.needsRelaunch {
					Text("Relaunch Cycle so previews start working.")
						.font(.callout).foregroundStyle(.secondary)
					Spacer()
					Button("Relaunch Cycle", action: permissions.relaunch)
						.buttonStyle(.glassProminent)
				} else if permissions.allGranted {
					Label("All set. Hold ⌘ and press Tab.", systemImage: "checkmark.circle.fill")
						.foregroundStyle(.green)
					Spacer()
				}
			}
		}
		.padding(28)
		.padding(.top, 12)
		.frame(width: 440, height: 530)
		.background(.background)
	}
}

/// One permission. The current step carries the draggable Cycle icon (drop it into the
/// open System Settings list); later steps wait; granted ones show a check.
struct PermissionRow: View {
	enum State { case current, next, granted }

	let symbol: String
	let title: String
	let detail: String
	let state: State
	let onDrag: (DraggableAppIcon.Phase) -> Void
	let onOpen: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 12) {
			HStack(spacing: 14) {
				Image(systemName: symbol)
					.font(.system(size: 18, weight: .medium))
					.foregroundStyle(state == .granted ? .green : .accentColor)
					.frame(width: 40, height: 40)
					.glassEffect(.regular, in: .circle)
				VStack(alignment: .leading, spacing: 2) {
					Text(title).font(.headline)
					Text(detail).font(.callout).foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
				Spacer(minLength: 8)
				switch state {
				case .granted:
					Image(systemName: "checkmark.circle.fill")
						.font(.system(size: 22))
						.foregroundStyle(.green)
				case .next:
					Text("Next").font(.callout.weight(.medium)).foregroundStyle(.tertiary)
				case .current:
					EmptyView()
				}
			}

			if state == .current {
				HStack(spacing: 14) {
					DraggableAppIcon(appURL: Bundle.main.bundleURL, size: 52, onDrag: onDrag)
						.frame(width: 52, height: 52)
						.padding(6)
						.background {
							RoundedRectangle(cornerRadius: 16, style: .continuous)
								.strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [5, 4]))
								.foregroundStyle(Color.accentColor.opacity(0.7))
						}
					VStack(alignment: .leading, spacing: 4) {
						Text("Drag Cycle into the \(title) list in System Settings.")
							.font(.callout.weight(.medium))
							.fixedSize(horizontal: false, vertical: true)
						Button("Open System Settings", action: onOpen)
							.buttonStyle(.link)
							.font(.callout)
					}
				}
				.transition(.opacity.combined(with: .move(edge: .top)))
			}
		}
		.padding(14)
		.frame(maxWidth: .infinity, alignment: .leading)
		.opacity(state == .next ? 0.55 : 1)
		.glassEffect(
			state == .current ? .regular.tint(Color.accentColor.opacity(0.18)) : .regular,
			in: RoundedRectangle(cornerRadius: 18, style: .continuous))
	}
}
