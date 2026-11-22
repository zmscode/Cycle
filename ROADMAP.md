# Tiling roadmap: ideas 5–15

Design notes for the next tiling features, written before building any of them. Each one
covers how it would work for you, how it would be built on what's there now (file names are
under `Sources/Cycle`), the edge cases, and a rough size: **S** is under a day, **M** is one
to two days, **L** is more. Questions that need your answer are marked **Decide**.

Since 0.1.4 the building blocks are:

- **`cycle.config`**, the settings file.
- **`layouts.json`**, the remembered layouts.
- **`TilingStore`**, which keeps remembered trees per display UUID, bound to the open windows.
- **`TilingCoordinator`**, which runs tiling between sessions.
- **The board preview**, a `WindowDrag.preview` layout drawn in place of the current one.

Most of the ideas below are new ways to produce a new `RiftLayout<CGWindowID>` and pass it
to `TilingCoordinator.apply`.

---

## 5. Drag the dividers on the board (M)

**How it works.** Hovering the line between two tiles on the board shows a resize cursor,
and dragging it moves the split. The tiles resize as you drag, and the real windows follow
when you let go (or live, if that's smooth enough). Double-clicking a divider resets it to
an even split.

**How it's built.**

- **Hit-testing:** RiftCore has `RiftDividerDrag` and `RiftGeometry` divider rects. Read
  `geometry(in:metrics:).dividers` (or the equivalent) and hit-test the pointer against
  each divider, scaled to the board and widened to about 8pt so it can be grabbed.
- **Where it runs:** this needs the board on screen without a window being dragged, so
  it depends on idea 6's "board mode" (below). With only the drag-time board, there's no
  free hand to drag a divider.
- **Applying it:** `layout.settingPosition(_:ofSplit:)`, clamped by `minimumPaneSize`,
  then `TilingCoordinator.apply`.
- **Saving it:** split positions are already part of the remembered tree, so a resized
  layout is saved automatically.

**Edge cases.**

- Apps with a minimum width will clamp. After placing, compare the actual frames (the
  tiler already reports them) and snap the divider back if the app refused.
- Live resizing calls AX for two or more windows on every mouse move. Throttle it to about
  30Hz, or only move the windows on release.

**Decide.** Should windows move live while you drag (feels great but can stutter in
Electron apps), or only when you let go?

## 6. Board mode: rearrange tiled windows on the board (M)

**How it works.** At the moment the board only appears while you drag a card. Board mode
shows it on its own:

- **Opening it:** hold ⌥ while the switcher is open, or click a small "board" button
  beside the gear.
- **Using it:** you drag tiles on the board itself. Drop a tile on another to swap them,
  or on an edge to move it there; dividers can be dragged (idea 5).
- **Closing it:** Esc or ⌥ again.

**How it's built.**

- **The overlay:** `TilingOverlayPanel` gains a mode that takes mouse events instead of
  letting them pass through (`ignoresMouseEvents = false`) while board mode is on.
- **Dragging tiles:** a tile drag is the same `WindowDrag`, started from the board instead
  of a card, so `TilingBoard.target(at:)`, `dropping`, the preview and `apply` all work
  unchanged. Dropping a tiled window on another already swaps them through Rift's
  `moving(_:to:zone:)`.
- **Extras:** right-clicking a tile shows "Remove from layout" and "Close window".

**Edge cases.**

- Board mode must keep the session open even in hold-to-switch mode, the way settings do,
  by setting `sessionMode = .onConfirmation`.
- The board covers part of the screen. It's already positioned to avoid the switcher.

## 7. Undo (S)

**How it works.** ⌘Z while the switcher is open undoes the last tiling change: a drop, a
⌘-number preset, a divider drag or a gap fill. ⇧⌘Z redoes it. The board briefly shows what
was undone.

**How it's built.**

- **History:** `TilingStore` keeps a short history per display, about 20 entries of
  `(remembered tree, frames of every window in it)`.
- **Recording:** every `save`, `windowClosed` and `appQuit` pushes onto it.
- **Undoing:** restore the tree, rebind the windows still open, then `place` each window
  at its old frame. The old frames are used because the spacing may have changed since,
  and the user expects things back exactly as they were.
- **Keys:** add `Key.z` in `SwitcherController+Keyboard`, checked with the modifier held.

**Edge cases.**

- A window in the history may have closed since. Skip it, and its neighbours take the
  space.
- History lives only while Cycle runs. It isn't worth persisting.

## 8. Choosing a monitor while dragging (M)

**How it works.** With two or more displays, the board shows a small strip of display
thumbnails, with the current one highlighted. Hovering one for about 0.4s switches the
board to that display. Dropping on it tiles there, moving windows across displays.

**How it's built.**

- **Boards:** `WindowDrag.screen` becomes mutable. Switching rebuilds `board` with
  `TilingBoard(layout: tiling.layout(for: other), visible: other.visibleFrameTopLeft, …)`
  but keeps the overlay on the switcher's screen. The board is a drawing, so it can show
  any display.
- **Saving:** `TilingStore.save` already takes a window out of the other displays'
  layouts, so moving windows between displays needs no extra work.
- **Layout:** `BoardPlacement` gets a `displays: [DisplayChip]` row above the card.

**Edge cases.**

- Displays with different scales or aspect ratios. The board takes the target display's
  aspect ratio, so the card is resized when you switch.
- AX positions are in global coordinates, which works for any arrangement.

## 9. Custom presets (M)

**How it works.**

- **Building one:** in settings, a "＋" chip opens a small editor. You start with one
  slot, click a slot's edge to split it there, drag dividers, and click a slot to delete
  it. You name the preset and save it.
- **From the board:** "Save as preset" (in board mode) turns the current layout into a
  preset.
- **Using them:** custom presets sit beside the built-in ones, can be turned on or off,
  and get ⌘ numbers.

**How it's built.**

- **Storage:** a preset is a `RiftLayout<Int>`, which is already Codable. `cycle.config`
  gains `tiling.customPresets: [{ "name": …, "layout": <Rift tree>, "mainSlot": 0 }]`.
- **Code changes:** `TilingPreset` changes from a closed enum to a struct, with the
  built-in presets as static values. `tiling.presets` keeps naming presets by id: the
  built-in names, plus `custom:<uuid>`.
- **Board mode:** "Save as preset" maps the live layout's window ids to 0…n in
  `slotOrder`: top left first, or the largest slot first.
- **Editing by hand:** a hand-written preset in the file is validated with Rift's
  `validate()`. An invalid one is skipped and logged.

**Decide.** Should a custom preset's split positions be fixed, or should it get a "main
share" like Main + Stack? I'd keep them fixed and use idea 11 for ratios.

## 10. Workspaces (L)

**How it works.** A workspace is a named set of windows and where they go, across every
display: for example "Coding" is the editor left, the terminal bottom right and the
browser top right.

- **Saving:** "Save Workspace…" in board mode or the settings panel.
- **Applying:** from the settings panel, a new `⌘⇧1…` shortcut in the switcher, or the
  command line (`Cycle --workspace Coding`). Cycle launches any apps that aren't running,
  waits for their windows, then tiles them.

**How it's built.**

- **Storage:** a workspace is `{ name, displays: [displayUUID: RiftLayout<RememberedSlot>] }`.
  That's the same shape as `layouts.json`, so `TilingStore`'s binding rules (same app and
  title, else same app) already find the windows. It goes in its own `workspaces.json`.
- **Launching:** `NSWorkspace.openApplication(at:configuration:)` for each bundle id with
  no running app. Then the coordinator's existing `scheduleRestore` retry loop binds the
  windows as they appear.
- **Missing displays:** a display in the workspace that isn't connected gets merged onto
  the main display, or skipped. **Decide** which.
- **More than one window:** apps that open one window when the workspace wants two would
  need an AppleScript "make new window" or similar. Out of scope: leave the slot empty.

**Edge cases.**

- Applying while windows are already tiled: the workspace replaces those displays'
  layouts (undo from idea 7 covers mistakes).
- Titles change over time (browser tabs), so matching falls back to the app alone.

## 11. Per-preset ratios (S)

**How it works.** Each preset that has a natural main slot gets its own ratio instead of
the single "Main Window" slider:

- **Thirds:** a 33/33/33, 50/25/25 or 25/50/25 picker.
- **Main + Stack and Centre:** their own sliders.
- **Halves:** a 50/50, 60/40 or 70/30 picker.
- **Editing:** in settings, clicking an enabled preset's thumbnail shows its options.

**How it's built.**

- **Storage:** `cycle.config` → `tiling.ratios: { "thirds": [0.5, 0.25, 0.25],
"mainStack": 0.65, … }`.
- **Code changes:** `TilingPreset.layout(mainShare:)` becomes `layout(ratios:)`, and the
  global `mainShare` becomes the default for presets with no ratio of their own.
- **Free once idea 9 lands:** custom presets carry their ratios in their tree.

## 12. Windows that won't fit their slot (S–M)

**How it works.** Some apps have a minimum size, or ignore resizes (some Electron apps and
System Settings). After tiling, Cycle notices a window that came out bigger than its slot:

- **Small overlaps** (under about 15%): the neighbouring split moves to make room, and the
  other windows are placed again.
- **Large ones:** the board shows that tile with a warning outline the next time it's
  open, and the window stays where the app put it.

**How it's built.**

- **Detection:** `WindowTiler.place` already returns the actual frames. Compare each with
  its target in `TilingCoordinator.place`.
- **Adjusting:** `RiftMetrics.minimumPaneSize` is global, so compute the needed split
  position from the actual width or height (`settingPosition` on the parent split, found
  with `path(to:)`), then place once more. Never loop more than once.
- **Remembering:** a per-app minimum size cache (`[bundleID: CGSize]`), kept in memory, so
  the next layout accounts for it straight away.
- **The board:** reads the cache and marks tiles that won't fit before you drop.

**Edge cases.**

- Moving the split may push a neighbour below its own minimum. In that case, accept the
  overlap and show the warning.

## 13. Animated moves (M)

**How it works.** Windows glide to their new frames over about 150ms instead of jumping.
There's an "Animate" toggle, and it respects Reduce Motion.

**How it's built.**

- **Moving:** `WindowTiler.setFrame` interpolates position and size in about 8 steps on
  its queue, using an ease-out curve.
- **Speed:** AX calls take about 2–10ms each in most apps and 30ms or more in Electron, so
  measure the first step and skip straight to the end if it's slow.
- **Order:** all windows animate together, interleaved step by step rather than one after
  another. The serial tiler queue handles one step for every window per frame.
- **Setting:** `cycle.config` → `tiling.animate: true`.

**Edge cases.**

- Apps that redraw slowly smear as they move. The per-app speed check keeps those snapping.
- Avoid AXEnhancedUserInterface flicker by keeping it off for the whole animation, not
  each step.

**Decide.** This is the riskiest polish item, because results vary from app to app.
Should I prototype it behind a setting that's off by default?

## 14. Faster marking (S)

**How it works.**

- **⌘-click a card:** toggles its mark, like Space.
- **⇧-click a card:** marks every window from the last marked one to this one, in the
  order shown.
- **Right-click a group header** (grouped layout): marks or unmarks all of that app's
  windows.
- **⌘A while the switcher is open:** marks every visible tileable window, and ⌘A again
  clears them. Handy with a filter: type "term" then ⌘A.

**How it's built.**

- **Clicks:** the click handlers in `SwitcherController+Mouse` read
  `NSEvent.modifierFlags`, and ⌘ or ⇧ there routes to `toggleMark` or a new `markRange`.
- **Group headers:** `AppGroupHeader` gets a right-click via the existing `DragTracker`
  `onRightClick` (using a header pointer id) or `.contextMenu`.
- **⌘A:** in `SwitcherController+Keyboard`, guarded so it doesn't conflict with typing,
  since ⌘ is held anyway in hold-to-switch mode.

**Edge cases.**

- ⌘-click competes with the click-to-switch action: ⌘ is down in hold-to-switch mode, so
  a plain ⌘-click must still switch. Use ⇧⌘-click for marking, or only treat ⌘-click as
  marking in confirm mode. **Decide.**

## 15. Choosing where each marked window goes (S–M)

**How it works.** When several marked windows are dropped on a preset chip, the board
preview (idea 1, now built) shows the numbered windows in their slots. Before releasing,
pressing Tab rotates the assignment: window 1 moves to the next slot and everyone shifts.
Pressing 1–9 swaps the window you grabbed with that number. The preview updates live, and
releasing applies what's shown.

**How it's built.**

- **State:** `WindowDrag` gains `slotOffset: Int`, and `TilingBoard.applying` rotates
  `slotOrder` by it. The preview already redraws on `target` changes, so it also needs to
  recompute when `slotOffset` changes.
- **Keys:** Tab and the digits are read in `SwitcherController+Keyboard` while
  `state.drag != nil`. Tab currently steps the selection, which is pointless mid-drag, so
  it can be reused.
- **Chips:** the chip thumbnail draws small numbers in each slot (in `PresetThumbnail`)
  for the current assignment.

---

## Suggested order

1. **7 Undo** and **14 Faster marking** are small, and they make everything else safer
   and quicker to try.
2. **6 Board mode**, then **5 Dividers**: board mode is the base that dividers, "save as
   preset" and workspaces build on.
3. **11 Ratios**, then **9 Custom presets**: both are mostly `cycle.config` plus a
   settings editor.
4. **12 Windows that won't fit**: quality work that's worth doing before animations.
5. **15 Slot assignment** and **8 Monitor choice**.
6. **10 Workspaces**: the biggest piece, and it reuses most of the above.
7. **13 Animation**: last, behind a setting.
