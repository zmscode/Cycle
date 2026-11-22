import SwiftUI

/// Cycle's settings, on the same glass sheet as the switcher: a header row like the
/// switcher's, then Control Center-style tiles for the layout, the shortcut, the switcher
/// options and permissions.
struct SettingsPanelView: View {
	@Bindable var settings: MenuSettings
	let permissions: Permissions
	let tapIsRunning: () -> Bool
	let onSetup: () -> Void
	let onQuit: () -> Void

	var body: some View {
		VStack(spacing: 0) {
			SettingsPanelHeader(onQuit: onQuit)
			Divider()
				.padding(.horizontal, Theme.Panel.padding)
			VStack(spacing: ControlTileMetrics.spacing) {
				LayoutTile(selection: $settings.layout)
				ShortcutTile(modifier: $settings.modifier)
				Grid(
					horizontalSpacing: ControlTileMetrics.spacing,
					verticalSpacing: ControlTileMetrics.spacing
				) {
					GridRow {
						ToggleTile(
							title: "Keep Open", subtitle: "Until Return",
							systemImage: "return", isOn: $settings.keepOpenUntilReturn)
						ToggleTile(
							title: "This Space", subtitle: "Only",
							systemImage: "square.on.square", isOn: $settings.currentSpaceOnly)
					}
					GridRow {
						ToggleTile(
							title: "Minimized", subtitle: "& Hidden",
							systemImage: "minus.rectangle", isOn: $settings.includeHiddenWindows)
						ToggleTile(
							title: "Windowless", subtitle: "Apps",
							systemImage: "app.dashed", isOn: $settings.showWindowlessApps)
					}
				}
				TilingTile(settings: settings)
				PermissionsTile(
					permissions: permissions,
					tapIsRunning: permissions.accessibility ? tapIsRunning() : true,
					onSetup: onSetup)
			}
			.padding(ControlTileMetrics.sheetPadding)
		}
		.frame(width: ControlTileMetrics.panelWidth)
		.glassSheet()
	}
}
