import AppKit
import RiftCore

/// Grips in the gaps between tiled windows on the real screen: drag one to resize the
/// windows either side, double-click it to even them up. A grip sits just above the
/// frontmost tiled window, so a window in front of the layout covers it, and it hides
/// while the layout's windows aren't on screen (another Space, hidden, minimized).
extension TilingCoordinator {
	/// How wide a grip is when the gap is narrower (it then overlaps the windows a little),
	/// so it's comfortable to grab.
	private static let minimumGripThickness: CGFloat = 14

	func setUpDividers() {
		screenDividers.onBegin = { [weak self] item, pointer in
			self?.beginResize(display: item.display, splitID: item.splitID, pointer: pointer)
		}
		screenDividers.onMove = { [weak self] pointer in self?.moveResize(to: pointer) }
		screenDividers.onEnd = { [weak self] in self?.endResize() }
		screenDividers.onReset = { [weak self] item in
			self?.resetDivider(display: item.display, splitID: item.splitID)
		}
		let center = NSWorkspace.shared.notificationCenter
		for name in [
			NSWorkspace.didActivateApplicationNotification,
			NSWorkspace.activeSpaceDidChangeNotification,
			NSWorkspace.didHideApplicationNotification,
			NSWorkspace.didUnhideApplicationNotification,
		] {
			center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
				MainActor.assumeIsolated { self?.refreshDividersSoon() }
			}
		}
		NotificationCenter.default.addObserver(
			forName: NSApplication.didChangeScreenParametersNotification, object: nil,
			queue: .main
		) { [weak self] _ in
			MainActor.assumeIsolated { self?.refreshDividersSoon() }
		}
	}

	/// Redraws every grip shortly (several changes in a row redraw once).
	func refreshDividersSoon() {
		NSObject.cancelPreviousPerformRequests(withTarget: DividerRefresh.shared)
		DividerRefresh.shared.action = { [weak self] in self?.refreshDividers() }
		DividerRefresh.shared.perform(#selector(DividerRefresh.fire), with: nil, afterDelay: 0.15)
	}

	private func refreshDividers() {
		guard resize == nil else { return }
		guard Settings.tilingShowsDividers else { return screenDividers.hideAll() }
		let order = Self.onScreenOrder()
		var items: [DividerHandleItem] = []
		for display in store.remembered.keys {
			items += dividerItems(for: display, layout: store.layout(for: display), order: order)
		}
		screenDividers.show(items)
	}

	/// Moves `display`'s grips to `layout` (mid-drag).
	func showDividers(for display: String, layout: RiftLayout<CGWindowID>?) {
		guard Settings.tilingShowsDividers else { return }
		screenDividers.show(
			dividerItems(for: display, layout: layout, order: Self.onScreenOrder()),
			replacing: display)
	}

	private func dividerItems(
		for display: String, layout: RiftLayout<CGWindowID>?, order: [CGWindowID]
	) -> [DividerHandleItem] {
		guard let layout, let screen = NSScreen.screen(uuid: display) else { return [] }
		let tiled = Set(layout.paneIDs.filter { !TilingSlot.isPlaceholder($0) })
		// No tiled window on screen here: nothing to resize.
		guard let front = order.first(where: tiled.contains) else { return [] }
		let board = TilingBoard.offscreen(on: screen, layout: layout)
		let height = NSScreen.screens.first?.frame.height ?? 0
		return (board.geometry?.dividers ?? []).map { divider in
			let rect = divider.hitRect(thickness: Self.minimumGripThickness)
			return DividerHandleItem(
				display: display, splitID: divider.splitID, axis: divider.axis,
				frame: CGRect(
					x: rect.minX, y: height - rect.maxY, width: rect.width, height: rect.height),
				above: front)
		}
	}

	/// On-screen windows, front to back.
	private static func onScreenOrder() -> [CGWindowID] {
		let info =
			CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID)
			as? [[String: Any]] ?? []
		return info.compactMap { entry in
			guard (entry[kCGWindowLayer as String] as? Int) == 0 else { return nil }
			return entry[kCGWindowNumber as String] as? CGWindowID
		}
	}
}

/// A target for a delayed, cancellable call (`perform(_:afterDelay:)` needs an object).
@MainActor
final class DividerRefresh: NSObject {
	static let shared = DividerRefresh()
	var action: (() -> Void)?

	@objc func fire() {
		action?()
	}
}
