# Tiling roadmap

Design notes for tiling ideas still to build. Every item in the previous roadmap is now
built: per-preset ratios (11), rearranging tiles on the board (6), windows that won't fit
(12), choosing where marked windows go (15), choosing a monitor while dragging (8) and
workspaces (10). The README describes how each works.

## Constraints

- **⌘ is held for the whole session.** In hold-to-switch mode the modifier stays down from
  opening the switcher to choosing a window, so any shortcut is really ⌘-something, and
  most ⌘ chords mean something to the system or to Cycle already.
- **Typing filters.** Letters, digits and the like go into the search, which is a core
  feature, so they can't become shortcuts either. (⌘1–⌘9 for presets and Space to mark
  before typing are the only exceptions, and they should stay the only ones.)
- **So new features use the mouse.** The board, grips, chips, right-click and scrolling
  are the place for them, plus settings and `cycle.config` for anything set once.

## Loose ends from the last round

- **Workspace chips on the board.** Workspaces apply from settings and the command line.
  A row of workspace chips on the board, and a "Save as Workspace" button there, would
  make them reachable mid-session. The board's hit layer (`BoardTileView`) can take the
  clicks.
- **Disconnected displays in a workspace** are skipped. Merging them onto the main
  display is the alternative, if skipping turns out to lose too much.
- **Minimum sizes are kept in memory only.** Persisting `TilingCoordinator.minimumSizes`
  (beside `layouts.json`) would let the first layout after a restart fit straight away.
  The grips' drag limits could also read it, so a divider can't be dragged past an app's
  minimum.
- **Tile hover feedback.** The board shows an open-hand cursor over tiles; a light
  highlight on the tile under the pointer would make picking one up clearer.
