# Tiling roadmap

Design notes for the tiling ideas still to build, written before building them. Each one
covers how it would work for you, how it would be built on what's there now (file names are
under `Sources/Cycle`), the edge cases, and a rough size: **S** is under a day, **M** is one
to two days, **L** is more. Questions that need your answer are marked **Decide**.

## Constraints

- **⌘ is held for the whole session.** In hold-to-switch mode the modifier stays down from
  opening the switcher to choosing a window, so any shortcut is really ⌘-something, and
  most ⌘ chords mean something to the system or to Cycle already.
- **Typing filters.** Letters, digits and the like go into the search, which is a core
  feature, so they can't become shortcuts either. (⌘1–⌘9 for presets and Space to mark
  before typing are the only exceptions, and they should stay the only ones.)
- **So new features use the mouse.** The board, grips, chips, right-click and scrolling
  are the place for them, plus settings and `cycle.config` for anything set once.

## What's there now

- **Settings:** `cycle.config` holds settings and custom presets. `layouts.json` holds each
  display's remembered layout.
- **Engine:** `TilingStore` keeps remembered trees bound to open windows.
  `TilingCoordinator` places windows (animated), fills gaps, restores layouts, drives
  divider drags and keeps the undo history.
- **The board:** during a session it shows under the switcher whenever the screen is tiled,
  with grips on its dividers, and it becomes the drop target when a window is picked up.
- **Screen grips:** they sit in the gaps between tiled windows on the real screen.
- **Undo:** a right-click outside the switcher undoes the last tiling change.

Most of the ideas below are new ways to produce a `RiftLayout<CGWindowID>` and pass it to
`TilingCoordinator.apply`.

---

## 6. Rearranging tiles on the board (M)

**How it works.** The board already shows during a session. You'd also be able to pick up
a tile on the board itself:
- **Moving:** drop it on another tile to swap them, or on an edge to move it there.
- **Taking it out:** drag it off the board to untile it (it stays where it is, out of the
  layout).
- **Right-click a tile:** "Remove from layout" and "Close window". This doesn't clash
  with undo, which only fires for right-clicks outside Cycle's panels.

**How it's built.**

- **Picking up tiles:** the board overlay lets clicks through, so tiles need a hit layer.
  Either give `TilingOverlayPanel` mouse events over the board card only, or add a
  transparent panel over the card the way `DividerHandles` does for grips.
- **Dragging tiles:** a tile drag is the same `WindowDrag`, started from the board, so
  `TilingBoard.target(at:)`, `dropping`, the preview and `apply` work unchanged. Rift's
  `moving(_:to:zone:)` already swaps.
- **Untiling:** dropping off the board calls `TilingStore.forget` (already used for windows
  the user moves away).

**Edge cases.**
- The board grips sit above the board; a tile drag should start only away from them.
- Picking a tile up must hold the session open like a card drag does.

## 8. Choosing a monitor while dragging (M)

**How it works.** With two or more displays, the board shows a small strip of display
thumbnails with the current one highlighted. Hovering one for about 0.4s switches the
board to that display. Dropping tiles there, moving windows across displays.

**How it's built.**

- **Boards:** `WindowDrag.screen` becomes mutable. Switching rebuilds `board` from
  `tiling.layout(for: other)` and the other display's visible frame, but the overlay stays
  on the switcher's screen. The board is a drawing, so it can show any display.
- **Saving:** `TilingStore.save` already takes a window out of other displays' layouts.
- **Layout:** `BoardPlacement` gets a `displays: [DisplayChip]` row above the card.

**Edge cases.**
- Displays with different aspect ratios: the card resizes when you switch.
- Screen grips already work per display, so nothing changes there.

## 10. Workspaces (L)

**How it works.** A workspace is a named set of windows and where they go, across every
display: for example "Coding" is the editor left, the terminal bottom right and the
browser top right.
- **Saving:** a "Save as Workspace" button on the board, or a Workspaces section in
  settings that captures the current layouts.
