import CoreGraphics

/// Sizes shared by the settings panel's tiles.
enum ControlTileMetrics {
	static let panelWidth: CGFloat = 296
	static let spacing: CGFloat = 8
	/// Inset of the tiles from the sheet's edge; with `tileRadius` this keeps the corners
	/// concentric with the sheet.
	static let sheetPadding: CGFloat = 10
	static let tileRadius: CGFloat = 20  // Theme.Panel.radius - sheetPadding
	static let tilePadding: CGFloat = 10
	static let circle: CGFloat = 32
	static let layoutCircle: CGFloat = 40
}
