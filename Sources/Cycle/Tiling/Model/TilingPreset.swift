import CoreGraphics
import RiftCore

/// A ready-made arrangement, as a Rift tree of numbered slots: one of Cycle's own, or one
/// made in the preset editor. Dropping a window on a slot lays the screen out this way:
/// the window takes that slot, windows already tiled fill the others (most important slot
/// first), and any slot left over stays empty for a later drop.
struct TilingPreset: Identifiable, Hashable {
	enum Shape: Hashable {
		case builtin(BuiltinPreset)
		case custom(RiftLayout<Int>)
	}

	/// The name `cycle.config` lists it by: a built-in's name, or `custom-<uuid>`.
	let id: String
	let title: String
	let shape: Shape

	static func builtin(_ preset: BuiltinPreset) -> TilingPreset {
		TilingPreset(id: preset.rawValue, title: preset.title, shape: .builtin(preset))
	}

	init(id: String, title: String, shape: Shape) {
		self.id = id
		self.title = title
		self.shape = shape
	}

	init(_ custom: CustomPreset) {
		self.init(id: custom.id, title: custom.name, shape: .custom(custom.layout))
	}

	var isCustom: Bool {
		if case .custom = shape { true } else { false }
	}

	/// Shown when settings has never been changed.
	static let defaultEnabled = BuiltinPreset.defaultEnabled.map(builtin)

	/// Every preset: Cycle's own, then `customs`.
	static func all(customs: [CustomPreset]) -> [TilingPreset] {
		BuiltinPreset.allCases.map(builtin) + customs.map(TilingPreset.init)
	}

	/// The preset named `id`, among Cycle's own and `customs`.
	static func named(_ id: String, customs: [CustomPreset]) -> TilingPreset? {
		if let builtin = BuiltinPreset(rawValue: id) { return .builtin(builtin) }
		return customs.first { $0.id == id }.map(TilingPreset.init)
	}

	/// The slot tree. `mainShare` is the main window's share of the width in Main + Stack
	/// and Centre.
	func layout(mainShare: Double) -> RiftLayout<Int> {
		switch shape {
		case .builtin(let preset): preset.layout(mainShare: mainShare)
		case .custom(let layout): layout
		}
	}

	/// Slots left to right, then top to bottom: the order marked windows fill them in.
	func readingOrder(mainShare: Double) -> [Int] {
		layout(mainShare: mainShare).geometry(
			in: CGRect(x: 0, y: 0, width: 1600, height: 1000),
			metrics: RiftMetrics(dividerThickness: 0, minimumPaneSize: .zero)
		).paneFrames.sorted { a, b in
			abs(a.value.minY - b.value.minY) > 1
				? a.value.minY < b.value.minY : a.value.minX < b.value.minX
		}.map(\.key)
	}

	/// Slots in the order windows fill them: the main one first. A custom preset's go
	/// largest first, then top to bottom and left to right.
	func slotOrder(mainShare: Double) -> [Int] {
		switch shape {
		case .builtin(let preset):
			return preset.slotOrder(mainShare: mainShare)
		case .custom(let layout):
			let frames = layout.geometry(
				in: CGRect(x: 0, y: 0, width: 1600, height: 1000),
				metrics: RiftMetrics(dividerThickness: 0, minimumPaneSize: .zero)
			).paneFrames
			return frames.sorted { a, b in
				let areaA = (a.value.width * a.value.height).rounded()
				let areaB = (b.value.width * b.value.height).rounded()
				if areaA != areaB { return areaA > areaB }
				if a.value.minY != b.value.minY { return a.value.minY < b.value.minY }
				return a.value.minX < b.value.minX
			}.map(\.key)
		}
	}
}
