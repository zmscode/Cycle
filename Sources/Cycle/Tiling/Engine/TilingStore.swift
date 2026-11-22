import CoreGraphics
import Foundation
import RiftCore

/// Each display's tiling layout. What's remembered is a Rift tree of `RememberedSlot`s
/// (windows by app and title, and empty preset slots), keyed by display UUID; windows open
/// now are bound to the remembered ones they are. The live layout of window ids is worked
/// out from the two:
///
/// - A window that's been moved or resized since Cycle placed it is forgotten.
/// - A window that closes is forgotten; its neighbours take the space, or with gap filling
///   off it leaves an empty slot.
/// - A window whose app quits stays remembered but unbound ("away"); its neighbours take
///   the space meanwhile (an empty slot with gap filling off), and it's bound again when a
///   matching window turns up.
@MainActor
final class TilingStore {
	private(set) var remembered: [String: RiftLayout<RememberedSlot>]
	/// Called whenever `remembered` changes, to save it.
	var onChange: (() -> Void)?

	private var bindings: [RememberedWindow: CGWindowID] = [:]
	private var identities: [CGWindowID: RememberedWindow] = [:]
	private var pids: [CGWindowID: pid_t] = [:]
	/// Where each tiled window actually ended up (apps can round or clamp a frame).
	private var placed: [CGWindowID: CGRect] = [:]
	/// When each restored window was bound: closing again straight away means it wasn't
	/// really the remembered window (a launch panel, a splash screen).
	private var restoredAt: [CGWindowID: Date] = [:]

	init(remembered: [String: RiftLayout<RememberedSlot>]) {
		self.remembered = remembered
	}

	/// Windows tiled right now.
	var tiledWindowIDs: Set<CGWindowID> { Set(identities.keys) }

	/// Whether any remembered window is waiting for its app to come back.
	var hasAwayWindows: Bool {
		remembered.values.contains { tree in
			tree.paneIDs.contains { slot in
				if case .window(let window) = slot { bindings[window] == nil } else { false }
			}
		}
	}

	/// The app a tiled window belongs to.
	func pid(of id: CGWindowID) -> pid_t? { pids[id] }

	func isAway(bundleID: String) -> Bool {
		remembered.values.contains { tree in
			tree.paneIDs.contains { slot in
				guard case .window(let window) = slot else { return false }
				return window.bundleID == bundleID && bindings[window] == nil
			}
		}
	}

	// MARK: Reading

	/// `display`'s live layout. Windows in `windows` that have moved since Cycle placed them
	/// are forgotten first (windows not in the list are left alone: they may only be
	/// filtered out of a session).
	func layout(for display: String, windows: [SwitcherWindow] = [])
		-> RiftLayout<CGWindowID>?
	{
		forgetMoved(windows)
		return live(display)
	}

	/// The live layout: remembered windows mapped to the windows bound to them.
	private func live(_ display: String) -> RiftLayout<CGWindowID>? {
		guard var tree = remembered[display] else { return nil }
		// Away windows: gone from the layout, or empty slots holding their place.
		for slot in tree.paneIDs {
			guard case .window(let window) = slot, bindings[window] == nil else { continue }
			if Settings.tilingFillsGaps {
				guard let rest = tree.removingProportionally(slot) else { return nil }
				tree = rest
			} else {
				let empty = RememberedSlot.empty(slot: Self.freeSlot(in: tree))
				tree = tree.replacing(.pane(slot)) { _ in .pane(empty) } ?? tree
			}
		}
		return tree.mapPanes { slot in
			switch slot {
			case .window(let window): bindings[window] ?? TilingSlot.placeholder(0)
			case .empty(let number): TilingSlot.placeholder(number)
			}
		}
	}

	// MARK: Changing

