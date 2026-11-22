import SwiftUI

/// A saved workspace in settings: its name, what it holds, Apply, and Delete on hover.
struct WorkspaceRow: View {
	let workspace: Workspace
	let onApply: () -> Void
	let onDelete: () -> Void

	@State private var isHovered = false

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
			if isHovered {
				Button(action: onDelete) {
					Image(systemName: "trash")
						.font(.caption)
						.foregroundStyle(.secondary)
						.frame(width: 22, height: 22)
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
		.onHover { hovering in withAnimation(.snappy(duration: 0.15)) { isHovered = hovering } }
		.accessibilityElement(children: .contain)
	}

	private var summary: String {
		let windows = workspace.windows.count
		let displays = workspace.displays.count
		let windowText = windows == 1 ? "1 window" : "\(windows) windows"
		return displays > 1 ? "\(windowText) · \(displays) displays" : windowText
	}
}
