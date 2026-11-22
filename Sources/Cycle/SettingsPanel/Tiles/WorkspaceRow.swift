import SwiftUI

/// A saved workspace in settings: its name, what it holds, Apply, and Delete (on hover, a
/// right-click or VoiceOver). Delete asks once more before it goes, since it can't be
/// undone.
struct WorkspaceRow: View {
	let workspace: Workspace
	let onApply: () -> Void
	let onDelete: () -> Void

	@State private var isHovered = false
	@State private var isConfirmingDelete = false

	var body: some View {
		HStack(spacing: 8) {
			Image(systemName: "square.grid.2x2")
				.foregroundStyle(Theme.Colors.mark)
				.accessibilityHidden(true)
			VStack(alignment: .leading, spacing: 1) {
				Text(workspace.name)
					.font(.callout.weight(.medium))
					.lineLimit(1)
				Text(summary)
					.font(.caption2)
					.foregroundStyle(.secondary)
					.lineLimit(1)
			}
			Spacer(minLength: 4)
			if isConfirmingDelete {
				Button("Delete", role: .destructive, action: onDelete)
					.buttonStyle(EditorButtonStyle(kind: .destructive))
					.accessibilityLabel("Delete \(workspace.name)")
					.transition(.opacity)
			} else if isHovered {
				Button(action: confirmDelete) {
					Image(systemName: "trash")
						.font(.caption)
						.foregroundStyle(.secondary)
						.frame(width: 24, height: 24)
						.contentShape(.rect)
				}
				.buttonStyle(.plain)
				.help("Delete \(workspace.name)")
				.accessibilityLabel("Delete \(workspace.name)")
				.transition(.opacity)
			}
			Button("Apply", action: onApply)
				.buttonStyle(EditorButtonStyle(kind: .prominent))
				.accessibilityLabel("Apply \(workspace.name)")
		}
		.padding(.vertical, 2)
		.contentShape(.rect)
		.onHover { hovering in
			withAnimation(.snappy(duration: 0.15)) {
				isHovered = hovering
				if !hovering { isConfirmingDelete = false }
			}
		}
		.contextMenu {
			Button("Apply", action: onApply)
			Divider()
			Button("Delete…", role: .destructive, action: confirmDelete)
		}
		.accessibilityElement(children: .contain)
		.accessibilityActions {
			Button("Apply \(workspace.name)", action: onApply)
			Button("Delete \(workspace.name)", action: onDelete)
		}
	}

	private func confirmDelete() {
		withAnimation(.snappy(duration: 0.15)) { isConfirmingDelete = true }
	}

	private var summary: String {
		let windows = workspace.windows.count
		let displays = workspace.displays.count
		let windowText = windows == 1 ? "1 window" : "\(windows) windows"
		return displays > 1 ? "\(windowText) · \(displays) displays" : windowText
	}
}
