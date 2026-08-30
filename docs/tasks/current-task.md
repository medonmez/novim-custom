# Current Task

Updated: 2026-08-30
Task ID: `TASK-010`
Status: `PLANNED`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-010-pane-layout-persistence`
Expected baseline: `94a8d0b` (`origin/main`)
Pull request: `NOT_OPEN`

## Outcome

Keep the user's chosen pane geometry stable when switching between the Files
and Git Diff views, and restore those independent layouts when the workbench is
reopened. A resize in Files must not reset the Files split; a resize in Git
Diff must not reset either Diff boundary.

## Context

TASK-008 added mouse-resizable panes and TASK-009 extended the Diff view to
three areas. The current implementation still assigns fixed starting widths
when `workbench.open()` creates the Files split and when
`ensure_diff_layout()` creates the middle Diff pane. Switching views therefore
recreates part of the layout and loses the user's previous geometry. The
existing isolated settings file persists theme and dot-folder visibility but
does not yet contain pane geometry.

## In scope

- Persist a separate Files layout value for the left/right split.
- Persist separate Diff layout values for the left/middle and middle/right
  boundaries, or an equivalent representation that restores both boundaries
  without losing the untouched pane.
- Capture the effective widths after a completed drag and before a view/layout
  is torn down; restore them when that view is entered again.
- Restore the values from the existing isolated `novim-dev` settings path on a
  later workbench launch. Do not store window IDs or absolute buffer IDs.
- Clamp saved values to the current terminal width and the existing minimums
  (Files: left 15/right 20; Diff: left 15/middle 20/right 20), including when
  the terminal is narrower or wider than the terminal used to save them.
- Keep Files and Diff geometry independent. Resizing one view must not alter
  the saved geometry of the other view.
- Treat missing, malformed, non-numeric, or impossible geometry as a safe
  default and keep the workbench usable; preserve unrelated settings.
- Add deterministic fixture coverage for Files resize → Diff → Files, both
  Diff boundary resizes → Files → Diff, persisted reload, and narrow-terminal
  clamping where the local test environment permits it.

## Out of scope

- Settings focus/navigation redesign, the top-right Settings close control,
  or changes to theme and dot-folder control semantics; these belong to
  TASK-011.
- Git history, branch/commit selection, staging, commit-message input,
  committing, merge, rebase, push, pull, discard, or any other new Git
  operation; these belong to TASK-012/TASK-013 and remain outside TASK-010.
- Persisting project-tree expansion, selected files, cursor positions, or
  editor buffers.
- Plugin installation, network access, changes to the installed `novim`, or
  writes to the normal Neovim configuration.

## Acceptance criteria

- [ ] After dragging the Files divider, switching to Git Diff and back restores
      the Files divider to the saved effective position, subject only to
      integer rounding and current-terminal minimum clamping.
- [ ] After independently dragging both Diff boundaries, switching to Files
      and back restores both Diff boundary positions without resetting either
      one to the fixed startup defaults.
- [ ] Closing and reopening the workbench in the same checkout restores the
      last saved Files and Diff geometry from the isolated settings file.
- [ ] A changed terminal width never creates an invalid window or violates
      the existing 15/20/20 minimums; impossible saved values fall back safely.
- [ ] Theme and dot-folder settings remain intact when geometry is saved or
      loaded, and a settings-write failure does not crash or corrupt the
      in-memory layout.
- [ ] Existing mouse dragging in both directions, selection/navigation,
      three-area Diff rendering, lazy browsing, source editing handoff,
      read-only Git behavior, launcher isolation, and installed-release
      boundaries remain intact.
- [ ] The focused regression and full local suite pass, including
      `./tests/run_tests.sh`, relevant syntax checks, JSON validation, and
      `git diff --check`.

## Decision guardrails

- Use the existing isolated settings path and a version-tolerant settings
  shape; never write layout data to the user's normal Neovim configuration or
  the installed release paths.
- Store logical geometry, not transient Neovim window/buffer IDs. Recompute
  actual widths from the current layout and clamp before applying them.
- Preserve the current mouse contract: press on a visible divider, drag in
  either direction, release; no `E21`, invalid-window error, or accidental
  file/Git mutation.
- Keep layout persistence local and synchronous with the existing settings
  boundary; do not add file watching, background polling, network behavior, or
  a plugin dependency.
- Keep the implementation limited to pane geometry and its tests. Do not
  resolve the pending Git mutation/history decisions inside this task.
- All evidence is local evidence only; do not claim hosted, production,
  recovery, or customer acceptance.

## Relevant areas

- `config/nvim/lua/novim/settings.lua` — isolated settings load/save and safe
  fallback behavior.
- `config/nvim/lua/novim/workbench.lua` — layout creation, view switching,
  divider drag state, width clamping, and state diagnostics.
- `tests/test_workbench.lua` and `tests/test_smoke.lua` — deterministic
  workbench, settings, layout, and isolation regression coverage.
- `docs/architecture.md` and `docs/product/product.md` — current layout and
  persistence contracts.

## Required validation

- Add focused tests for independent Files/Diff persistence across view
  switches, workbench reopen, malformed/missing geometry, and minimum clamps.
- Run `./tests/run_tests.sh` and the relevant standalone smoke checks.
- Run Lua/shell syntax checks as applicable, `python3 -m json.tool
  docs/project.json`, both development/installed version checks, and
  `git diff --check`.
- Inspect the real diff for scope creep, settings corruption, installed
  release writes, network/plugin additions, and Git mutation commands.

## Blockers and dependencies

- Dependency: TASK-009 is accepted on `origin/main`; the verified planning
  baseline is `94a8d0b`.
- No product decision blocks TASK-010.
- TASK-011, TASK-012, and TASK-013 remain successor backlog slices with
  accepted direction recorded in ADR-004; they must not be implemented as part
  of TASK-010.

## Implementation handoff

Implement exactly this task on `task/TASK-010-pane-layout-persistence`, add
the focused regression coverage, create one local handoff commit, and stop for
`$project-orchestrator` review. Do not push, open a PR, merge, or mark the task
accepted as the implementer.
