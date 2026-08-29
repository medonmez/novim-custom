# Current Task

Updated: 2026-08-30
Task ID: `TASK-009`
Status: `PLANNED`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-009-three-area-diff`
Expected baseline: `6621cd84362bd1975106b8b1ba2e012d0682823a` (`origin/main`)
Pull request: `NOT_OPEN`

## Outcome

Complete the next workbench slice: render the Git Diff view as a three-area
side-by-side read-only diff — left changed-file list, middle old-file pane,
right new-file pane — with refresh on entry, while preserving the accepted
read-only, isolated, terminal-first derivative boundary.

## Context

The Git Diff view currently pairs the left changed-file list with a single
right diff pane. The accepted product direction (ADR-003) calls for a
three-area layout: the changed-file list stays visible beside separate
old-file and new-file panes, and the diff refreshes on entry. TASK-008's
themes, settings key help, immediate close, and divider drag are accepted on
`origin/main` and must remain intact while this rendering slice is
implemented.

## In scope

- Render the Diff view with three visible areas: left changed-file list,
  middle old-file pane, right new-file pane, per the accepted
  `acceptedProductDirection.diffLayout` (no unified fallback).
- Refresh the diff rendering on every entry into the Diff view so changed
  files and content reflect the current working tree versus `HEAD`.
- Keep the changed-file list visible and navigable beside the old/new panes;
  selecting an entry updates both content panes.
- Preserve readable handling for binary, deleted, renamed, and untracked
  files: a sensible textual state or placeholder instead of broken output.
- Extend the accepted divider-drag behavior to the visible boundaries between
  the three areas with sensible minimum widths and no `E21`/invalid-window
  failure.
- Keep existing Files view, lazy browser, settings/themes behavior, source
  preview/editing, read-only Git commands, and navigation intact.
- Add deterministic tests for the three-area layout, entry refresh,
  per-entry old/new rendering, special-file handling, boundary dragging
  between three panes, and existing regression contracts.

## Out of scope

- Git mutation of any kind; diff stays working-tree-versus-`HEAD` read-only.
- Any change to project-browser traversal, themes, or settings behavior;
  TASK-007 and TASK-008 are accepted.
- Plugin dependencies, network access, background polling, installed
  `novim` changes, or changes to the normal Neovim configuration.
- Diff editing, staging, conflict resolution, or merge-tool workflows.

## Acceptance criteria

- [ ] The Diff view renders three visible areas — left changed-file list,
      middle old-file pane, right new-file pane — with no unified fallback.
- [ ] Entering the Diff view refreshes the changed-file list and diff content
      against the current working tree and `HEAD`.
- [ ] Selecting a changed file updates the old and new panes while the
      changed-file list stays visible and navigable.
- [ ] Binary, deleted, renamed, and untracked files render readably (clear
      state text or placeholder; no broken pane output).
- [ ] Visible boundaries between the three areas respond to mouse drag with
      minimum widths, preserving valid windows and no `E21`.
- [ ] TASK-007 lazy browsing, TASK-008 themes/settings/Esc-close/drag
      behavior, source preview/editing, and read-only Git behavior remain
      intact.
- [ ] No Git mutation, network action, plugin dependency, installed-release
      write, or settings/browser regression is introduced.

## Decision guardrails

- Keep all Git commands read-only (`status`, `diff`, `show` class) and avoid
  network actions by default.
- Render diff content with application-owned code in the bundled Neovim
  configuration; no new runtime dependencies.
- Preserve the isolated settings/runtime paths and the accepted theme system.
- Keep the accepted divider-drag semantics (press, drag, release, clamped
  minimum widths) when extending to the third boundary.
- Do not modify `/Users/mert/.local/share/novim`, the installed `novim`
  command, or the normal Neovim configuration.
- Keep this slice limited to Diff view rendering; do not begin any further
  backlog item.

## Relevant areas

- `config/nvim/lua/novim/workbench.lua` — Diff view layout, three-pane
  rendering, navigation, and mouse handling.
- `config/nvim/lua/novim/git.lua` — read-only diff/status content retrieval
  for refresh-on-entry.
- `tests/test_workbench.lua` and `tests/test_smoke.lua` — deterministic
  layout, refresh, special-file, drag, and regression coverage.
- `docs/architecture.md` — the accepted diff-view contract once implemented.

## Required validation

- Add and run focused tests for the three-area layout, refresh on entry,
  per-entry old/new rendering, binary/deleted/renamed/untracked handling,
  three-pane boundary dragging with minimum widths, and existing regression
  contracts.
- Run `./tests/run_tests.sh`, including the offline package and regression
  smoke suites.
- Run Lua/shell syntax checks as applicable, both version checks, JSON
  validation, and `git diff --check`.
- Verify the candidate diff contains no Git mutation, network, credential,
  plugin, installed-release, TASK-007/TASK-008 regression, or out-of-scope
  change.
- Keep all evidence local; do not claim hosted, production, recovery, or
  customer acceptance.

## Blockers and dependencies

- No product decision is open for this slice; the layout and refresh-on-entry
  decisions are recorded in ADR-003 and `docs/project.json`.
- Dependency: TASK-008 is accepted on `origin/main` at
  `6621cd84362bd1975106b8b1ba2e012d0682823a`.

## Implementation handoff

Status: `PLANNED`

Implement only TASK-009 on the recorded isolated branch. Return a local
handoff with the candidate commit and observed validation; do not push, open a
PR, merge, or mark the task accepted as the implementer.
