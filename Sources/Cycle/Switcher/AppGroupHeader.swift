import SwiftUI

/// A group's large app icon and name, with its window count as a pill on the right.
struct AppGroupHeader: View {
	let window: SwitcherWindow
	let windowCount: Int

	var body: some View {
		HStack(spacing: 10) {
			if let icon = window.icon {
				Image(nsImage: icon)
					.resizable()
					.frame(width: Theme.Group.iconSize, height: Theme.Group.iconSize)
					.shadow(color: .black.opacity(0.3), radius: 3, y: 2)
					.accessibilityHidden(true)
			}
			Text(window.appName)
				.font(.headline)
				.lineLimit(1)
			Spacer(minLength: 4)
			if windowCount > 1 {
				Text(windowCount, format: .number)
					.font(.caption.bold().monospacedDigit())
					.foregroundStyle(.secondary)
					.padding(.horizontal, 8)
					.padding(.vertical, 2)
					.background(.white.opacity(0.1), in: .capsule)
					.accessibilityLabel("^[\(windowCount) window](inflect: true)")
			}
		}
		.padding(.horizontal, 4)
		.frame(height: Theme.Group.headerHeight)
	}
}
