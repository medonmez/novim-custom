# Current Task

Updated: 2026-08-30
Task ID: `TASK-010`
Status: `READY_FOR_REVIEW`
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

Status: `READY_FOR_REVIEW` (local implementer handoff; not yet reviewed or
accepted)

### Change summary

- `settings.lua`: added a version-tolerant `layout` settings shape
  (`{ files = { left }, diff = { left, middle } }`) validated by
  `sanitize_width`/`sanitize_layout` (non-numeric, NaN/inf, out-of-range, and
  unknown values fall back to defaults), `layout` loading in `M.load`,
  layout preservation in `M.save`, and `M.set_layout` (per-view wholesale
  merge; theme and dot-folder settings preserved; a write failure leaves the
  in-memory layout unchanged).
- `workbench.lua`: captures effective pane widths after a completed drag and
  before every view/layout teardown (`pane_drag_end`, `set_view`, `M.close`),
  stores logical column counts only (no window/buffer IDs) through the
  existing settings boundary, and restores saved geometry on Diff re-entry and
  on workbench launch, clamped to the current terminal width and the
  15/20/20 minimums (`apply_files_geometry`/`apply_diff_geometry`). Restore
  runs after the final focus switch because 'winwidth' (20) would otherwise
  re-widen a freshly-focused pane narrower than 20 columns. Storage failures
  are pcall-swallowed and never disturb the live layout. Files and Diff
  geometry are saved and restored independently.

### Files changed

- `config/nvim/lua/novim/settings.lua`
- `config/nvim/lua/novim/workbench.lua`
- `tests/test_workbench.lua`
- `tests/test_smoke.lua`
- `docs/tasks/current-task.md` (this handoff)

### Validation performed (local evidence only)

- `./tests/run_tests.sh` — three consecutive runs, each exit 0: 38/38
  integration tests, offline package suite PASS, 8/8 smoke tests (new
  `test_smoke_pane_layout_persistence_and_clamping` included). Repeat runs
  prove restore determinism across launches sharing persisted state.
- Headless `loadfile` syntax checks on `workbench.lua`, `settings.lua`,
  `test_workbench.lua`, `test_smoke.lua` via `bin/novim-dev --headless`: pass.
- `bash -n` on `bin/novim-dev`, `bin/novim-dev-package`,
  `tests/run_tests.sh`, `tests/run_smoke_tests.sh`,
  `tests/run_package_tests.sh`: pass.
- `python3 -m json.tool docs/project.json`: pass.
- `bin/novim-dev --version` → `novim-dev 0.1.7-dev` (NVIM v0.12.5);
  `/Users/mert/.local/bin/novim --version` → `novim 0.1.7`; installed release
  untouched.
- `git diff --check`: clean. Diff scan found no network, plugin, installed
  release writes, or Git mutation commands.

### Acceptance-criterion evidence

- Files resize → Diff → Files restores the saved divider position exactly:
  `tests.test_pane_layout_persists_across_view_switches_independently`
  (equality assertions at the same terminal width).
- Independent Diff boundary resizes → Files → Diff restore both boundaries
  without resetting either to startup defaults: same test (boundary-1 and
  boundary-2 equality assertions) plus the smoke test.
- Closing and reopening the workbench restores both layouts from the isolated
  settings file, including a cold settings cache and on-disk JSON
  verification: `tests.test_pane_layout_persists_across_workbench_reopen`.
- Missing/malformed/non-numeric/impossible geometry falls back to the
  built-in layout while theme and dot-folder settings survive, and a
  settings-write failure does not crash or corrupt the live layout:
  `tests.test_pane_layout_malformed_values_fall_back_safely`.
- Narrow-terminal clamping (120 → 70, plus extreme 50): saved widths clamp to
  the current terminal, 15/20/20 minimums hold, panes fill the terminal
  exactly, and a terminal that cannot fit three usable panes degrades to the
  built-in start: `tests.test_pane_layout_clamps_to_narrow_terminal`
  (headless `vim.o.columns` manipulation; the local environment permits it).
- Files/Diff independence: each drag writes only its own view's geometry
  (asserted in the integration and smoke tests).
- Pre-existing behavior intact: all 34 prior integration tests and 7 prior
  smoke tests pass with unchanged assertions (three width-sensitive tests pin
  a clean layout start via `reset_saved_layout` because restore-on-open now
  honors persisted geometry).

### Residual risks / known gaps

- Stored geometry is global rather than per-checkout, matching the task's
  "restore on a later workbench launch"; a different checkout at a narrower
  terminal clamps safely.
- A Diff left pane narrower than 'winwidth' (20) is reachable because drags
  bypass focus-time enforcement; restore deliberately re-applies widths after
  focus so the saved effective position survives, matching what the user last
  saw.
- The TASK-009 review observation (stale `state.win_middle` after a manual
  middle-pane `:q`) stays deferred; capture/restore guard against an invalid
  middle window.

### Commit

HEAD (handoff commit)
