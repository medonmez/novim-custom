# Backlog

Updated: 2026-08-30

Statuses: `PROPOSED`, `PLANNED`, `IN_PROGRESS`, `READY_FOR_REVIEW`,
`CHANGES_REQUESTED`, `BLOCKED`, or `ACCEPTED`.

| Priority | ID | Vertical slice | Status | Dependency |
|---:|---|---|---|---|
| 1 | TASK-001 | Run this checkout through an isolated `novim-dev` command without changing installed `novim` | ACCEPTED | None |
| 2 | TASK-002 | Inspect the working tree versus `HEAD` in a two-pane, mouse-resizable read-only workbench, including untracked files | ACCEPTED | TASK-001 (accepted) |
| 3 | TASK-003 | Browse project files with dot-folders hidden by default and a persistent settings toggle | ACCEPTED | TASK-002 (accepted) |
| 4 | TASK-004 | Open source files and move between file tree, changed files, and diff context | ACCEPTED | TASK-002, TASK-003 (accepted) |
| 5 | TASK-005 | Add local regression smoke tests for launcher, workbench layout, settings, and diff rendering | ACCEPTED | TASK-002 through TASK-004 (accepted) |
| 6 | TASK-006 | Package the local derivative and document a safe upstream sync procedure | ACCEPTED | TASK-005 (accepted) |
| 7 | TASK-007 | Start quickly with a root-only lazy project browser and session-only folder expansion | ACCEPTED | TASK-006 (accepted) |
| 8 | TASK-008 | Add six built-in themes, settings key help, immediate settings close, and reliable mouse pane resizing | ACCEPTED | TASK-007 (accepted) |
| 9 | TASK-009 | Render a three-area side-by-side read-only Git diff with refresh on entry | ACCEPTED | TASK-008 (accepted) |
| 10 | TASK-010 | Persist independent Files and Git Diff pane geometry across view switches and workbench launches | PLANNED | TASK-009 (accepted) |
| 11 | TASK-011 | Make Settings focus-driven with arrow navigation, context-aware theme changes, Space toggles, and a mouse close affordance | PROPOSED | TASK-010 (accepted) |
| 12 | TASK-012 | Add a VS Code-like Git Source Control layout with current changes above a selectable current-branch history | BLOCKED | TASK-011 (accepted); history decisions pending |
| 13 | TASK-013 | Add local staging, unstage actions, commit-message input, and local staged commit | BLOCKED | TASK-012 (accepted); Git mutation boundary pending |

TASK-010 is the only actionable current task. TASK-011 is the next bounded
successor. TASK-012 and TASK-013 are recorded for the requested Git direction
but cannot be implemented until the open history and mutation decisions are
resolved; no later task may absorb those features incidentally.

## Accepted task notes

- `TASK-002` through `TASK-009` preserve the initial local, read-only Git
  contract: no stage, commit, push, merge, rebase, discard, or plugin manager
  was introduced.
- The existing workbench has one Files boundary and two Diff boundaries, all
  with application-owned minimum-width clamps. TASK-010 must preserve those
  interaction guarantees while adding logical persistence.
- Settings currently persist theme and dot-folder visibility in isolated state;
  TASK-011 must preserve both values and make focus state visible and
  testable.

## New task notes

- `TASK-010` stores logical per-view geometry, not transient Neovim window or
  buffer IDs. It must survive view switching and a later local launch while
  clamping safely to the current terminal width.
- `TASK-011` must ensure Up/Down changes only the selected Settings control,
  Left/Right changes theme only while the theme row is selected, and Space
  activates the selected control. The Settings panel must visibly document
  `Esc` close and expose a top-right mouse close control.
- `TASK-012` should use a horizontal split inside the left Git area: current
  changes/status above and current-branch history below. It must not silently
  check out or mutate a branch. The exact history graph and commit-selection
  baseline are open decisions.
- `TASK-013` is intentionally blocked pending explicit confirmation that the
  first write-capable Git surface is limited to local stage/unstage/commit.
  Push, pull, merge, rebase, branch checkout, discard, amend, and remote
  synchronization remain excluded unless separately authorized.

## Preserved boundaries

- No plugin dependency is required for these slices.
- No source, credentials, or Git metadata leave the machine by default.
- The installed `novim`, normal Neovim configuration, and upstream-facing
  command remain unchanged.
- Local tests and local branches are not hosted, production, recovery, or
  customer-acceptance evidence.
