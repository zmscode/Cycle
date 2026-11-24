import SwiftUI

/// The setup window: a header, the two permission steps in one grouped card, and a footer
/// that reports progress.
struct PermissionsView: View {
	let permissions: Permissions
	let owner: PermissionsWindow

	@Environment(\.accessibilityReduceMotion) private var reduceMotion

	var body: some View {
		VStack(spacing: 24) {
			SetupHeader(completed: completedSteps, total: permissions.needsScreenRecording ? 2 : 1)
			VStack(spacing: 0) {
				PermissionRow(
					number: 1, symbol: "keyboard", title: "Accessibility",
					detail: "Catch ⌘Tab, list windows, and switch, close or minimize them.",
					state: state(for: .accessibility, granted: permissions.accessibility),
					onDrag: owner.iconDrag,
					onOpen: openAccessibility)
				if permissions.needsScreenRecording {
				Divider().padding(.leading, 56)
				PermissionRow(
					number: 2, symbol: "rectangle.dashed.badge.record", title: "Screen Recording",
					detail: "Draw live window previews and read window titles.",
					state: state(for: .screenRecording, granted: permissions.screenRecording),
					onDrag: owner.iconDrag,
					onOpen: openScreenRecording)
				}
			}
			.background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 16))
			.overlay {
				RoundedRectangle(cornerRadius: 16).strokeBorder(.separator, lineWidth: 0.5)
			}
			.animation(reduceMotion ? nil : Theme.Motion.selection, value: permissions.step)
			Spacer(minLength: 0)
			SetupFooter(permissions: permissions)
		}
		.padding(28)
		.padding(.top, 8)
		.frame(width: 460, height: 560)
	}

	private var completedSteps: Int {
		(permissions.accessibility ? 1 : 0)
			+ (permissions.needsScreenRecording && permissions.screenRecording ? 1 : 0)
	}

	private func state(for step: Permissions.Step, granted: Bool) -> PermissionStepState {
		if granted { return .granted }
		return permissions.step == step ? .current : .upcoming
	}

	private func openAccessibility() {
		owner.openPane(Permissions.Step.accessibility.pane)
	}

	private func openScreenRecording() {
		owner.openPane(Permissions.Step.screenRecording.pane)
	}
}
