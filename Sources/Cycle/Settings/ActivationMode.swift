/// DockDoor's `WindowCycleActivationMode`: commit when the modifier is released, or keep
/// the panel open until Return / click.
enum ActivationMode: String, CaseIterable {
	case onKeyRelease, onConfirmation
}
