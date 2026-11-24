import SwiftUI

/// Permission status as two compact rows, with Set Up when something is missing.
struct PermissionsTile: View {
	let permissions: Permissions
	/// Previews are on: Screen Recording is needed for them.
	let needsScreenRecording: Bool
	let tapIsRunning: Bool
	let onSetup: () -> Void

	var body: some View {
		ControlTile {
			VStack(alignment: .leading, spacing: 8) {
				HStack {
					Text("Permissions").font(.callout.bold())
					Spacer()
					if !permissions.allGranted || !tapIsRunning {
						Button("Set Up…", action: onSetup)
							.buttonStyle(.glass)
							.controlSize(.small)
					}
				}
				PermissionStatusRow(title: "Accessibility", granted: permissions.accessibility)
				if needsScreenRecording || permissions.screenRecording {
					PermissionStatusRow(
						title: "Screen Recording", granted: permissions.screenRecording)
				} else {
					Text("Screen Recording isn't needed with previews off.")
						.font(.caption)
						.foregroundStyle(.secondary)
				}
				if permissions.accessibility && !tapIsRunning {
					Label(
						"Keyboard shortcut isn't running. Relaunch Cycle.",
						systemImage: "exclamationmark.triangle.fill"
					)
					.font(.caption)
					.foregroundStyle(.orange)
				}
			}
		}
	}
}
