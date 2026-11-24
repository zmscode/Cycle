import AppKit

/// Cycle's icon in the menu bar (turned off in settings): its menu opens settings, applies
/// a workspace, opens `cycle.config`, and quits. Without it, settings are behind the gear
/// beside the switcher, `cycle --settings`, or opening Cycle again.
@MainActor
final class MenuBarItem: NSObject, NSMenuDelegate {
	private var item: NSStatusItem?
	private let openSettings: () -> Void
	private let applyWorkspace: (Workspace) -> Void

	init(openSettings: @escaping () -> Void, applyWorkspace: @escaping (Workspace) -> Void) {
		self.openSettings = openSettings
		self.applyWorkspace = applyWorkspace
	}

	/// Shows or removes the icon to match the setting.
	func update() {
		if Settings.showMenuBarIcon {
			guard item == nil else { return }
			let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
			item.button?.image = NSImage(
				systemSymbolName: "rectangle.on.rectangle", accessibilityDescription: "Cycle")
			item.button?.image?.isTemplate = true
			item.button?.toolTip = "Cycle"
			let menu = NSMenu()
			menu.delegate = self
			item.menu = menu
			self.item = item
		} else if let item {
			NSStatusBar.system.removeStatusItem(item)
			self.item = nil
		}
	}

	/// Built fresh each time it opens, so the workspaces are current.
	func menuNeedsUpdate(_ menu: NSMenu) {
		menu.removeAllItems()
		let settings = ClosureMenuItem("Settings…", systemImage: "gearshape") { [weak self] in
			self?.openSettings()
		}
		settings.keyEquivalent = ","
		menu.addItem(settings)

		let workspaces = Settings.tilingWorkspaces
		if !workspaces.isEmpty {
			let item = NSMenuItem(title: "Apply Workspace", action: nil, keyEquivalent: "")
			item.image = NSImage(systemSymbolName: "square.grid.2x2", accessibilityDescription: nil)
			let submenu = NSMenu()
			for workspace in workspaces {
				submenu.addItem(
					ClosureMenuItem(workspace.name) { [weak self] in
						self?.applyWorkspace(workspace)
					})
			}
			item.submenu = submenu
			menu.addItem(item)
		}
		menu.addItem(
			ClosureMenuItem("Open cycle.config", systemImage: "doc.text") {
				ConfigStore.shared.openInEditor()
			})

		menu.addItem(.separator())
		let quit = ClosureMenuItem("Quit Cycle") { NSApp.terminate(nil) }
		quit.keyEquivalent = "q"
		menu.addItem(quit)
	}
}
