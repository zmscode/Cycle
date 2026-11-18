import AppKit
import ApplicationServices

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
	private let controller = SwitcherController()
	private var statusItem: NSStatusItem?

	func applicationDidFinishLaunching(_ notification: Notification) {
		controller.start()
		// A window, not just the system prompts: the Screen Recording prompt only ever
		// appears once, and both are easy to dismiss.
		if !Permissions.shared.allGranted || CommandLine.arguments.contains("--setup") {
			PermissionsWindow.shared.show()
		}

		let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
		item.button?.image = Self.menuBarImage()
		let menu = NSMenu()
		menu.delegate = self
		item.menu = menu
		statusItem = item
	}

	// Rebuilt each time it opens so the checkmarks and permission rows are current.
	func menuNeedsUpdate(_ menu: NSMenu) {
		menu.removeAllItems()

		let header = NSMenuItem(
			title: "Switch windows with \(Settings.modifier.symbol)Tab", action: nil,
			keyEquivalent: "")
		header.isEnabled = false
		menu.addItem(header)
		menu.addItem(.separator())

		let shortcut = NSMenuItem(title: "Shortcut", action: nil, keyEquivalent: "")
		let shortcutMenu = NSMenu()
		for modifier in InitializerModifier.allCases {
			let item = NSMenuItem(
				title: "\(modifier.symbol)Tab", action: #selector(setModifier(_:)),
				keyEquivalent: "")
			item.representedObject = modifier.rawValue
			item.state = Settings.modifier == modifier ? .on : .off
			item.target = self
			shortcutMenu.addItem(item)
		}
		shortcut.submenu = shortcutMenu
		menu.addItem(shortcut)

		menu.addItem(
			toggle(
				"Keep Open Until Return", Settings.activationMode == .onConfirmation,
				#selector(toggleActivationMode)))
		menu.addItem(
			toggle("Current Space Only", Settings.currentSpaceOnly, #selector(toggleCurrentSpace)))
		menu.addItem(
			toggle(
				"Include Minimized and Hidden", Settings.includeHiddenWindows,
				#selector(toggleHidden)))
		menu.addItem(
			toggle(
				"Show Apps Without Windows", Settings.showWindowlessApps,
				#selector(toggleWindowless)))

		menu.addItem(.separator())
		let ax = AXIsProcessTrusted()
		let sc = CGPreflightScreenCaptureAccess()
		menu.addItem(permissionItem("Accessibility", granted: ax))
		menu.addItem(permissionItem("Screen Recording", granted: sc))
		let setup = NSMenuItem(title: "Permissions…", action: #selector(showPermissions), keyEquivalent: "")
		setup.target = self
		menu.addItem(setup)
		if ax, !controller.tapIsRunning {
			let warn = NSMenuItem(
				title: "Keyboard tap not running — relaunch Cycle", action: nil, keyEquivalent: "")
			warn.isEnabled = false
			menu.addItem(warn)
		}

		menu.addItem(.separator())
		menu.addItem(
			NSMenuItem(
				title: "Quit Cycle", action: #selector(NSApplication.terminate(_:)),
				keyEquivalent: "q"))
	}

	private func toggle(_ title: String, _ on: Bool, _ action: Selector) -> NSMenuItem {
		let item = NSMenuItem(title: title, action: action, keyEquivalent: "")
		item.state = on ? .on : .off
		item.target = self
		return item
	}

	private func permissionItem(_ name: String, granted: Bool) -> NSMenuItem {
		let item = NSMenuItem(
			title: granted ? "\(name): Allowed" : "\(name): Not Allowed",
			action: granted ? nil : #selector(showPermissions), keyEquivalent: "")
		item.image = NSImage(
			systemSymbolName: granted ? "checkmark.circle.fill" : "exclamationmark.triangle.fill",
			accessibilityDescription: nil)
		item.target = self
		item.isEnabled = !granted
		return item
	}

	/// The template glyph from Support/MenuBarIcon.svg; an SF Symbol when running outside
	/// the bundle.
	private static func menuBarImage() -> NSImage? {
		if let url = Bundle.main.url(forResource: "MenuBarIcon", withExtension: "svg"),
			let image = NSImage(contentsOf: url)
		{
			image.size = NSSize(width: 18, height: 18)
			image.isTemplate = true
			image.accessibilityDescription = "Cycle"
			return image
		}
		return NSImage(systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Cycle")
	}

	@objc private func showPermissions() { PermissionsWindow.shared.show() }

	@objc private func setModifier(_ sender: NSMenuItem) {
		if let raw = sender.representedObject as? String, let m = InitializerModifier(rawValue: raw)
		{
			Settings.modifier = m
		}
	}

	@objc private func toggleActivationMode() {
		Settings.activationMode =
			Settings.activationMode == .onKeyRelease ? .onConfirmation : .onKeyRelease
	}

	@objc private func toggleCurrentSpace() { Settings.currentSpaceOnly.toggle() }
	@objc private func toggleHidden() { Settings.includeHiddenWindows.toggle() }
	@objc private func toggleWindowless() { Settings.showWindowlessApps.toggle() }

}
