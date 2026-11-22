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
	/// The settings button's own little window, in the screen's top-right corner.
	private var gearPanel: NSPanel?
	/// Dims the rest of the screen behind the switcher during a session.
	private var dimPanel: NSPanel?

	init(state: SwitcherState, controller: SwitcherController) {
		self.state = state
		self.controller = controller
	}

	func show() {
		let panel = self.panel ?? makePanel()
		self.panel = panel
		showDim()
		relayout()
		panel.alphaValue = 1
		panel.orderFrontRegardless()
		gearPanel?.orderFrontRegardless()
	}

	/// The panel's frame on screen.
	var frame: CGRect? { panel?.isVisible == true ? panel?.frame : nil }

	/// The settings button's frame on screen; settings open beside it.
	var gearFrame: CGRect? { gearPanel?.isVisible == true ? gearPanel?.frame : nil }

	/// The layout last drawn, so arrow keys move through what's on screen.
	private var metrics: SwitcherLayout?

	/// Windows by visual row for arrow-key movement. Before the panel has been drawn (a
	/// quick tap) it measures the layout it would draw.
	func navigationRows() -> [[NavigationStop]] {
		(metrics ?? measure()).navigationRows(windowCount: state.windows.count)
	}

	private func measure() -> SwitcherLayout {
		let visible = Self.screenUnderPointer().visibleFrame
		return SwitcherLayout.metrics(
			for: state.windows, style: Settings.layout,
			maxSize: CGSize(width: visible.width * 0.9, height: visible.height * 0.8),
			showsSearchBar: !state.searchQuery.isEmpty)
	}

	/// The top row's height in the current layout.
	private(set) var headerHeight: CGFloat = Theme.Panel.searchHeight

	func hide() {
		panel?.orderOut(nil)
		gearPanel?.orderOut(nil)
		hideDim()
	}

	/// A subtle shade over the switcher's screen, fading in behind the panel. It ignores
	/// the mouse, so a click anywhere still reaches the window under it (and ends the
	/// session, as before).
	private func showDim() {
		let screen = Self.screenUnderPointer()
		let dim = dimPanel ?? makeDimPanel()
		dimPanel = dim
		dim.setFrame(screen.frame, display: false)
		dim.alphaValue = 0
		dim.orderFrontRegardless()
		NSAnimationContext.runAnimationGroup { context in
			context.duration = 0.18
			dim.animator().alphaValue = 1
		}
	}

	private func hideDim() {
		guard let dim = dimPanel, dim.isVisible else { return }
		NSAnimationContext.runAnimationGroup({ context in
			context.duration = 0.12
			dim.animator().alphaValue = 0
		}) {
			MainActor.assumeIsolated {
				// A new session may have started while this faded; leave it up then.
				if dim.alphaValue == 0 { dim.orderOut(nil) }
			}
		}
	}

	private func makeDimPanel() -> NSPanel {
		let dim = NSPanel(
			contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
			backing: .buffered, defer: false)
		// Just under the switcher and its gear.
		dim.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
		dim.collectionBehavior = [
			.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle,
		]
		dim.isOpaque = false
		dim.hasShadow = false
		dim.ignoresMouseEvents = true
		dim.animationBehavior = .none
		dim.backgroundColor = NSColor.black.withAlphaComponent(Theme.Panel.dimOpacity)
		return dim
	}

	/// Re-measure for the current window list and recentre.
	func relayout() {
		guard let panel, let host else { return }
		let visible = Self.screenUnderPointer().visibleFrame
		let metrics = measure()
		self.metrics = metrics
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
		placeGear()
	}

	/// Puts the settings button in the top-right corner of the switcher's screen, creating
	/// its window on first use.
	private func placeGear() {
		let gear = gearPanel ?? makeGearPanel()
		gearPanel = gear
		let size = Theme.Gear.diameter
		let visible = Self.screenUnderPointer().visibleFrame
		let margin = Theme.Gear.margin
		gear.setFrame(
			CGRect(
				x: visible.maxX - margin - size, y: visible.maxY - margin - size, width: size,
				height: size),
			display: true)
	}

	private func makeGearPanel() -> NSPanel {
		let gear = NSPanel(
			contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel],
			backing: .buffered, defer: false)
		gear.level = .popUpMenu
		gear.collectionBehavior = [
			.canJoinAllSpaces, .fullScreenAuxiliary, .transient, .ignoresCycle,
		]
		gear.isOpaque = false
		gear.backgroundColor = .clear
		gear.hasShadow = false
		gear.becomesKeyOnlyIfNeeded = true
		gear.animationBehavior = .none
		gear.contentView = NSHostingView(
			rootView: FloatingSettingsButton(
				state: state, onToggle: { [weak controller] in controller?.toggleSettings() }))
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
