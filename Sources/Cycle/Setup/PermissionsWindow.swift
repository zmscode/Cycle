import AppKit
import SwiftUI

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
				contentRect: NSRect(x: 0, y: 0, width: 460, height: 560),
				styleMask: [.titled, .closable, .fullSizeContentView],
				backing: .buffered, defer: false)
			window.titlebarAppearsTransparent = true
			window.titleVisibility = .hidden
			window.isMovableByWindowBackground = true
			window.isReleasedWhenClosed = false
			window.contentView = NSHostingView(
				rootView: PermissionsView(permissions: .shared, owner: self))
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
		if Permissions.shared.step == nil, CommandLine.arguments.contains("--setup"),
			openedStep == nil
		{
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
