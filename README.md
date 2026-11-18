# Cycle

A ⌘Tab window switcher for macOS 26+, modelled on DockDoor Pro's Alt-Tab switcher. It switches
between windows, not apps, with live thumbnails on Liquid Glass cards.

## Use

| Key           | Does                                                     |
| ------------- | -------------------------------------------------------- |
| ⌘Tab (hold ⌘) | open; Tab / Shift-Tab / arrows move; release ⌘ to switch |
| ⌘`            | next window of the highlighted app                       |
| `,`           | search windows (stays open; Return switches)             |
| Esc           | clear search, then cancel                                |
| Q W M F H     | quit app, close, minimize, full screen, hide             |

Windows are grouped by app by default; a grid and a list (with a large preview) are the
other layouts. Each window's controls (close, minimize, full screen, then quit) appear on it
when it's highlighted or under the pointer. A quick ⌘Tab tap switches to the previous window
without showing the panel, and pressing ⌘Tab rapidly never leaves the switcher stuck open.

There's no menu-bar item. Settings are behind the round gear floating left of the switcher
(it keeps the switcher open until Return, a click or Escape; Escape closes settings first), or
open Cycle again from Finder or Spotlight.
They cover the layout, the modifier (⌘, ⌥ or ⌃), whether the switcher stays open until
Return, this Space only, minimized and hidden windows, apps without windows (off by default),
and the search bar (off removes the switcher's top row; `,` still searches). Quit is in the
settings header.

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

## Icons

SVG sources are in `Support/Icons` (`cycle-minimal` is the app icon; `cycle-panes`,
`cycle-carousel` and `cycle-orbit` are alternatives).
`just icon <name>` rebuilds `Support/AppIcon.icns` from one of them.

`open build/Cycle.app --args --setup` shows the setup window even when everything is granted.
`Cycle --dump` prints the window list a session would show; `Cycle --demo [grouped|grid|list]` opens it over made-up windows (add `--with-settings` to open settings too); `Cycle --preview` shows the panel for
four seconds without the keyboard.

It uses private SkyLight and HIServices calls (`CGSHWCaptureWindowList`, `_AXUIElementGetWindow`,
`_SLPSSetFrontProcessWithOptions`, `SLPSPostEventRecordTo`), so it can't be sandboxed or ship on the
App Store.