	/// Remembers `layout` for `display`, as dropped. Its windows leave every other display's
	/// layout, and windows away from this display are let go (the new arrangement wins).
	func save(
		_ layout: RiftLayout<CGWindowID>, for display: String, windows: [SwitcherWindow]
	) {
		let byID = Dictionary(windows.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
		let ids = Set(layout.paneIDs.filter { !TilingSlot.isPlaceholder($0) })
		for id in ids where identities[id] == nil {
			guard let window = byID[id] else { continue }
			bind(RememberedWindow(window), to: id, pid: window.pid)
		}
		// Off the other displays.
		for (other, tree) in remembered where other != display {
			var rest: RiftLayout<RememberedSlot>? = tree
			for slot in tree.paneIDs {
				guard case .window(let window) = slot, let id = bindings[window], ids.contains(id)
				else { continue }
				rest = rest?.removingProportionally(slot)
			}
			remembered[other] = rest
		}
		// Windows that were here and aren't any more.
		for slot in remembered[display]?.paneIDs ?? [] {
			guard case .window(let window) = slot else { continue }
			if let id = bindings[window], !ids.contains(id) { unbind(id) }
		}
		remembered[display] = layout.mapPanes { id in
			if TilingSlot.isPlaceholder(id) { return .empty(slot: Int(CGWindowID.max - id)) }
			return identities[id].map(RememberedSlot.window)
				?? .window(RememberedWindow(windowID: id, bundleID: "", title: ""))
		}
		onChange?()
	}

	func recordPlacement(_ id: CGWindowID, frame: CGRect) {
		placed[id] = frame
	}

	/// A tiled window closed. Returns its display, whose layout changed.
	func windowClosed(_ id: CGWindowID) -> String? {
		guard let identity = identities[id] else { return nil }
		// Restored moments ago: it wasn't the remembered window after all, which stays away.
		if let bound = restoredAt[id], Date().timeIntervalSince(bound) < Self.restoreGrace {
			unbind(id)
			return displays(holding: [identity]).first
		}
		unbind(id)
		for (display, tree) in remembered where tree.contains(.window(identity)) {
			let slot = RememberedSlot.window(identity)
			if Settings.tilingFillsGaps {
				remembered[display] = tree.removingProportionally(slot)
			} else {
				let empty = RememberedSlot.empty(slot: Self.freeSlot(in: tree))
				remembered[display] = tree.replacing(.pane(slot)) { _ in .pane(empty) } ?? tree
			}
			onChange?()
			return display
		}
		return nil
	}

	/// An app quit: its windows are away until it's back. Returns the displays whose live
	/// layouts changed.
	func appQuit(_ pid: pid_t) -> Set<String> {
		let gone = pids.filter { $0.value == pid }.map(\.key)
		guard !gone.isEmpty else { return [] }
		let identitiesGone = Set(gone.compactMap { identities[$0] })
		gone.forEach(unbind)
		return displays(holding: identitiesGone)
	}

	/// Binds away windows to open windows that match them: the same window id (Cycle
	/// restarted), else the same app and title, else the same app. Returns the displays
	/// whose live layouts changed.
	func bind(_ windows: [SwitcherWindow]) -> Set<String> {
		var candidates = windows.filter {
			// Minimized and hidden windows wait until they're shown: placing them would show
			// them. Dialogs and panels are never what was tiled.
			identities[$0.id] == nil && $0.bundleID != nil && WindowTiler.canTile($0)
				&& !$0.isMinimized && !$0.isAppHidden && !$0.isDialog
		}
		guard !candidates.isEmpty else { return [] }
		let away = remembered.values.flatMap(\.paneIDs).compactMap { slot -> RememberedWindow? in
			guard case .window(let window) = slot, bindings[window] == nil else { return nil }
			return window
		}
		guard !away.isEmpty else { return [] }
		let rules: [(RememberedWindow, SwitcherWindow) -> Bool] = [
			{ $0.windowID == $1.id && $0.bundleID == $1.bundleID },
			{ $0.bundleID == $1.bundleID && $0.title == $1.title },
			// Same app only for windows with a title of their own: an untitled window, or one
			// named just for the app, is usually a launch panel or splash screen.
			{ $0.bundleID == $1.bundleID && !$1.title.isEmpty && $1.title != $1.appName },
		]
		var found: Set<RememberedWindow> = []
		for rule in rules {
			for identity in away where bindings[identity] == nil {
				guard let index = candidates.firstIndex(where: { rule(identity, $0) }) else {
					continue
				}
				let window = candidates.remove(at: index)
				bind(identity, to: window.id, pid: window.pid)
				restoredAt[window.id] = Date()
				found.insert(identity)
			}
		}
		return displays(holding: found)
	}

	/// Forgets every away window (layout restoring was turned off).
	func forgetAway() {
		for (display, tree) in remembered {
			var rest: RiftLayout<RememberedSlot>? = tree
			for slot in tree.paneIDs {
				guard case .window(let window) = slot, bindings[window] == nil else { continue }
				rest = rest?.removingProportionally(slot)
			}
			remembered[display] = rest
		}
		onChange?()
	}

	// MARK: Helpers

	/// Forgets windows in `windows` that aren't where Cycle put them.
	private func forgetMoved(_ windows: [SwitcherWindow]) {
		var changed = false
		for window in windows {
			guard let identity = identities[window.id] else { continue }
			if let then = placed[window.id], Self.matches(window.bounds, then) { continue }
			unbind(window.id)
			for (display, tree) in remembered where tree.contains(.window(identity)) {
				remembered[display] = tree.removingProportionally(.window(identity))
			}
			changed = true
		}
		if changed { onChange?() }
	}

	private func bind(_ identity: RememberedWindow, to id: CGWindowID, pid: pid_t) {
		bindings[identity] = id
		identities[id] = identity
		pids[id] = pid
	}

	private func unbind(_ id: CGWindowID) {
		if let identity = identities.removeValue(forKey: id) { bindings[identity] = nil }
		pids[id] = nil
		placed[id] = nil
		restoredAt[id] = nil
	}

	private func displays(holding windows: Set<RememberedWindow>) -> Set<String> {
		Set(
			remembered.filter { _, tree in
				tree.paneIDs.contains { slot in
					if case .window(let window) = slot { windows.contains(window) } else { false }
				}
			}.keys)
	}

	/// An empty-slot number not used in `tree` (placeholder ids have room for 64).
	private static func freeSlot(in tree: RiftLayout<RememberedSlot>) -> Int {
		let used = Set(
			tree.paneIDs.compactMap { slot -> Int? in
				if case .empty(let number) = slot { number } else { nil }
			})
		return (0..<64).first { !used.contains($0) } ?? 63
	}

	/// How long a restored window has to stay open to count as the remembered one.
	private static let restoreGrace: TimeInterval = 10

	private static func matches(_ a: CGRect, _ b: CGRect) -> Bool {
		let tolerance = Theme.Tiling.movedTolerance
		return abs(a.minX - b.minX) <= tolerance && abs(a.minY - b.minY) <= tolerance
			&& abs(a.width - b.width) <= tolerance && abs(a.height - b.height) <= tolerance
	}
}
