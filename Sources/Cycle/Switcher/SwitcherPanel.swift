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
	/// The settings button's own little window, floating just left of the panel.
	private var gearPanel: NSPanel?

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
		gearPanel?.orderFrontRegardless()
	}

	/// The panel's frame on screen.
	var frame: CGRect? { panel?.isVisible == true ? panel?.frame : nil }

	/// The settings button's frame on screen; settings open beside it.
	var gearFrame: CGRect? { gearPanel?.isVisible == true ? gearPanel?.frame : nil }

	/// The top row's height in the current layout.
	private(set) var headerHeight: CGFloat = Theme.Panel.searchHeight

	func hide() {
		panel?.orderOut(nil)
		gearPanel?.orderOut(nil)
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
		placeGear(beside: panel.frame)
	}

	/// Puts the settings button just left of the panel, top edges aligned, creating its
	/// window on first use.
	private func placeGear(beside frame: CGRect) {
		let gear = gearPanel ?? makeGearPanel()
		gearPanel = gear
		let size = Theme.Gear.diameter
		gear.setFrame(
			CGRect(x: frame.minX - Theme.Gear.gap - size, y: frame.maxY - size, width: size, height: size),
			display: true)
	}

	private func makeGearPanel() -> NSPanel {
		let gear = NSPanel(
			contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
			backing: .buffered, defer: false)
		gear.level = .popUpMenu
		gear.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle]
		gear.isOpaque = false
		gear.backgroundColor = .clear
		gear.hasShadow = false
		gear.becomesKeyOnlyIfNeeded = true
		gear.animationBehavior = .none
		gear.contentView = NSHostingView(
			rootView: FloatingSettingsButton(state: state, onToggle: { [weak controller] in controller?.toggleSettings() }))
		return gear
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
