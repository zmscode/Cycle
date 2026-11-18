import SwiftUI

/// A round control face: filled with the selection blue and a white glyph when on (the
/// same blue as the switcher's selection ring), a faint disc when off. The glyph morphs
/// between symbols.
struct RoundIcon<Glyph: View>: View {
	let isOn: Bool
	var diameter: CGFloat = ControlTileMetrics.circle
	@ContentBuilder let glyph: Glyph

	var body: some View {
		glyph
			.foregroundStyle(isOn ? .white : .primary)
			.contentTransition(.symbolEffect(.replace))
			.frame(width: diameter, height: diameter)
			.background(
				isOn ? AnyShapeStyle(Theme.Colors.selection) : AnyShapeStyle(.white.opacity(0.1)),
				in: .circle)
			.overlay {
				Circle().strokeBorder(.white.opacity(isOn ? 0.3 : 0.12), lineWidth: 0.5)
			}
			.shadow(color: Theme.Colors.selection.opacity(isOn ? 0.45 : 0), radius: 5, y: 1)
			.animation(.smooth(duration: 0.18), value: isOn)
	}
}
