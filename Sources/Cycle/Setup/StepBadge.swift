import SwiftUI

/// The step's number in a circle: filled when current, a green check once granted.
struct StepBadge: View {
	let number: Int
	let state: PermissionStepState

	var body: some View {
		ZStack {
			switch state {
			case .granted:
				Circle().fill(.green)
				Image(systemName: "checkmark")
					.font(.callout.bold())
					.foregroundStyle(.white)
			case .current:
				Circle().fill(Theme.Colors.selection)
				Text(number, format: .number)
					.font(.callout.bold())
					.foregroundStyle(.white)
			case .upcoming:
				Circle().strokeBorder(.tertiary, lineWidth: 1.5)
				Text(number, format: .number)
					.font(.callout.bold())
					.foregroundStyle(.tertiary)
			}
		}
		.frame(width: 28, height: 28)
		.accessibilityElement()
		.accessibilityLabel(accessibilityText)
	}

	private var accessibilityText: Text {
		switch state {
		case .granted: Text("Step \(number), done")
		case .current: Text("Step \(number), current")
		case .upcoming: Text("Step \(number), next")
		}
	}
}
