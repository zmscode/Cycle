import SwiftUI

/// The list layout's detail pane: the highlighted window's preview with its controls, and
/// its title and app underneath.
struct WindowPreviewPane: View {
	let window: SwitcherWindow?
	let image: NSImage?
	/// The space for the preview; the window's own shape is fitted into it.
	let previewBox: CGSize
	let controller: SwitcherController

	var body: some View {
		VStack(alignment: .leading, spacing: 14) {
			if let window {
				if !window.isWindowless {
					WindowControls(isActive: true, onAction: perform)
				}
				// Centred in a fixed box, so portrait and small windows sit in the middle of
				// the pane and the title below doesn't jump as the selection changes.
				WindowThumbnail(
					window: window, image: image,
					size: SwitcherLayout.fit(aspect: SwitcherLayout.aspect(of: window), in: previewBox),
					isSelected: false)
					.frame(width: previewBox.width, height: previewBox.height)
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
