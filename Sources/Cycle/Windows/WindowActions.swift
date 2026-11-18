import AppKit
import ApplicationServices

/// Focus / close / minimize / quit, the way DockDoor's switcher does them: SkyLight to
/// bring the process (and its Space) forward with the right key window, then AXRaise.
enum WindowActions {
	static func focus(_ window: SwitcherWindow) {
		guard let app = window.app else { return }
		if window.isWindowless {
			app.unhide()
			app.activate()
			return
		}
		if app.isHidden { app.unhide() }
		if window.isMinimized, let ax = window.axElement {
			AXUIElementSetAttributeValue(ax, kAXMinimizedAttribute as CFString, kCFBooleanFalse)
		}
		if !SkyLight.setFrontProcess(pid: window.pid, windowID: window.id) {
			app.activate()
		}
		if let ax = window.axElement {
			// A hung app shouldn't hold the focus queue for AX's default six seconds.
			AXUIElementSetMessagingTimeout(ax, 0.25)
			AXUIElementPerformAction(ax, kAXRaiseAction as CFString)
			AXUIElementSetAttributeValue(ax, kAXMainAttribute as CFString, kCFBooleanTrue)
		}
	}

	static func close(_ window: SwitcherWindow) {
		guard let ax = window.axElement,
			let button: AXUIElement = ax.attribute(kAXCloseButtonAttribute)
		else { return }
		AXUIElementPerformAction(button, kAXPressAction as CFString)
	}

	static func toggleMinimize(_ window: SwitcherWindow) {
		guard let ax = window.axElement else { return }
		AXUIElementSetAttributeValue(
			ax, kAXMinimizedAttribute as CFString,
			window.isMinimized ? kCFBooleanFalse : kCFBooleanTrue)
	}

	static func toggleFullScreen(_ window: SwitcherWindow) {
		guard let ax = window.axElement else { return }
		let isFull: Bool = ax.attribute("AXFullScreen") ?? false
		AXUIElementSetAttributeValue(
			ax, "AXFullScreen" as CFString, isFull ? kCFBooleanFalse : kCFBooleanTrue)
	}

	static func quit(_ window: SwitcherWindow) {
		window.app?.terminate()
	}

	static func toggleHidden(_ window: SwitcherWindow) {
		guard let app = window.app else { return }
		if app.isHidden { app.unhide() } else { app.hide() }
	}
}
