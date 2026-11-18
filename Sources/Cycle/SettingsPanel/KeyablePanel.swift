import AppKit

/// A borderless panel that can still become key, so the Escape monitor and controls work.
final class KeyablePanel: NSPanel {
	override var canBecomeKey: Bool { true }
}
