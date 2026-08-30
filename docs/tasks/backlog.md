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
| 10 | TASK-010 | Persist independent Files and Git Diff pane geometry across view switches and workbench launches | ACCEPTED | TASK-009 (accepted) |
| 11 | TASK-011 | Make Settings focus-driven with arrow navigation, context-aware theme changes, Space toggles, and a mouse close affordance | ACCEPTED | TASK-010 (accepted) |
| 12 | TASK-012 | Add a VS Code-like Git Source Control layout with current changes above a selectable full current-branch graph and two-endpoint comparison | ACCEPTED | TASK-011 (accepted) |
| 13 | TASK-013 | Add file-level staging, unstaging, commit-message input, and local staged commit | CHANGES_REQUESTED | TASK-012 (accepted) |

TASK-013 is the only actionable current task. Its accepted product direction
is recorded in ADR-004 and `docs/tasks/current-task.md`; no later task may
absorb its features incidentally.

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
- TASK-011 was accepted after local review and merge as PR #19. Its focus
  state remains session-only, and the close affordance uses the existing safe
  Settings cleanup path.
- `TASK-012` was accepted after local review and merge as PR #21. The full
  current-branch Source Control graph, two-endpoint read-only comparison, and
  current changes/history split are now part of the mainline surface.

## New task notes

- `TASK-010` is accepted. It stores logical per-view geometry, not transient
  Neovim window or buffer IDs, survives view switching and a later local
  launch, and clamps safely to the current terminal width.
- `TASK-011` is accepted. Up/Down changes only the selected Settings control,
  Left/Right changes theme only while the theme row is selected, Space
  activates the selected control, `Esc` closes immediately, and the panel
  exposes a top-right mouse close control.
- `TASK-012` is accepted. It keeps current changes/status above a full
  current-branch graph with merge nodes, supports two explicit comparison
  endpoints, and remains read-only without checkout.
- `TASK-012` should use a horizontal split inside the left Git area: current
  changes/status above and current-branch history below. It must not silently
  check out or mutate a branch. The full reachable ancestry graph, merge nodes,
  and two user-selected revision/location endpoints are accepted in ADR-004.
- `TASK-013` is now the only actionable planned slice. It is limited to
  file-level local stage/unstage/commit with a user-entered message. Push,
  pull, fetch, merge, rebase, branch checkout, discard, amend, remote
  synchronization, credentials, and partial-line staging remain excluded.

- `TASK-013` remains the only actionable slice after local review of candidate
  `c90f863`: restore the history-pane `N` mapping, render write notices when
  the changes list is empty, and preserve selected paths across commit
  refresh. No PR or remote delivery was attempted.

- `TASK-012` is accepted with the full ancestry graph reachable from the
  current branch, including merge nodes, and two revision/location endpoints
  for a read-only comparison. Its default remains working tree versus `HEAD`;
  selecting history does not check out a branch.

## Preserved boundaries

- No plugin dependency is required for these slices.
- No source, credentials, or Git metadata leave the machine by default.
- The installed `novim`, normal Neovim configuration, and upstream-facing
  command remain unchanged.
- Local tests and local branches are not hosted, production, recovery, or
  customer-acceptance evidence.