- **Applying:** from settings, from a workspace chip row on the board (clicked, not a
  shortcut), or the command line (`Cycle --workspace Coding`). Cycle launches any apps
  that aren't running, waits for their windows, then tiles them.

**How it's built.**

- **Storage:** `{ name, displays: [displayUUID: RiftLayout<RememberedSlot>] }`, the same
  shape as `layouts.json`, so `TilingStore.bind`'s matching rules already find the windows.
  It's kept in `workspaces.json`, or in `cycle.config` if it stays small.
- **Launching:** `NSWorkspace.openApplication` for each bundle id with no running app.
  The coordinator's `scheduleRestore` retry loop then binds windows as they appear, and
  dialogs and launch panels are already ignored.
- **Undo:** applying records one undo entry per display, so a right-click puts things back.

**Decide.** A workspace display that isn't connected: merge it onto the main display, or
skip it?

**Edge cases.**
- Apps that open one window when the workspace wants two: leave the extra slot empty.
- Titles change (browser tabs), so matching falls back to the app alone.

## 11. Per-preset ratios (S)

**How it works.** Custom presets already keep their own split positions. For the built-in
ones, an "Adjust…" item on a built-in's thumbnail in settings opens it in the preset
editor. Saving makes a custom copy ("Thirds 50/25/25"), which you can turn on in place of
the original. The single "Main Window" slider stays for Main + Stack and Centre.

**How it's built.**
- `PresetDraft(startingWith: builtin.layout(mainShare:), name:)` already does almost all
  of it; it needs only the entry point on built-in thumbnails.
- Optionally, swap the copy into the original's place in `tiling.presets` so its ⌘
  number carries over.

## 12. Windows that won't fit their slot (S–M)

**How it works.** Some apps have a minimum size or ignore resizes (some Electron apps,
System Settings). After tiling, Cycle notices a window that came out bigger than its slot:
- **Small overlaps** (under about 15%): the neighbouring split moves to make room and the
  others are placed again.
- **Large ones:** the board shows that tile with a warning outline, and the window stays
  where the app put it.

**How it's built.**
- **Detection:** `WindowTiler.place` returns actual frames. Compare them with the targets
  in `TilingCoordinator.place`.
- **Adjusting:** work out the needed split position from the actual size (`path(to:)` to
  find the parent split, then `settingPosition`), and place once more. Never loop.
- **Remembering:** a per-app minimum size cache (`[bundleID: CGSize]`) so later layouts
  account for it straight away. The board and the screen grips' drag limits read it too.

**Edge cases.**
- The fix can push a neighbour below its own minimum: accept the overlap and warn.
- Animated placement: compare after the final frame only.

## 15. Choosing where each marked window goes (S–M)

**How it works.** When several marked windows are dragged over a preset chip, the board
preview already shows them numbered in their slots. Using only the mouse:
- **Choosing the slot:** hovering a different slot of the chip puts the grabbed window
  there, as now.
- **Rotating the rest:** scrolling while over the chip rotates the other windows through
  the remaining slots. Scrolling steps through windows in the switcher, but that's
  pointless mid-drag, so it can be reused.
- The preview updates live, and releasing applies what's shown.

**How it's built.**
- **State:** `WindowDrag` gains `slotOffset: Int`, and `TilingBoard.applying` rotates the
  waiting windows by it. The preview recomputes when it changes.
- **Input:** `SwitcherController+Navigation.scrolled` checks `state.drag` and adjusts the
  offset instead of stepping.
- **Chips:** `PresetThumbnail` draws the numbers in each slot for the current assignment.

---

## Suggested order

1. **11 Per-preset ratios**: small, and it builds on the new editor.
2. **6 Rearranging tiles on the board**: the board is already up during sessions.
3. **12 Windows that won't fit**: quality work, worth doing early.
4. **15 Slot assignment** and **8 Monitor choice**.
5. **10 Workspaces**: the biggest piece, and it reuses most of the above.
