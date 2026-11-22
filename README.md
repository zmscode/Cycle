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
| Esc           | close settings, then clear the filter, then cancel              |
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

To tile several windows at once, right-click each one first: it gets a numbered badge
(right-click again to unmark it, or press Esc to clear them all). Dragging any marked window
brings the others along. Dropped on a preset slot, the window you dragged takes that slot and
the others fill the next slots in the order you marked them; dropped on the screen or beside
a tiled window, they go side by side (stacked, along a side edge), sharing the space evenly.

Keep holding ⌘ to tile several windows in one go; let go of ⌘ and the drop switches to the
window you dropped. Esc puts a drag down. The layout is remembered per screen until you
quit, so later sessions add to it; a window you've moved or resized yourself drops out of
it. The layout tree, frames and drop zones come from [RiftCore](https://github.com/zmscode/Rift).
Windows on other Spaces and full-screen windows can't be tiled.

The Tiling tile in settings picks which presets the board shows, the main window's share
in Main + Stack and Centre, and the gaps between windows and around the screen's edges
(down to none). Changing a gap re-tiles the windows already tiled straight away.

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
