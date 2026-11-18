/// Where a permission row is in the setup sequence.
enum PermissionStepState {
	/// The step to do now: it shows the drag well.
	case current
	/// Waits for the step before it.
	case upcoming
	case granted
}
