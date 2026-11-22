import SwiftUI

/// A labelled slider with its value on the right, for the tiling settings.
struct TilingSlider: View {
	let title: String
	@Binding var value: Double
	let range: ClosedRange<Double>
	let step: Double
	let format: (Double) -> String

	var body: some View {
		VStack(alignment: .leading, spacing: 2) {
			HStack {
				Text(title).font(.caption)
				Spacer()
				Text(format(value))
					.font(.caption.monospacedDigit())
					.foregroundStyle(.secondary)
			}
			Slider(value: $value, in: range, step: step)
				.controlSize(.small)
				.tint(Theme.Colors.selection)
				.accessibilityLabel(title)
				.accessibilityValue(format(value))
		}
	}
}
