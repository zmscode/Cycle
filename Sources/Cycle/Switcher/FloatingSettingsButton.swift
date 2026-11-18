import SwiftUI

/// The settings button, floating as its own round piece of glass just left of the
/// switcher rather than inside it. Drawn on the same dark glass sheet as the switcher and
/// settings, and filled with the accent colour while settings are open, like every other
/// "on" control.
struct FloatingSettingsButton: View {
	let state: SwitcherState
	let onToggle: () -> Void

	private var isOpen: Bool { state.isShowingSettings }

	var body: some View {
		Button("Settings", systemImage: "gearshape.fill", action: onToggle)
			.labelStyle(.iconOnly)
			.font(.title3)
			.foregroundStyle(isOpen ? .white : .primary)
			.frame(width: Theme.Gear.diameter, height: Theme.Gear.diameter)
			.background(isOpen ? AnyShapeStyle(Theme.Colors.selection) : AnyShapeStyle(.clear), in: .circle)
			.contentShape(.circle)
			.buttonStyle(.plain)
			.glassSheet(cornerRadius: Theme.Gear.diameter / 2)
			.help("Cycle Settings")
			.accessibilityAddTraits(isOpen ? .isSelected : [])
			.animation(.smooth(duration: 0.18), value: isOpen)
	}
}
