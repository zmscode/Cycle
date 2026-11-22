import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
	private let controller = SwitcherController()

	func applicationDidFinishLaunching(_ notification: Notification) {
		controller.start()
		// A window, not just the system prompts: the Screen Recording prompt only ever
		// appears once, and both are easy to dismiss.
		if !Permissions.shared.allGranted || CommandLine.arguments.contains("--setup") {
			PermissionsWindow.shared.show()
		}
		// `--workspace <name>` with no Cycle running before: apply it once windows are known.
		let arguments = CommandLine.arguments
		if let index = arguments.firstIndex(of: "--workspace"), arguments.indices.contains(index + 1)
		{
			DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
				self?.controller.applyWorkspace(named: arguments[index + 1])
			}
		}
		// `--settings` opens the settings panel at launch (for checking its layout).
		if CommandLine.arguments.contains("--settings") {
			DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
				self?.controller.settingsPanel.showStandalone()
			}
		}
	}

	/// There's no menu-bar item: opening Cycle again (Finder, Spotlight, the Dock) shows
	/// its settings. They're also behind the gear in the switcher.
	func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool)
		-> Bool
	{
		controller.settingsPanel.showStandalone()
		return false
	}

}
