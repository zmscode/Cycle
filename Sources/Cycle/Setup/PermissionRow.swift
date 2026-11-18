import SwiftUI

/// One permission step. The current step opens into a drag well holding Cycle's icon;
/// upcoming steps are dimmed; granted ones show a check.
struct PermissionRow: View {
	let number: Int
	let symbol: String
	let title: LocalizedStringKey
	let detail: LocalizedStringKey
	let state: PermissionStepState
	let onDrag: (DraggableAppIcon.Phase) -> Void
	let onOpen: () -> Void

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			HStack(alignment: .firstTextBaseline, spacing: 14) {
				StepBadge(number: number, state: state)
					.alignmentGuide(.firstTextBaseline) { $0[VerticalAlignment.center] + 5 }
				VStack(alignment: .leading, spacing: 3) {
					Label(title, systemImage: symbol)
						.font(.headline)
					Text(detail)
						.font(.callout)
						.foregroundStyle(.secondary)
						.fixedSize(horizontal: false, vertical: true)
				}
				Spacer(minLength: 0)
			}
			if state == .current {
				DragWell(title: title, onDrag: onDrag, onOpen: onOpen)
					.padding(.leading, 42)
					.transition(.opacity)
			}
		}
		.padding(16)
		.opacity(state == .upcoming ? 0.5 : 1)
	}
}
