# Cycle

A ⌘Tab window switcher for macOS 26+, modelled on DockDoor Pro's Alt-Tab switcher. It switches
between windows, not apps, with live thumbnails on Liquid Glass cards.

## Install

```bash
brew install --cask zmscode/cycle/cycle
```

Cycle isn't notarized yet, so macOS may refuse to open it the first time: approve it once in
System Settings > Privacy & Security > Open Anyway, or run
`xattr -dr com.apple.quarantine /Applications/Cycle.app`. It needs macOS 26 or later on Apple
silicon.

## Use

| Key           | Does                                                            |
| ------------- | --------------------------------------------------------------- |
| ⌘Tab (hold ⌘) | open; Tab / Shift-Tab step through windows; release ⌘ to switch |
| ← →           | move along the current row                                      |
| ↑ ↓           | move to the row above or below                                  |
| scroll        | next / previous window                                          |
| type          | filter by app or window name (release ⌘ to switch to the match) |
| ⌘`            | next window of the highlighted app                              |
| Space         | mark the highlighted window for tiling (before typing a filter) |
| ⌘1 … ⌘9       | tile with the board's first … ninth preset                      |
| Esc           | close settings, clear the filter, clear marks, then cancel      |
| Return        | switch to the highlighted window                                |

Windows are grouped by app by default. The other layouts, picked in settings:

- **Grid**: every window in rows. **List**: rows with large icons and a big preview.

Each window's controls (close, minimize, full screen, then quit) appear on it
when it's highlighted or under the pointer. A quick ⌘Tab tap switches to the previous window
without showing the panel, and pressing ⌘Tab rapidly never leaves the switcher stuck open.

### Tiling

While the switcher's screen has tiled windows, a small copy of the screen (the board)
shows under the switcher. Hold a window's card for a moment (or press and drag it) and the
board appears if it isn't already. Drag onto it to tile:

- onto an empty screen: the window fills it;
- onto an edge of a tiled window: that window splits and the new one takes that half;
- onto the middle of a tiled window: the new one takes its place (dragging a tiled window
  onto another swaps them);
- along the screen's outer edge: a full-height or full-width slot beside everything;
- onto a slot of one of the presets under the board (Halves, Thirds, Quarters, Main + Stack,
  Centre, Rows, Full): the screen is laid out that way, with the window in that slot and
  windows already tiled filling the rest. Slots left over stay empty, shown dashed on the
  board, until you drop a window into them.

While you hover the board, the tiles stay where they are and the dragged windows are drawn,
outlined, where they'll land. Dropping a tiled window on another's middle shows the swap.
The caption names the spot ("Left of Zed", "Full width along the top", "Swap with Zed").
While you hover a preset chip, the board shows the whole layout that preset would make,
and the caption says if any tiled window would be left out. Over a target, the dragged
window shrinks and moves to the lower right of the pointer so the spot stays in view.

To tile several windows at once, mark each one first by right-clicking it or pressing Space.
It gets a numbered badge. Right-click or press Space again to unmark it, or press Esc to
clear them all. Dragging any marked window brings the others along. Dropped on a preset, they fill its slots in the order you
marked them, left to right and then top to bottom (window 1 on the left in Halves, window 2
on the right), whichever window you grabbed; the chip lights the slots they'll take. Dropped on the screen or beside a tiled window, they go side by side (stacked
along a side edge), sharing the space evenly.

From the keyboard, ⌘1 to ⌘9 apply the presets in the order the board shows them (the number
is on each chip). The marked windows fill the slots in the order you marked them, left to
right, or the highlighted window takes the main slot if nothing's marked. Mid-drag, the dragged windows are used.
If the screen is already laid out with that preset and has empty slots, the windows go into
those instead. A note at the foot of the switcher confirms the preset, and names any tiled
window that was left out.

Keep holding ⌘ to tile several windows in one go; let go of ⌘ and the drop switches to the
window you dropped. Esc puts a drag down. A window you've moved or resized yourself drops out
of the layout. The layout tree, frames and drop zones come from
[RiftCore](https://github.com/zmscode/Rift). Windows on other Spaces and full-screen windows
can't be tiled.

**Closing and quitting.** When a tiled window closes, the rest of its row closes up, each
keeping its share, so an even row stays even: Thirds becomes halves.
When its app quits, its windows are remembered as away and the neighbours fill in
meanwhile. With **Fill Gaps** off, a closed or away window leaves an empty slot instead.

**Remembered layouts.** Each screen's layout is saved in `~/.config/cycle/layouts.json`,
keyed by the display's UUID. When Cycle starts, or a tiled app reopens, Cycle finds the
remembered windows: first by window id (if Cycle restarted), then by app and title, then by
app alone. App alone only counts windows with a title of their own, and never dialogs, so a
launch panel isn't mistaken for a document. It then puts them back in place. A restored
window that closes within 10 seconds leaves its slot waiting for the real one. Minimized and
hidden windows wait until they're shown.
**Restore Layouts** turns this off.

**Dividers.** Slim grips sit in the gaps between tiled windows on the screen. Drag one to
resize the windows on either side live (it snaps to the middle with a tick), and
double-click one to even them up. They sit just above the tiled windows, so a window in
front covers them, and they hide while the tiled windows aren't on screen. The board has the
same grips during a session. **Dividers** in settings turns the screen grips off.

**Undo.** Right-click anywhere outside the switcher (on the desktop or another app's window)
to undo the last tiling change: a drop, a preset, a divider drag. Each right-click undoes
one more, up to 20. The click is caught, so the app underneath doesn't open a menu.

**Custom presets.** The New tile at the end of the presets grid opens the preset editor. It
has a little screen you split and resize: hover a slot to split it side by side, split it
top to bottom, or remove it. Drag a divider to move it, or double-click it to even it. Start
from any built-in preset, or from the screen's current layout. Slots are numbered as they'll
be filled, and the largest is the main slot. A new preset goes on the board straight away;
hover it in the grid and click the pencil to edit or delete it. Presets can have up to
8 slots.

**Animation.** Windows glide into place when tiled, restored or re-tiled (divider drags
follow the pointer directly). **Animate** in settings turns it off, and the Animation slider
sets how long it takes (0.05–0.5 s). It's off while macOS's Reduce Motion is on. An app that
answers too slowly to animate smoothly snaps into place instead.

**Rearranging on the board.** The board's tiles can be picked up during a session. Drop
one on another tile's middle to swap them, on an edge to move it beside that tile, or along
the screen's edge. Drag it off the board to take it out of the layout (it stays where it
is). Right-click a tile for **Remove from Layout** and **Close Window**; right-clicks on the
board don't undo.

**Rotating marked windows.** With several marked windows over a preset chip, the chip
numbers the slots each will take. Scroll to rotate them through the slots (and, with more
windows than slots, through which ones are left out); releasing applies what's shown.

**Other displays.** With more than one display, the board's header shows a chip for each.
Mid-drag, rest the pointer on one for a moment and the board switches to that display:
dropping there moves the windows to it, and the display they came from closes up.

**Windows that won't fit.** Some apps won't shrink below a minimum size. After tiling,
Cycle checks where each window actually landed. If one came out up to 15% bigger than its
slot, the neighbouring divider moves to make room and the windows are placed once more. A
bigger overrun is left where the app put it and outlined in amber on the board. Cycle
remembers each app's minimum while it runs, so later layouts make room straight away.

**Adjusting built-in presets.** Hover a built-in preset in the grid and click the sliders
to open a copy in the preset editor. Saving makes it a custom preset that takes the
original's place on the board, ⌘ number included.

**Workspaces.** The Workspaces tile in settings saves how every display is tiled now under
a name, and puts it back with **Apply**: apps that aren't running are opened, and their
windows are tiled as they appear (matched as remembered layouts are). A display that isn't
connected is skipped. Each display it lays out is one undo step. `Cycle --workspace <name>`
applies one from the command line, handing it to the copy of Cycle that's running.
Workspaces are kept in `cycle.config` under `tiling.workspaces`.

The Tiling tile in settings picks which presets the board shows, the main window's share
in Main + Stack and Centre, and the gaps between windows and around the screen's edges
(down to none). Presets are numbered ⌘1, ⌘2… in the order the grid shows them (or the
order you gave them in `cycle.config`). Changing a gap
re-tiles the windows already tiled straight away.

### Settings file

Settings live in `~/.config/cycle/cycle.config` (or `$XDG_CONFIG_HOME/cycle`), a JSON file.
The settings panel writes to it, and edits you make by hand apply while Cycle runs. A
missing or invalid value falls back to its default. The page button in the settings header
opens it. On first launch it's created from the settings earlier versions kept in
UserDefaults.

```json
{
	"switcher": {
		"activationMode": "onKeyRelease",
		"currentSpaceOnly": false,
		"includeHiddenWindows": true,
		"layout": "grouped",
		"modifier": "command",
		"panelDelay": 0.12,
		"showWindowlessApps": false
	},
	"tiling": {
		"fillGaps": true,
		"gap": 10,
		"mainShare": 0.6,
		"margin": 10,
		"presets": ["halves", "thirds", "quarters", "mainStack", "full"],
		"restoreLayouts": true,
		"showDividers": true,
		"animate": true,
		"animationDuration": 0.2,
		"customPresets": [],
		"workspaces": []
	}
}
```

`modifier` is `command`, `option` or `control`. `activationMode` is `onKeyRelease` or
`onConfirmation`, and `layout` is `grouped`, `grid` or `list`. Preset names are `halves`,
`thirds`, `quarters`, `mainStack`, `centre`, `rows` and `full`, in ⌘1… order, plus the `id`
of any custom preset. A custom preset is `{ "id": "custom-…", "name": "…", "layout": <Rift
tree> }`, where the tree's panes are slot numbers from 0.

There's no menu-bar item. Settings are behind the round gear in the top-right corner of the
screen while the switcher is open (it keeps the switcher open until Return, a click or Escape; Escape closes settings first), or
open Cycle again from Finder or Spotlight.
They cover the layout, the modifier (⌘, ⌥ or ⌃), whether the switcher stays open until
Return, this Space only, minimized and hidden windows, and apps without windows (off by
default). Quit is in the settings header. There are no letter shortcuts, so typing always
filters; the window controls on each card do close, minimize, full screen and quit.

## Build

```bash
just run
```

Without [`just`](https://github.com/casey/just), the `Makefile` has the same tasks for the
`make` that ships with macOS:

```bash
make run
```

`make help` lists them. Options are variables: `make build CONFIG=debug` builds a debug copy,
and `make icon NAME=cycle-panes` picks the icon. `make release` does the same as
`just release`.

Cycle needs **Accessibility** (for the keyboard tap and window control) and **Screen Recording**
(for thumbnails and titles). On launch, if either is missing, Cycle opens a setup window and
takes you through them in order. It opens System Settings at the Accessibility list (Device
Control and Data Access on macOS 27) and docks beside it. The Accessibility row holds the Cycle
icon: drag it into the list, which adds Cycle and switches it on, as in Rex's permission flow.
Once Cycle is detected, Settings moves to the Screen Recording list and the icon moves to that
row. While you drag, everything but System Settings is dimmed. Afterwards the window offers to
relaunch Cycle, which macOS needs before captures work.

The build is ad hoc signed with a designated requirement of its bundle id, so grants survive
rebuilds. `just reset-permissions` clears them. Set `CYCLE_SIGN_IDENTITY` to sign with a
certificate instead.

### Project layout

Everything is in `Sources/Cycle`, one type per file:

| Folder                                      | What's in it                                                                                                                                      |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------- |
| `App`                                       | Entry point and app delegate                                                                                                                      |
| `Settings`                                  | `cycle.config` (reading, writing, watching, migrating) and the observable copy the settings panel edits                                           |
| `Input`                                     | The keyboard event tap and key codes                                                                                                              |
| `System`                                    | Private SkyLight / AX calls, permissions, AppKit and AX helpers                                                                                   |
| `Windows`                                   | Listing windows, thumbnails, recency order, focusing and window actions                                                                           |
| `Switcher/Controller`                       | The session controller, split by concern (keyboard, navigation, search, mouse, actions, settings)                                                 |
| `Switcher/Model`, `Panel`, `Views`, `Cards` | Session state, the panel and its layout, and the SwiftUI views                                                                                    |
| `Tiling/Model`                              | Presets, the board (targets and drops) and drag state, built on RiftCore                                                                          |
| `Tiling/Engine`                             | The layout store, remembered layouts, window watching, the animated window mover, and the coordinator (with undo, divider drags and screen grips) |
| `Tiling/Dividers`                           | The divider grip windows, shared by the screen and the board                                                                                      |
| `Tiling/Debug`                              | `--render-board` (debug builds): renders the board and editor offscreen                                                                           |
| `Tiling/Interaction`                        | Mouse tracking, the controller's tiling and board extensions, divider resizing and the overlay panel                                              |
| `Tiling/Views`                              | The board, presets, ghosts and mark badges                                                                                                        |
| `SettingsPanel`                             | The settings panel, its tiles and controls, and the preset editor                                                                                 |
| `Setup`                                     | First-run permissions window and drag-to-grant                                                                                                    |
| `Style`                                     | Theme constants and shared view styles                                                                                                            |

## Releasing

Bump `VERSION`, commit, then `just release`: it builds and zips the app, publishes
`v<version>` on GitHub with the zip, and updates the cask in
[zmscode/homebrew-cycle](https://github.com/zmscode/homebrew-cycle) with the new version and
checksum. `Casks/cycle.rb` here is the template it fills in.

## Icons

The icon's SVG sources are no longer in the repository; `Support/AppIcon.icns` is the app
icon. To change it, put an SVG in `Support/Icons` and run `just icon <name>`, which rebuilds
`Support/AppIcon.icns` from it.

`open build/Cycle.app --args --setup` shows the setup window even when everything is granted.
`Cycle --dump` prints the window list a session would show.

It uses private SkyLight and HIServices calls (`CGSHWCaptureWindowList`, `_AXUIElementGetWindow`,
`_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo`), so it can't be sandboxed or ship on the
App Store.
