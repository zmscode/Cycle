import AppKit
import RiftCore

/// A set of divider grips, one window each, kept in step with a list of items: grips are
/// reused by split, moved, and closed when their split goes.
@MainActor
final class DividerHandles {
	var onBegin: ((DividerHandleItem, CGPoint) -> Void)?
	var onMove: ((CGPoint) -> Void)?
	var onEnd: (() -> Void)?
	var onReset: ((DividerHandleItem) -> Void)?

	private let style: DividerHandleStyle
	private var panels: [UUID: DividerHandlePanel] = [:]
	private var items: [UUID: DividerHandleItem] = [:]

	init(style: DividerHandleStyle) {
		self.style = style
	}

	/// Shows exactly `newItems` (for `display`, or every display when nil), hiding the rest.
	func show(_ newItems: [DividerHandleItem], replacing display: String? = nil) {
		let keep = Set(newItems.map(\.splitID))
		for (id, item) in items
		where !keep.contains(id) && (display == nil || item.display == display) {
			panels[id]?.orderOut(nil)
			panels[id] = nil
			items[id] = nil
		}
		for item in newItems {
			let panel = panels[item.splitID] ?? makePanel()
			panels[item.splitID] = panel
			items[item.splitID] = item
			panel.handle.axis = item.axis
			panel.setFrame(item.frame.integral, display: true)
			if let above = item.above {
				panel.order(.above, relativeTo: Int(above))
			} else {
				panel.orderFrontRegardless()
			}
		}
	}

	func hideAll() {
		show([])
	}

	private func makePanel() -> DividerHandlePanel {
		let panel = DividerHandlePanel(style: style)
		let handle = panel.handle
		handle.onBegin = { [weak self, weak panel] pointer in
			guard let self, let panel, let item = self.item(for: panel) else { return }
			self.onBegin?(item, pointer)
		}
		handle.onMove = { [weak self] pointer in self?.onMove?(pointer) }
		handle.onEnd = { [weak self] in self?.onEnd?() }
		handle.onReset = { [weak self, weak panel] in
			guard let self, let panel, let item = self.item(for: panel) else { return }
			self.onReset?(item)
		}
		return panel
	}

	private func item(for panel: DividerHandlePanel) -> DividerHandleItem? {
		panels.first { $0.value === panel }.flatMap { items[$0.key] }
	}
}
