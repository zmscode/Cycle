import AppKit

/// `Cycle --demo`: opens the switcher over made-up windows on a plain gradient backdrop, so
/// screenshots show the UI without anyone's real windows. Used for the README images.
@MainActor
enum Demo {
	private struct Mock {
		let app: String
		let path: String
		let title: String
		let accent: NSColor
		let dark: Bool
	}

	private static let mocks: [Mock] = [
		Mock(app: "Safari", path: "/Applications/Safari.app", title: "Start Page",
			 accent: NSColor(srgbRed: 0.20, green: 0.52, blue: 1.0, alpha: 1), dark: false),
		Mock(app: "Notes", path: "/System/Applications/Notes.app", title: "Weekend Plans",
			 accent: NSColor(srgbRed: 0.98, green: 0.78, blue: 0.20, alpha: 1), dark: false),
		Mock(app: "Music", path: "/System/Applications/Music.app", title: "Listen Now",
			 accent: NSColor(srgbRed: 0.98, green: 0.24, blue: 0.36, alpha: 1), dark: true),
		Mock(app: "Mail", path: "/System/Applications/Mail.app", title: "Inbox",
			 accent: NSColor(srgbRed: 0.18, green: 0.62, blue: 0.98, alpha: 1), dark: false),
		Mock(app: "Calendar", path: "/System/Applications/Calendar.app", title: "November",
			 accent: NSColor(srgbRed: 0.96, green: 0.30, blue: 0.25, alpha: 1), dark: true),
		Mock(app: "Maps", path: "/System/Applications/Maps.app", title: "Guides",
			 accent: NSColor(srgbRed: 0.24, green: 0.74, blue: 0.42, alpha: 1), dark: false),
	]

	private static var backdrop: NSWindow?

	static func run(controller: SwitcherController) {
		showBackdrop()
		var windows: [SwitcherWindow] = []
		var images: [CGWindowID: NSImage] = [:]
		var tints: [CGWindowID: NSColor] = [:]
		for (i, mock) in mocks.enumerated() {
			let id = CGWindowID(900_000 + i)
			var window = SwitcherWindow(
				id: id, pid: -1, appName: mock.app, bundleID: nil, title: mock.title,
				bounds: CGRect(x: 0, y: 0, width: 1440, height: 900), axElement: nil,
				isMinimized: false, isAppHidden: false, isOnOtherSpace: false, isWindowless: false)
			window.iconOverride = NSWorkspace.shared.icon(forFile: mock.path)
			windows.append(window)
			images[id] = mockWindow(mock)
			tints[id] = mock.accent.blended(withFraction: 0.35, of: .black)
		}
		controller.showDemo(windows, images: images, tints: tints)
	}

	/// A soft wallpaper behind the panel, covering the screen it opens on.
	private static func showBackdrop() {
		let screen = SwitcherPanel.screenUnderPointer()
		let window = NSWindow(contentRect: screen.frame, styleMask: .borderless, backing: .buffered, defer: false)
		window.level = NSWindow.Level(rawValue: NSWindow.Level.popUpMenu.rawValue - 1)
		window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
		window.ignoresMouseEvents = true
		let view = NSView(frame: screen.frame)
		view.wantsLayer = true
		let gradient = CAGradientLayer()
		gradient.frame = view.bounds
		gradient.colors = [
			NSColor(srgbRed: 0.98, green: 0.62, blue: 0.48, alpha: 1).cgColor,
			NSColor(srgbRed: 0.62, green: 0.38, blue: 0.86, alpha: 1).cgColor,
			NSColor(srgbRed: 0.16, green: 0.30, blue: 0.78, alpha: 1).cgColor,
		]
		gradient.startPoint = CGPoint(x: 0, y: 1)
		gradient.endPoint = CGPoint(x: 1, y: 0)
		view.layer = gradient
		window.contentView = view
		window.orderFrontRegardless()
		backdrop = window
	}

	/// Draws a simple window: toolbar, sidebar, and content blocks in the app's accent.
	private static func mockWindow(_ mock: Mock) -> NSImage {
		let size = NSSize(width: 1440, height: 900)
		return NSImage(size: size, flipped: true) { rect in
			let bg = mock.dark ? NSColor(white: 0.12, alpha: 1) : NSColor(white: 0.98, alpha: 1)
			let panel = mock.dark ? NSColor(white: 0.18, alpha: 1) : NSColor(white: 0.93, alpha: 1)
			let line = mock.dark ? NSColor(white: 0.30, alpha: 1) : NSColor(white: 0.82, alpha: 1)
			bg.setFill(); rect.fill()

			// Toolbar with traffic lights.
			panel.setFill(); NSRect(x: 0, y: 0, width: size.width, height: 104).fill()
			for (i, c) in [NSColor.systemRed, .systemYellow, .systemGreen].enumerated() {
				c.setFill()
				NSBezierPath(ovalIn: NSRect(x: 36 + CGFloat(i) * 40, y: 38, width: 26, height: 26)).fill()
			}
			line.setFill()
			NSBezierPath(roundedRect: NSRect(x: 520, y: 30, width: 400, height: 44), xRadius: 22, yRadius: 22).fill()

			// Sidebar.
			panel.setFill(); NSRect(x: 0, y: 104, width: 300, height: size.height - 104).fill()
			for i in 0..<7 {
				(i == 1 ? mock.accent : line).setFill()
				NSBezierPath(roundedRect: NSRect(x: 30, y: 150 + CGFloat(i) * 70, width: i == 1 ? 240 : 200 - CGFloat(i % 3) * 30, height: 36),
							 xRadius: 12, yRadius: 12).fill()
			}

			// Content.
			mock.accent.setFill()
			NSBezierPath(roundedRect: NSRect(x: 350, y: 150, width: 1040, height: 300), xRadius: 28, yRadius: 28).fill()
			NSColor.white.withAlphaComponent(0.85).setFill()
			NSBezierPath(roundedRect: NSRect(x: 400, y: 200, width: 420, height: 50), xRadius: 25, yRadius: 25).fill()
			NSColor.white.withAlphaComponent(0.5).setFill()
			NSBezierPath(roundedRect: NSRect(x: 400, y: 280, width: 600, height: 32), xRadius: 16, yRadius: 16).fill()
			for col in 0..<3 {
				line.setFill()
				NSBezierPath(roundedRect: NSRect(x: 350 + CGFloat(col) * 355, y: 500, width: 330, height: 340), xRadius: 24, yRadius: 24).fill()
				mock.accent.withAlphaComponent(0.55).setFill()
				NSBezierPath(roundedRect: NSRect(x: 380 + CGFloat(col) * 355, y: 530, width: 160, height: 26), xRadius: 13, yRadius: 13).fill()
			}
			return true
		}
	}
}
