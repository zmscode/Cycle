import AppKit
import SwiftUI

/// While the icon is being dragged: dims every screen except the System Settings window,
/// rims that window, and captions it (Rex's `DropGuide` + `SpotlightPanel`). The panels
/// ignore the mouse, so the drop lands on Settings underneath.
@MainActor
final class DropGuide {
	private var panels: [NSPanel] = []

	func show(target: SystemSettingsWindow) {
		hide()
		for screen in NSScreen.screens {
			let panel = NSPanel(
				contentRect: screen.frame, styleMask: [.borderless, .nonactivatingPanel],
				backing: .buffered, defer: false)
			panel.level = .floating
			panel.isOpaque = false
			panel.backgroundColor = .clear
			panel.hasShadow = false
			panel.ignoresMouseEvents = true
			panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
			let hole = target.frame.offsetBy(dx: -screen.frame.minX, dy: -screen.frame.minY)
			let showsCaption = screen.frame.intersects(target.frame)
			panel.contentView = NSHostingView(
				rootView: SpotlightView(
					hole: hole, size: screen.frame.size, showsCaption: showsCaption))
			panel.alphaValue = 0
			panel.orderFrontRegardless()
			NSAnimationContext.runAnimationGroup {
				$0.duration = 0.18
				panel.animator().alphaValue = 1
			}
			panels.append(panel)
		}
	}

	func hide() {
		let old = panels
		panels = []
		NSAnimationContext.runAnimationGroup({
			$0.duration = 0.18
			old.forEach { $0.animator().alphaValue = 0 }
		}) {
			old.forEach { $0.orderOut(nil) }
		}
	}
}
