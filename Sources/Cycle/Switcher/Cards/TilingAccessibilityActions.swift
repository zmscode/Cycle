import SwiftUI

/// VoiceOver actions on a window card for what dragging and the right-click menu do:
/// mark it, tile it with each preset on the board, take it out of its layout.
struct TilingAccessibilityActions: ViewModifier {
	let id: CGWindowID
	let controller: SwitcherController

	func body(content: Content) -> some View {
		let marked = controller.state.markedIDs.contains(id)
		content
			.accessibilityAction(named: marked ? "Unmark" : "Mark for Tiling") {
				controller.toggleMark(id)
			}
			.accessibilityActions {
				ForEach(Settings.tilingPresets) { preset in
					Button("Tile With \(preset.title)") { controller.tile(id, with: preset) }
				}
				if controller.tiling.store.display(of: id) != nil {
					Button("Remove from Layout") { controller.untile(id) }
				}
			}
	}
}

extension View {
	func tilingAccessibilityActions(_ id: CGWindowID, controller: SwitcherController) -> some View {
		modifier(TilingAccessibilityActions(id: id, controller: controller))
	}
}
