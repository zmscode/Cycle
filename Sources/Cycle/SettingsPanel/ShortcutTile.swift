import SwiftUI

/// The modifier held with Tab, as three round keys.
struct ShortcutTile: View {
	@Binding var modifier: InitializerModifier

	var body: some View {
		ControlTile {
			HStack(spacing: 10) {
				VStack(alignment: .leading, spacing: 1) {
					Text("Shortcut").font(.callout.bold())
					Text("\(modifier.symbol) + Tab")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				Spacer()
				ForEach(InitializerModifier.allCases, id: \.self) { key in
					ModifierKeyButton(key: key, isSelected: modifier == key, onSelect: select)
				}
			}
		}
	}

	private func select(_ key: InitializerModifier) {
		modifier = key
	}
}
