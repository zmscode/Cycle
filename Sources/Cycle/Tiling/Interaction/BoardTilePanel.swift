import AppKit

/// The window holding the board's hit layer, just over the board picture. It never takes
/// focus, so the switcher keeps the keyboard.
final class BoardTilePanel: NSPanel {
	let tiles = BoardTileView()

	init() {
		super.init(
			contentRect: .zero, styleMask: [.borderless, .nonactivatingPanel], backing: .buffered,
			defer: false)
		isOpaque = false
		backgroundColor = .clear
		hasShadow = false
		hidesOnDeactivate = false
		isReleasedWhenClosed = false
		animationBehavior = .none
		collectionBehavior = [.canJoinAllSpaces, .transient, .ignoresCycle, .fullScreenAuxiliary]
		// The board's level; the board's divider grips sit one above.
		level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue + 1)
		contentView = tiles
	}

	override var canBecomeKey: Bool { false }
	override var canBecomeMain: Bool { false }
}
