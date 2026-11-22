import AppKit

/// The little borderless window a grip lives in. It never takes focus, so dragging a
/// divider leaves the app in front as it was.
final class DividerHandlePanel: NSPanel {
	let handle = DividerHandleView()

	init(style: DividerHandleStyle) {
		super.init(
			contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
			defer: false)
		handle.style = style
		isOpaque = false
		backgroundColor = .clear
		hasShadow = false
		hidesOnDeactivate = false
		isReleasedWhenClosed = false
		animationBehavior = .none
		collectionBehavior = [.transient, .ignoresCycle, .fullScreenAuxiliary]
		switch style {
		case .screen:
			// Same level as app windows, so it can sit just above the tiled ones.
			level = .normal
		case .board:
			// Over the tiling board, which is above the switcher.
			level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 2)
		}
		contentView = handle
	}

	override var canBecomeKey: Bool { false }
	override var canBecomeMain: Bool { false }
}
