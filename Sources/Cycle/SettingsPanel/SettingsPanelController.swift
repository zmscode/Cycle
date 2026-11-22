import AppKit
import SwiftUI

/// Cycle's settings, as a floating sheet of glass tiles. During a switcher session it
/// opens under the switcher's gear and edits apply to the open switcher at once; when
/// Cycle is reopened from Finder or Spotlight it opens by itself in the middle of the
/// screen. There's no menu-bar item.
@MainActor
final class SettingsPanelController {
	let settings = MenuSettings()
	private let tapIsRunning: () -> Bool
	private var panel: NSPanel?
	/// Set for the standalone panel, which closes on a click elsewhere or Escape. In a
	/// session the switcher handles both.
	private var clickMonitor: Any?
	private var keyMonitor: Any?

	var isVisible: Bool { panel?.isVisible == true }

	/// The panel's size at its content's natural height.
	var size: CGSize { preparedPanel().frame.size }

	init(tapIsRunning: @escaping () -> Bool) {
		self.tapIsRunning = tapIsRunning
	}

	/// Opens with its top-left corner at `topLeft` (screen coordinates), beside the switcher.
	func show(topLeft: CGPoint) {
		let panel = preparedPanel()
		panel.setFrameTopLeftPoint(topLeft)
		fadeIn(panel)
	}

	/// Opens by itself, centred on the screen under the pointer.
	func showStandalone() {
		let panel = preparedPanel()
		let visible = SwitcherPanel.screenUnderPointer().visibleFrame
		panel.setFrameOrigin(
			CGPoint(
				x: visible.midX - panel.frame.width / 2,
				y: visible.midY - panel.frame.height / 2))
		NSApp.activate()
		fadeIn(panel)
		panel.makeKey()
		clickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [
			.leftMouseDown, .rightMouseDown,
		]) {
			[weak self] _ in
			MainActor.assumeIsolated { self?.close() }
		}
		keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
			guard event.keyCode == 53 else { return event }
			MainActor.assumeIsolated { self?.close() }
			return nil
		}
	}

	func close() {
		if let clickMonitor { NSEvent.removeMonitor(clickMonitor) }
		if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
		clickMonitor = nil
		keyMonitor = nil
		guard let panel, panel.isVisible else { return }
		NSAnimationContext.runAnimationGroup({
			$0.duration = 0.1
			panel.animator().alphaValue = 0
		}) {
			panel.orderOut(nil)
		}
	}

	private func preparedPanel() -> NSPanel {
		Permissions.shared.refresh()
		let panel = self.panel ?? makePanel()
		self.panel = panel
		if let host = panel.contentView { panel.setContentSize(host.fittingSize) }
		return panel
	}

	private func fadeIn(_ panel: NSPanel) {
		panel.alphaValue = 0
		panel.orderFrontRegardless()
		NSAnimationContext.runAnimationGroup {
			$0.duration = 0.12
			panel.animator().alphaValue = 1
		}
	}

	private func makePanel() -> NSPanel {
		let panel = KeyablePanel(
			contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
			backing: .buffered, defer: false)
		// Above the switcher panel, which sits at pop-up menu level.
		panel.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
		panel.isOpaque = false
		panel.backgroundColor = .clear
		// The glass draws its own edge; a window shadow would show square corners.
		panel.hasShadow = false
		panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
		let view = SettingsPanelView(
			settings: settings,
			permissions: .shared,
			tapIsRunning: tapIsRunning,
			onSetup: { [weak self] in self?.showSetup() },
			onOpenConfig: { ConfigStore.shared.openInEditor() },
			onQuit: { NSApp.terminate(nil) })
		let host = NSHostingView(rootView: view)
		host.sizingOptions = [.intrinsicContentSize]
		panel.contentView = host
		panel.setContentSize(host.fittingSize)
		return panel
	}

	private func showSetup() {
		close()
		PermissionsWindow.shared.show()
	}
}
