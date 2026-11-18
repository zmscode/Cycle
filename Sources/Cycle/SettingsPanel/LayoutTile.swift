import SwiftUI

/// The three layouts as round controls with captions; the current one is filled.
struct LayoutTile: View {
	@Binding var selection: SwitcherStyle

	var body: some View {
		ControlTile {
			VStack(alignment: .leading, spacing: 8) {
				Text("Layout").font(.callout.bold())
				HStack {
					ForEach(SwitcherStyle.allCases, id: \.self) { style in
						LayoutChoice(style: style, isSelected: selection == style, onSelect: select)
							.frame(maxWidth: .infinity)
					}
				}
			}
		}
	}

	private func select(_ style: SwitcherStyle) {
		selection = style
	}
}
