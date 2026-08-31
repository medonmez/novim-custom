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
| 13 | TASK-013 | Add file-level staging, unstaging, commit-message input, and local staged commit | ACCEPTED | TASK-012 (accepted) |
| 14 | TASK-014 | Add automatic mouse-copy in editable files and direct Esc return to same-file Preview | ACCEPTED | TASK-013 (accepted) |
| 15 | TASK-015 | Rebrand the public product as oh-my-code and add the primary `ohc` launcher with a one-release compatibility alias | ACCEPTED | TASK-014 (accepted) |
| 16 | TASK-016 | Add a one-second interactive-TTY startup splash with explicit no-animation controls | ACCEPTED | TASK-015 (accepted) |
| 17 | TASK-017 | Package oh-my-code, add the safe public installer, and generate GitHub Release assets | ACCEPTED | TASK-015, TASK-016 (accepted) |
| 18 | TASK-018 | Replace the upstream README with a discoverable oh-my-code guide and real terminal demo assets | PLANNED | TASK-015, TASK-016, TASK-017 (accepted) |
| 19 | TASK-019 | Run the strict release candidate gate, rename the GitHub repository, and publish `v1.0.0` | PROPOSED | TASK-015 through TASK-018 (accepted) |

TASK-001 through TASK-017 are accepted. The public release direction is
accepted in ADR-006; only TASK-018 is currently actionable.

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
- `TASK-013` was accepted after local review and merge as PR #23. It provides
  file-level local stage/unstage and local staged commit with a transient
  user-entered message, while keeping push, pull, fetch, merge, rebase,
  branch checkout, discard, amend, remote synchronization, credentials, and
  partial-line staging excluded. The review corrections restored history-pane
  `N`, clean-state write notices, and selected-path preservation across commit
  refresh.

- `TASK-014` was accepted after local review and merge as PR #25. It is limited to local
  editable-file mouse selection auto-copy, direct `Esc` return from Insert,
  Normal, and Visual modes to that file's Preview, explicit confirmation for
  unsaved buffers, and bottom editor statusline guidance. Preview/Diff
  read-only panes, keyboard-only auto-copy, auto-save, and remote clipboard
  synchronization remain excluded.

- `TASK-012` is accepted with the full ancestry graph reachable from the
  current branch, including merge nodes, and two revision/location endpoints
  for a read-only comparison. Its default remains working tree versus `HEAD`;
  selecting history does not check out a branch.

- `TASK-014` was accepted after local review and merge as PR #25. It provides
  editable-file mouse selection auto-copy to the local system clipboard,
  direct all-mode `Esc` return to the same file's Preview, explicit
  unsaved-buffer confirmation with in-memory recovery, and statusline guidance.
  Preview/Diff read-only panes, keyboard-only auto-copy, auto-save, and remote
  clipboard synchronization remain excluded.

- `TASK-015` was accepted after local review and merge as PR #27 at
  `8457dbf`. It establishes the `ohc` public launcher and keeps `novim-dev` as
  a one-release compatibility alias without changing installed `novim`.
- `TASK-016` was accepted after local review and merge as PR #29 at
  `9904324`. It adds the one-second interactive-TTY splash to both checkout
  launchers, consumes `--no-animation`, honors `OHC_NO_ANIMATION=1`, and must
  not delay help, version, headless, piped, or test launches. Its task record
  contains the local review closure and acceptance evidence.
- `TASK-017` owns public archive naming, installer paths, safe alias handling,
  and release workflow assets. Normal `ohc` launch remains network-free.
- `TASK-017` was accepted after the same-task ShellCheck correction at
  `369dedb` and follow-up PR #32, merged at `bad06b69`. The review records a
  separately repaired installed-`novim` probe incident; hosted release work
  remains excluded.
- `TASK-018` owns the public README, Mermaid/terminal explanation, and a real
  `ohc` terminal demo capture with no private project data.
- `TASK-019` is the only task authorized to perform the hosted repository
  rename, tag `v1.0.0`, GitHub Release creation, and fresh installer download
  verification. It uses the strict release gate.

## Preserved boundaries

- No plugin dependency is required for these slices.
- No source, credentials, or Git metadata leave the machine by default.
- The installed `novim`, normal Neovim configuration, and upstream-facing
  `bin/novim` command remain unchanged. `ohc` is a separate public command.
- Local tests and local branches are not hosted, production, recovery, or
  customer-acceptance evidence.
