import SwiftUI

/// A dashed well holding Cycle's icon, to drag into the open System Settings list, with a
/// link to reopen Settings if it was closed.
struct DragWell: View {
	let title: LocalizedStringKey
	let onDrag: (DraggableAppIcon.Phase) -> Void
	let onOpen: () -> Void

	private var shape: RoundedRectangle { RoundedRectangle(cornerRadius: 14) }

	var body: some View {
		HStack(spacing: 14) {
			DraggableAppIcon(appURL: Bundle.main.bundleURL, size: 48, onDrag: onDrag)
				.frame(width: 48, height: 48)
				.accessibilityLabel("Cycle app icon")
			VStack(alignment: .leading, spacing: 4) {
				Text("Drag Cycle into the list")
					.font(.callout.bold())
				Text("System Settings is open beside this window.")
					.font(.callout)
					.foregroundStyle(.secondary)
				Button("Open System Settings", action: onOpen)
					.buttonStyle(.link)
					.font(.callout)
			}
			Spacer(minLength: 0)
		}
		.padding(12)
		.background(Theme.Colors.selection.opacity(0.08), in: shape)
		.overlay {
			shape
				.strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
				.foregroundStyle(Theme.Colors.selection.opacity(0.6))
		}
	}
}
