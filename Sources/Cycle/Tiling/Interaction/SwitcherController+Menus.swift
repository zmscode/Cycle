import AppKit

/// The tiling context menu, on a card's or a board tile's right-click. It offers what
/// dragging does, so none of it needs a drag: mark for tiling, tile with a preset, move
/// to another display, take out of the layout, undo. Cards add the window actions.
extension SwitcherController {
	/// Shows the menu for `id` at the right-click `event`, in `view`. The session stays
	/// open while the menu is up, even if the modifier is let go.
	func showMenu(for id: CGWindowID, onBoard: Bool, event: NSEvent, in view: NSView) {
		guard isActive, state.drag == nil, let menu = menu(for: id, onBoard: onBoard) else {
			return
		}
		isShowingMenu = true
		NSMenu.popUpContextMenu(menu, with: event, for: view)
		isShowingMenu = false
		releaseIfModifierUp()
	}

	private func menu(for id: CGWindowID, onBoard: Bool) -> NSMenu? {
		guard let window = state.recentOrder.first(where: { $0.id == id }) else { return nil }
		let menu = NSMenu()
		menu.autoenablesItems = false
		let tileable = WindowTiler.canTile(window)
		let tiled = tiling.store.display(of: id) != nil

		// Tiling.
		if tileable, !onBoard {
			let marked = state.markedIDs.contains(id)
			menu.addItem(
				ClosureMenuItem(
					marked ? "Unmark" : "Mark for Tiling",
					systemImage: marked ? "checkmark.circle.fill" : "checkmark.circle"
				) { [weak self] in self?.toggleMark(id) })
		}
		if tileable { menu.addItem(tileWithItem(for: id)) }
		if tileable, let moveItem = moveToDisplayItem(for: id) { menu.addItem(moveItem) }
		if tiled {
			menu.addItem(
				ClosureMenuItem("Remove from Layout", systemImage: "rectangle.badge.minus") {
					[weak self] in self?.untile(id)
				})
		}
		if let undo = tiling.undoLabel {
			menu.addItem(
				ClosureMenuItem("Undo \(undo)", systemImage: "arrow.uturn.backward") {
					[weak self] in self?.undoTiling()
				})
		}

		// The window itself; destructive actions last.
		if !menu.items.isEmpty { menu.addItem(.separator()) }
		if !onBoard, !window.isWindowless {
			menu.addItem(
				ClosureMenuItem(
					window.isMinimized ? "Unminimize" : "Minimize", systemImage: "minus.rectangle"
				) { [weak self] in self?.perform(.minimize, on: id) })
		}
		if !window.isWindowless {
			menu.addItem(
				ClosureMenuItem("Close Window", systemImage: "xmark.rectangle") { [weak self] in
					if onBoard {
						WindowActions.close(window)
					} else {
						self?.perform(.close, on: id)
					}
				})
		}
		if !onBoard {
			menu.addItem(
				ClosureMenuItem("Quit \(window.appName)", systemImage: "power") { [weak self] in
					self?.perform(.quit, on: id)
				})
		}
		return menu.items.isEmpty ? nil : menu
	}

	/// "Tile With ▸", one item per preset on the board: the window (or every marked
	/// window, when it's marked) laid out with that preset.
	private func tileWithItem(for id: CGWindowID) -> NSMenuItem {
		let item = NSMenuItem(title: "Tile With", action: nil, keyEquivalent: "")
		item.image = NSImage(systemSymbolName: "rectangle.split.3x1", accessibilityDescription: nil)
		let submenu = NSMenu()
		for preset in Settings.tilingPresets {
			submenu.addItem(
				ClosureMenuItem(preset.title) { [weak self] in self?.tile(id, with: preset) })
		}
		item.submenu = submenu
		item.isEnabled = !submenu.items.isEmpty
		return item
	}

	/// "Move to Display ▸", one item per other display, with two or more displays.
	private func moveToDisplayItem(for id: CGWindowID) -> NSMenuItem? {
		let current = tiling.store.display(of: id)
			?? state.recentOrder.first { $0.id == id }.flatMap { window in
				NSScreen.screens.first { $0.frame.intersects(Self.appKitFrame(window.bounds)) }
			}?.displayUUID
		let others = NSScreen.screens.filter { $0.displayUUID != nil && $0.displayUUID != current }
		guard NSScreen.screens.count > 1, !others.isEmpty else { return nil }
		let item = NSMenuItem(title: "Move to Display", action: nil, keyEquivalent: "")
		item.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: nil)
		let submenu = NSMenu()
		for screen in others {
			submenu.addItem(
				ClosureMenuItem(screen.localizedName) { [weak self] in
					self?.move(id, to: screen)
				})
		}
		item.submenu = submenu
		return item
	}

	/// Tiles `id` (with the other marked windows, if it's marked) using `preset`.
	func tile(_ id: CGWindowID, with preset: TilingPreset) {
		let ids =
			state.markedIDs.contains(id) ? state.markedIDs.filter(canTile) : [id]
		tile(ids, with: preset)
	}

	/// Moves `id` into `screen`'s layout: filling the screen if nothing's tiled there,
	/// else in a full-height slot on the right.
	func move(_ id: CGWindowID, to screen: NSScreen) {
		let board = TilingBoard.offscreen(
			on: screen, layout: tiling.layout(for: screen, windows: state.recentOrder))
		let others = (board.layout?.paneIDs ?? []).filter {
			$0 != id && !TilingSlot.isPlaceholder($0)
		}
		guard let layout = board.dropping([id], on: others.isEmpty ? .fill : .edge(.right))
		else { return }
		tiling.apply(
			layout, on: board, screen: screen, windows: state.recentOrder,
			label: "Move to \(screen.localizedName)")
		showNotice("Moved \(name(of: id)) to \(screen.localizedName)")
	}

	/// A window-server frame (top-left origin) in AppKit screen coordinates.
	private static func appKitFrame(_ frame: CGRect) -> CGRect {
		let height = NSScreen.screens.first?.frame.height ?? 0
		return CGRect(
			x: frame.minX, y: height - frame.maxY, width: frame.width, height: frame.height)
	}
}
