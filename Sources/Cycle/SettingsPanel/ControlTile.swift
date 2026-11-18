import SwiftUI

/// The rounded tile every panel section sits in: a faint fill with a glass edge, a
/// little brighter while the pointer is over it.
struct ControlTile<Content: View>: View {
	@ContentBuilder var content: Content
	@State private var isHovering = false

	var body: some View {
		content
			.padding(ControlTileMetrics.tilePadding)
			.frame(maxWidth: .infinity, alignment: .leading)
			.insetSurface(cornerRadius: ControlTileMetrics.tileRadius, isHighlighted: isHovering)
			.onHover { isHovering = $0 }
	}
}
