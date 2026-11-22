import SwiftUI

/// A half-width Control Center toggle: a round icon (white when on), title and state.
/// The whole tile toggles; the icon bounces and the trackpad ticks when it does.
struct ToggleTile: View {
	let title: LocalizedStringKey
	let subtitle: LocalizedStringKey
	let systemImage: String
	@Binding var isOn: Bool
	@State private var isHovering = false

	var body: some View {
		Button(action: flip) {
			HStack(spacing: 10) {
				RoundIcon(isOn: isOn) {
					Image(systemName: systemImage)
						.font(.body.bold())
						.symbolEffect(.bounce, value: isOn)
				}
				VStack(alignment: .leading, spacing: 0) {
					Text(title).font(.callout.bold())
					Text(subtitle).font(.caption).foregroundStyle(.secondary)
				}
				.lineLimit(1)
				.minimumScaleFactor(0.85)
				Spacer(minLength: 0)
			}
			.padding(ControlTileMetrics.tilePadding - 2)
			.frame(maxWidth: .infinity, alignment: .leading)
			.insetSurface(cornerRadius: ControlTileMetrics.tileRadius, isHighlighted: isHovering)
			.contentShape(RoundedRectangle(cornerRadius: ControlTileMetrics.tileRadius))
		}
		.buttonStyle(.plain)
		.onHover { isHovering = $0 }
		.sensoryFeedback(.selection, trigger: isOn)
		.accessibilityValue(isOn ? "On" : "Off")
		.accessibilityAddTraits(.isToggle)
	}

	private func flip() {
		isOn.toggle()
	}
}
