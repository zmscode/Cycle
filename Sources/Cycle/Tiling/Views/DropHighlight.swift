import SwiftUI

/// Where the dragged window will go, drawn like Rift's drop indicator: a translucent
/// accent fill with a solid outline.
struct DropHighlight: View {
	var body: some View {
		let shape = RoundedRectangle(cornerRadius: Theme.Tiling.tileRadius)
		shape
			.fill(Theme.Colors.selection.opacity(0.28))
			.strokeBorder(Theme.Colors.selection, lineWidth: 2)
			.allowsHitTesting(false)
	}
}
