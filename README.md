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

Hold a window's card for a moment (or press and drag it) and a small copy of the screen
appears under the switcher, showing the windows already tiled there. Drag onto it to tile:

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
clear them all. Dragging any marked window brings the others along. Dropped on a preset slot,
the window you dragged takes that slot and the others fill the next slots in the order you
marked them. Dropped on the screen or beside a tiled window, they go side by side (stacked
along a side edge), sharing the space evenly.

From the keyboard, ⌘1 to ⌘9 apply the presets in the order the board shows them (the number
is on each chip). The marked windows fill the slots in order, starting with the main slot,
or the highlighted window does if nothing's marked. Mid-drag, the dragged windows are used.
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
    "restoreLayouts": true
  }
}
```

`modifier` is `command`, `option` or `control`. `activationMode` is `onKeyRelease` or
`onConfirmation`, and `layout` is `grouped`, `grid` or `list`. Preset names are `halves`,
`thirds`, `quarters`, `mainStack`, `centre`, `rows` and `full`, in ⌘1… order.

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

| Folder                                      | What's in it                                                                                      |
| ------------------------------------------- | ------------------------------------------------------------------------------------------------- |
| `App`                                       | Entry point and app delegate                                                                      |
| `Settings` | `cycle.config` (reading, writing, watching, migrating) and the observable copy the settings panel edits |
| `Input`                                     | The keyboard event tap and key codes                                                              |
| `System`                                    | Private SkyLight / AX calls, permissions, AppKit and AX helpers                                   |
| `Windows`                                   | Listing windows, thumbnails, recency order, focusing and window actions                           |
| `Switcher/Controller`                       | The session controller, split by concern (keyboard, navigation, search, mouse, actions, settings) |
| `Switcher/Model`, `Panel`, `Views`, `Cards` | Session state, the panel and its layout, and the SwiftUI views                                    |
| `Tiling/Model`                              | Presets, the board (targets and drops) and drag state, built on RiftCore                          |
| `Tiling/Engine` | The layout store, remembered layouts, close watching, the window mover and the coordinator that runs tiling between sessions |
| `Tiling/Interaction`                        | Mouse tracking, the controller's tiling extension and the overlay panel                           |
| `Tiling/Views`                              | The board, presets, ghosts and mark badges                                                        |
| `SettingsPanel`                             | The settings panel, its tiles and controls                                                        |
| `Setup`                                     | First-run permissions window and drag-to-grant                                                    |
| `Style`                                     | Theme constants and shared view styles                                                            |

## Releasing

Bump `VERSION`, commit, then `just release`: it builds and zips the app, publishes
`v<version>` on GitHub with the zip, and updates the cask in
[zmscode/homebrew-cycle](https://github.com/zmscode/homebrew-cycle) with the new version and
checksum. `Casks/cycle.rb` here is the template it fills in.

## Icons

SVG sources are in `Support/Icons` (`cycle-minimal` is the app icon; `cycle-panes`,
`cycle-carousel` and `cycle-orbit` are alternatives).
`just icon <name>` rebuilds `Support/AppIcon.icns` from one of them.

`open build/Cycle.app --args --setup` shows the setup window even when everything is granted.
`Cycle --dump` prints the window list a session would show.

It uses private SkyLight and HIServices calls (`CGSHWCaptureWindowList`, `_AXUIElementGetWindow`,
`_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo`), so it can't be sandboxed or ship on the
App Store.
