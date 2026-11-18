import SwiftUI

/// The list layout's detail pane: the highlighted window's preview with its controls, and
/// its title and app underneath.
struct WindowPreviewPane: View {
	let window: SwitcherWindow?
	let image: NSImage?
	let thumb: CGSize
	let controller: SwitcherController

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			if let window {
				WindowThumbnail(window: window, image: image, size: thumb, isSelected: false)
					.overlay(alignment: .topLeading) {
						if !window.isWindowless {
							WindowControls(onAction: perform)
								.padding(8)
						}
					}
				VStack(alignment: .leading, spacing: 4) {
					Text(window.displayTitle)
						.font(.title3.bold())
						.lineLimit(2)
					Label {
						Text(window.appName)
					} icon: {
						if let icon = window.icon {
							Image(nsImage: icon).resizable().frame(width: 16, height: 16)
						}
					}
					.font(.callout)
					.foregroundStyle(.secondary)
				}
			}
			Spacer(minLength: 0)
			SwitcherKeyHints()
		}
		.padding(Theme.Panel.padding)
		.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
	}

	private func perform(_ action: CardAction) {
		guard let window else { return }
		controller.perform(action, on: window.id)
	}
}
