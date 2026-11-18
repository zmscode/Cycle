import AppKit
import SwiftUI

/// Borderless, non-activating floating panel on the display under the pointer. Never
/// becomes key: the keyboard reaches the session through the event tap, so the app the
/// user is leaving keeps focus until a window is chosen.
@MainActor
final class SwitcherPanel {
	private let state: SwitcherState
	private unowned let controller: SwitcherController
	private var panel: NSPanel?
	private var host: NSHostingView<SwitcherView>?

	init(state: SwitcherState, controller: SwitcherController) {
		self.state = state
		self.controller = controller
	}

	func show() {
		let panel = self.panel ?? makePanel()
		self.panel = panel
		relayout()
		panel.alphaValue = 1
		panel.orderFrontRegardless()
	}

	/// The panel's frame on screen, for placing the settings panel under its gear.
	var frame: CGRect? { panel?.isVisible == true ? panel?.frame : nil }

	/// The top row's height in the current layout.
	private(set) var headerHeight: CGFloat = Theme.Panel.searchHeight

	func hide() {
		panel?.orderOut(nil)
	}

	/// Re-measure for the current window list and recentre.
	func relayout() {
		guard let panel, let host else { return }
		let screen = Self.screenUnderPointer()
		let visible = screen.visibleFrame
		let metrics = SwitcherLayout.metrics(
			for: state.windows, style: Settings.layout,
			maxSize: CGSize(width: visible.width * 0.9, height: visible.height * 0.8),
			showsSearchBar: Settings.showSearchBar || state.isSearching)
		host.rootView = SwitcherView(state: state, controller: controller, metrics: metrics)
		headerHeight = metrics.headerHeight
		let size = metrics.fullSize
		panel.setFrame(
			CGRect(
				x: visible.midX - size.width / 2, y: visible.midY - size.height / 2,
				width: size.width, height: size.height
			).integral,
			display: true
		)
	}

	private func makePanel() -> NSPanel {
		let panel = NSPanel(
			contentRect: .zero,
			styleMask: [.borderless, .nonactivatingPanel],
			backing: .buffered, defer: false
		)
		panel.level = .popUpMenu
		panel.collectionBehavior = [
			.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle,
		]
		panel.isOpaque = false
		panel.backgroundColor = .clear
		panel.hasShadow = true
		panel.hidesOnDeactivate = false
		panel.isMovable = false
		panel.becomesKeyOnlyIfNeeded = true
		panel.animationBehavior = .none
		let host = NSHostingView(
			rootView: SwitcherView(state: state, controller: controller, metrics: .empty))
		host.sizingOptions = []
		panel.contentView = host
		self.host = host
		return panel
	}

	static func screenUnderPointer() -> NSScreen {
		let mouse = NSEvent.mouseLocation
		return NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
			?? NSScreen.screens[0]
	}
}
