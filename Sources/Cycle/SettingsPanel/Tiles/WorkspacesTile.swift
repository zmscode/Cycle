import SwiftUI

/// Workspaces: save the layouts of every display under a name, and put them back later
/// (opening any apps that aren't running). Also `Cycle --workspace <name>`.
struct WorkspacesTile: View {
	@Bindable var settings: MenuSettings
	/// The current layouts as a workspace with this name; nil when nothing is tiled.
	let capture: (String) -> Workspace?
	/// Applies a workspace; returns how many of its displays aren't connected.
	let apply: (Workspace) -> Int

	@State private var name = ""
	@State private var note: String?
	@FocusState private var nameFocused: Bool

	var body: some View {
		ControlTile {
			VStack(alignment: .leading, spacing: 8) {
				Text("Workspaces").font(.callout.bold())
				if settings.tilingWorkspaces.isEmpty {
					Text("Save how every display is tiled now, to put it back later.")
						.font(.caption2)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
				ForEach(settings.tilingWorkspaces) { workspace in
					WorkspaceRow(
						workspace: workspace, onApply: { applyWorkspace(workspace) },
						onDelete: { delete(workspace) })
				}
				saveRow
				if let note {
					Text(note)
						.font(.caption2)
						.foregroundStyle(.secondary)
						.transition(.opacity)
				}
			}
		}
		.onChange(of: nameFocused) { _, focused in settings.isEditingText = focused }
		.onDisappear { settings.isEditingText = false }
	}

	private var saveRow: some View {
		HStack(spacing: 6) {
			TextField("Workspace name", text: $name)
				.textFieldStyle(.plain)
				.font(.callout)
				.focused($nameFocused)
				.onSubmit(save)
				.padding(.horizontal, 10)
				.padding(.vertical, 4)
				.background(.black.opacity(0.25), in: .capsule)
				.overlay {
					Capsule().strokeBorder(nameFocused ? Theme.Colors.mark : .white.opacity(0.12))
				}
			Button("Save Current", action: save)
				.buttonStyle(EditorButtonStyle())
				.disabled(trimmedName.isEmpty)
				.opacity(trimmedName.isEmpty ? 0.5 : 1)
		}
	}

	private var trimmedName: String {
		name.trimmingCharacters(in: .whitespacesAndNewlines)
	}

	/// Saves the current layouts; a workspace with the same name is replaced.
	private func save() {
		let name = trimmedName
		guard !name.isEmpty else { return }
		guard var workspace = capture(name) else { return show("Nothing is tiled yet") }
		var workspaces = settings.tilingWorkspaces
		if let index = workspaces.firstIndex(where: {
			$0.name.compare(name, options: .caseInsensitive) == .orderedSame
		}) {
			workspace.id = workspaces[index].id
			workspaces[index] = workspace
		} else {
			workspaces.append(workspace)
		}
		settings.tilingWorkspaces = workspaces
		self.name = ""
		nameFocused = false
		show("Saved \(name)")
	}

	private func applyWorkspace(_ workspace: Workspace) {
		let skipped = apply(workspace)
		show(
			skipped == 0
				? "Applied \(workspace.name)"
				: "Applied \(workspace.name) · \(skipped) display\(skipped == 1 ? "" : "s") not connected")
	}

	private func delete(_ workspace: Workspace) {
		settings.tilingWorkspaces.removeAll { $0.id == workspace.id }
	}

	private func show(_ text: String) {
		withAnimation { note = text }
		DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
			guard note == text else { return }
			withAnimation { note = nil }
		}
	}
}
