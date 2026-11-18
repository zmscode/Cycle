import SwiftUI

/// What's left: a tip for entries that don't register, a relaunch once Screen Recording
/// is granted, or "All set".
struct SetupFooter: View {
	let permissions: Permissions

	var body: some View {
		if permissions.needsRelaunch {
			HStack {
				Text("Relaunch Cycle so previews start working.")
					.font(.callout)
					.foregroundStyle(.secondary)
				Spacer()
				Button("Relaunch Cycle", action: permissions.relaunch)
					.buttonStyle(.glassProminent)
					.controlSize(.large)
			}
		} else if permissions.allGranted {
			Label("All set. Hold ⌘ and press Tab.", systemImage: "checkmark.circle.fill")
				.font(.headline)
				.foregroundStyle(.green)
				.frame(maxWidth: .infinity)
		} else {
			// A grant is tied to the build that was in the list when it was switched on;
			// an entry left from an older build shows as on but doesn't count.
			Label {
				Text(
					"Already on in the list but not ticked here? Remove Cycle with −, then drag it in again. On macOS 27, Accessibility is called Device Control and Data Access."
				)
				.fixedSize(horizontal: false, vertical: true)
			} icon: {
				Image(systemName: "info.circle")
			}
			.font(.footnote)
			.foregroundStyle(.secondary)
		}
	}
}
