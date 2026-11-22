import AppKit

/// A menu item that runs a closure.
final class ClosureMenuItem: NSMenuItem {
	private let handler: () -> Void

	init(_ title: String, systemImage: String? = nil, handler: @escaping () -> Void) {
		self.handler = handler
		super.init(title: title, action: #selector(run), keyEquivalent: "")
		target = self
		if let systemImage {
			image = NSImage(systemSymbolName: systemImage, accessibilityDescription: nil)
		}
	}

	@available(*, unavailable)
	required init(coder: NSCoder) {
		fatalError("init(coder:) is not used")
	}

	@objc private func run() {
		handler()
	}
}
