import RiftCore
import SwiftUI

/// Cycle's settings, on the same glass sheet as the switcher: a header row like the
/// switcher's, then Control Center-style tiles for the layout, the shortcut, the switcher
/// options and permissions.
struct SettingsPanelView: View {
	@Bindable var settings: MenuSettings
	let permissions: Permissions
	let tapIsRunning: () -> Bool
	let onSetup: () -> Void
	let onOpenConfig: () -> Void
	/// The screen's tiled layout, for the preset editor to start from.
	let currentLayout: () -> RiftLayout<Int>?
	/// The current layouts as a workspace, and applying one.
	let captureWorkspace: (String) -> Workspace?
	let applyWorkspace: (Workspace) -> Int
	/// The content changed height; the panel fits itself to it.
	let onResize: () -> Void
	let onQuit: () -> Void

	var body: some View {
		VStack(spacing: 0) {
			SettingsPanelHeader(onOpenConfig: onOpenConfig, onQuit: onQuit)
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
				TilingTile(settings: settings, currentLayout: currentLayout, onResize: onResize)
				Grid(
					horizontalSpacing: ControlTileMetrics.spacing,
					verticalSpacing: ControlTileMetrics.spacing
				) {
					GridRow {
						ToggleTile(
							title: "Fill Gaps", subtitle: "When Closed",
							systemImage: "rectangle.split.2x1", isOn: $settings.tilingFillsGaps)
						ToggleTile(
							title: "Restore", subtitle: "Layouts",
							systemImage: "clock.arrow.circlepath",
							isOn: $settings.tilingRestoresLayouts)
					}
					GridRow {
						ToggleTile(
							title: "Dividers", subtitle: "On Screen",
							systemImage: "arrow.left.and.right.square",
							isOn: $settings.tilingShowsDividers)
						ToggleTile(
							title: "Animate", subtitle: "Windows",
							systemImage: "wind", isOn: $settings.tilingAnimates)
					}
					GridRow {
						ToggleTile(
							title: "Right-Click", subtitle: "Opens Menu",
							systemImage: "contextualmenu.and.cursorarrow",
							isOn: $settings.tilingRightClickMenu)
						ToggleTile(
							title: "Right-Click", subtitle: "Outside Undoes",
							systemImage: "arrow.uturn.backward",
							isOn: $settings.tilingRightClickUndo)
					}
					GridRow {
						ToggleTile(
							title: "Undo Notes", subtitle: "After Tiling",
							systemImage: "text.bubble", isOn: $settings.tilingShowsNotes)
						ToggleTile(
							title: "Haptics", subtitle: "Trackpad",
							systemImage: "hand.tap", isOn: $settings.haptics)
					}
				}
				WorkspacesTile(
					settings: settings, capture: captureWorkspace, apply: applyWorkspace)
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
