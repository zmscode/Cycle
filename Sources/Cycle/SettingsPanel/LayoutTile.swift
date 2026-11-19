import SwiftUI

/// The layouts as round controls with captions, three across; the current one is filled.
struct LayoutTile: View {
	@Binding var selection: SwitcherStyle

	var body: some View {
		ControlTile {
			VStack(alignment: .leading, spacing: 8) {
				Text("Layout").font(.callout.bold())
				// Three across, so all six layouts fit in two rows.
				LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 10) {
					ForEach(SwitcherStyle.allCases, id: \.self) { style in
						LayoutChoice(style: style, isSelected: selection == style, onSelect: select)
					}
				}
			}
		}
	}

	private func select(_ style: SwitcherStyle) {
		selection = style
	}
}
