import SwiftUI

/// Permission status as two compact rows, with Set Up when something is missing.
struct PermissionsTile: View {
	let permissions: Permissions
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
				PermissionStatusRow(title: "Screen Recording", granted: permissions.screenRecording)
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
