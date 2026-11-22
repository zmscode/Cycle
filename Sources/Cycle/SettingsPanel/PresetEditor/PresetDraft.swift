import CoreGraphics
import Foundation
import RiftCore

/// A preset being made or changed in the editor. Slots keep their numbers while editing,
/// so they animate as the layout changes; saving numbers them afresh in reading order.
struct PresetDraft: Equatable {
	static let maximumSlots = 8
	/// How far a divider may go towards either side.
	static let positionRange = 0.15...0.85

	var id: String
	var name: String
	var layout: RiftLayout<Int>
	/// Not saved yet (no Delete).
	let isNew: Bool

	/// A new preset, starting as `layout`.
	init(startingWith layout: RiftLayout<Int>, name: String) {
		id = CustomPreset.newID()
		self.name = name
		self.layout = layout
		isNew = true
	}

	init(editing preset: CustomPreset) {
		id = preset.id
		name = preset.name
		layout = preset.layout
		isNew = false
	}

	var slotCount: Int { layout.paneIDs.count }
	var canSplit: Bool { slotCount < Self.maximumSlots }
	var canRemove: Bool { slotCount > 1 }

	/// Splits `slot` in two along `axis` (side by side for horizontal).
	mutating func split(_ slot: Int, along axis: RiftAxis) {
		guard canSplit else { return }
		let new = (layout.paneIDs.max() ?? 0) + 1
		layout = layout.splitting(slot, with: new, edge: axis == .horizontal ? .right : .bottom) ?? layout
	}

	mutating func remove(_ slot: Int) {
		guard canRemove, let rest = layout.removingProportionally(slot) else { return }
		layout = rest
	}

	mutating func setPosition(_ position: Double, ofSplit id: UUID) {
		let clamped = min(max(position, Self.positionRange.lowerBound), Self.positionRange.upperBound)
		layout = layout.settingPosition(clamped, ofSplit: id) ?? layout
	}

	/// Starts again from `layout` (a built-in, or the screen's own).
	mutating func start(from layout: RiftLayout<Int>) {
		self.layout = layout
	}

	/// The preset to save: slots numbered from 0, top to bottom and left to right.
	var saved: CustomPreset {
		let frames = layout.geometry(
			in: CGRect(x: 0, y: 0, width: 1600, height: 1000),
			metrics: RiftMetrics(dividerThickness: 0, minimumPaneSize: .zero)
		).paneFrames
		let order = frames.sorted { a, b in
			abs(a.value.minY - b.value.minY) > 1
				? a.value.minY < b.value.minY : a.value.minX < b.value.minX
		}.map(\.key)
		let number = Dictionary(uniqueKeysWithValues: order.enumerated().map { ($1, $0) })
		let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
		return CustomPreset(
			id: id, name: trimmed.isEmpty ? "Custom" : trimmed,
			layout: layout.mapPanes { number[$0] ?? $0 })
	}
}
