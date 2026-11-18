import SwiftUI

/// The highlight behind the selected window: a soft gradient with a glass edge. Shared by
/// every layout so the selection looks the same everywhere.
struct SelectionPlate: View {
	let cornerRadius: CGFloat

	var body: some View {
		RoundedRectangle(cornerRadius: cornerRadius)
			.fill(
				LinearGradient(
					colors: [.white.opacity(0.18), .white.opacity(0.08)],
					startPoint: .top, endPoint: .bottom))
			.overlay {
				SpecularBorder(cornerRadius: cornerRadius, intensity: 0.8)
			}
	}
}
