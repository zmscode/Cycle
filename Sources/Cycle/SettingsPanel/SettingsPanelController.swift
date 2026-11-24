import AppKit
import RiftCore
import SwiftUI

/// Cycle's settings, as a floating sheet of glass tiles. During a switcher session it
/// opens under the switcher's gear and edits apply to the open switcher at once; when
/// Cycle is reopened from Finder or Spotlight it opens by itself in the middle of the
/// screen. There's no menu-bar item.
@MainActor
final class SettingsPanelController {
	let settings = MenuSettings()
	private let sizing = SettingsPanelSizing()
	private let tapIsRunning: () -> Bool
	private var panel: NSPanel?
	/// Set for the standalone panel, which closes on a click elsewhere or Escape. In a
	/// session the switcher handles both.
	private var clickMonitor: Any?
	private var keyMonitor: Any?

	var isVisible: Bool { panel?.isVisible == true }
	/// The screen's tiled layout as preset slots, for the editor's "This Screen".
	var currentLayout: () -> RiftLayout<Int>? = { nil }
	/// The current layouts as a workspace; applying one (returns displays skipped).
	var captureWorkspace: (String) -> Workspace? = { _ in nil }
	var applyWorkspace: (Workspace) -> Int = { _ in 0 }

	/// The panel's frame on screen while it's open.
	var frame: CGRect? { isVisible ? panel?.frame : nil }

	/// The panel's size at its content's natural height.
	var size: CGSize { preparedPanel().frame.size }

	/// The panel's size when it may be at most `maxHeight` tall (it scrolls past that).
	func prepare(maxHeight: CGFloat) -> CGSize {
		sizing.maxHeight = maxHeight
		return preparedPanel().frame.size
	}

	init(tapIsRunning: @escaping () -> Bool) {
		self.tapIsRunning = tapIsRunning
	}

	/// Opens with its top-left corner at `topLeft` (screen coordinates), beside the switcher.
	func show(topLeft: CGPoint) {
		// Never past the bottom of the screen: the tiles scroll instead.
		let visible = (NSScreen.screens.first { $0.frame.contains(topLeft) } ?? NSScreen.main)?
			.visibleFrame ?? .zero
		sizing.maxHeight = min(sizing.maxHeight, topLeft.y - visible.minY - Self.screenMargin)
		let panel = preparedPanel()
		panel.setFrameTopLeftPoint(topLeft)
		fadeIn(panel)
	}

	/// Opens by itself, centred on the screen under the pointer.
	func showStandalone() {
		let visible = SwitcherPanel.screenUnderPointer().visibleFrame
		sizing.maxHeight = visible.height - Self.screenMargin * 4
		#if DEBUG
			// For checking the scrolling layout on a big screen.
			if let cap = ProcessInfo.processInfo.environment["CYCLE_SETTINGS_MAX_HEIGHT"]
				.flatMap(Double.init)
			{
				sizing.maxHeight = cap
			}
		#endif
		let panel = preparedPanel()
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

	/// Space kept between the panel and the screen's edge.
	private static let screenMargin: CGFloat = 12

	private func preparedPanel() -> NSPanel {
		Permissions.shared.refresh()
		let panel = self.panel ?? makePanel()
		self.panel = panel
		if let host = panel.contentView { panel.setContentSize(host.fittingSize) }
		return panel
	}

	/// Fits the panel to its content, keeping its top edge where it is.
	private func fitToContent() {
		guard let panel, let host = panel.contentView else { return }
		let top = panel.frame.maxY
		let size = host.fittingSize
		panel.setFrame(
			CGRect(x: panel.frame.minX, y: top - size.height, width: size.width, height: size.height),
			display: true, animate: false)
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
			currentLayout: { [weak self] in self?.currentLayout() },
			captureWorkspace: { [weak self] name in self?.captureWorkspace(name) },
			applyWorkspace: { [weak self] workspace in self?.applyWorkspace(workspace) ?? 0 },
			onResize: { [weak self] in self?.fitToContent() },
			onQuit: { NSApp.terminate(nil) },
			sizing: sizing)
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
