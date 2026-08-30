# Current Task

Updated: 2026-08-30
Task ID: `TASK-011`
Status: `IN_PROGRESS`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-011-settings-focus-close`
Expected baseline: `a63bd76` (`origin/main`)
Pull request: `NOT_OPEN`

## Outcome

Make the Settings panel behave like a focused option menu: one visible
selected-control indicator, Up/Down navigation only between controls,
context-aware Left/Right theme changes, Space activation, immediate `Esc`
close, and a visible top-right mouse close affordance.

## Context

The existing Settings panel persists the accepted theme and dot-folder
visibility controls and renders key help, but its interaction still behaves
like a freely navigable text buffer. The next usability slice should make the
focus model explicit without changing the existing setting meanings or the
already accepted pane-geometry persistence.

## In scope

- Add an in-memory selected-control model for the Settings controls and render
  a visible arrow or equivalent selected-control indicator.
- Make Up/Down move only between the actual controls, never through help text
  or other rendered informational lines.
- Make Left/Right change the theme only when the theme control is selected.
- Make Space activate the selected control, including the dot-folder toggle,
  while preserving the existing synchronous save/error behavior.
- Keep one-key `Esc` as an immediate close that restores workbench focus.
- Add a visible top-right close affordance that closes Settings through the
  same safe path when clicked with the mouse.
- Update the visible key help and deterministic tests to match the real
  Settings mappings and focus behavior.

## Out of scope

- Pane geometry persistence or Files/Diff layout behavior; TASK-010 is
  accepted and must remain intact.
- New themes, changed theme colors, changed dot-folder semantics, or settings
  storage migration.
- Git history, branch/revision comparison, staging, committing, or any other
  Git mutation; those remain TASK-012/TASK-013 scope.
- Plugin installation, network behavior, installed-release changes, normal
  Neovim configuration writes, or unrelated workbench redesign.

## Acceptance criteria

- [ ] Settings opens with exactly one selected control indicated visibly; the
      indicator moves between controls without selecting help text.
- [ ] Up/Down changes only the selected control, wraps or clamps consistently,
      and never moves the cursor through the rendered help section.
- [ ] Left/Right changes the theme only when the theme control is selected;
      it does not change the theme while another control is selected.
- [ ] Space activates the selected control, including dot-folder visibility,
      with successful changes persisted and failed writes reported without
      changing the effective in-memory value.
- [ ] One-key `Esc` closes Settings immediately, restores workbench focus, and
      remains documented in the visible help.
- [ ] A visible top-right mouse close affordance closes Settings and restores
      workbench focus without changing settings.
- [ ] Existing theme catalog, dot-folder behavior, pane geometry persistence,
      workbench navigation/resizing, read-only Git behavior, launcher
      isolation, and installed-release boundaries remain intact.
- [ ] Focused and full local validation pass, including
      `./tests/run_tests.sh`, relevant syntax checks, JSON validation, version
      checks, and `git diff --check`.

## Decision guardrails

- Keep Settings interactions application-owned and deterministic; do not make
  help text or other informational lines navigable controls.
- Reuse the existing settings persistence and error boundary. A failed write
  must leave the effective value and selected-control state coherent.
- Preserve the one-key `Esc` close contract and route keyboard and mouse close
  through one safe cleanup/focus-restoration path.
- Do not persist cursor/control focus unless a later task explicitly decides
  to do so; pane geometry remains logical and independent as accepted in
  TASK-010.
- Do not add network behavior, plugins, Git mutation, installed-release
  writes, or writes to the normal Neovim configuration.
- All evidence is local evidence only; do not claim hosted, production,
  recovery, or customer acceptance.

## Relevant areas

- `config/nvim/lua/novim/settings_ui.lua` — Settings controls, focus state,
  keyboard mappings, close affordance, and help rendering.
- `config/nvim/lua/novim/settings.lua` — existing validated persistence and
  write-failure boundary.
- `config/nvim/lua/novim/workbench.lua` — Settings launch/focus restoration
  and preserved pane/view contracts.
- `config/nvim/lua/novim/keymaps.lua` — canonical visible key-help mappings.
- `tests/test_workbench.lua` and `tests/test_smoke.lua` — deterministic focus,
  keyboard, mouse-close, persistence, and regression coverage.

## Required validation

- Add focused tests for selected-control rendering, Up/Down focus movement,
  theme-only Left/Right behavior, Space activation, keyboard close, and mouse
  close affordance, including failed settings writes.
- Run `./tests/run_tests.sh`, including package and regression smoke suites.
- Run Lua/shell syntax checks as applicable, `python3 -m json.tool
  docs/project.json`, both version checks, and `git diff --check`.
- Inspect the real diff for pane-geometry regression, settings corruption,
  network/plugin additions, Git mutations, installed-release writes, and
  scope creep.

## Blockers and dependencies

- Dependency: TASK-010 is accepted on `origin/main` at `a039f29`.
- No product decision blocks TASK-011; the interaction contract is accepted
  in the successor brief in `docs/product/product.md`.
- TASK-012 and TASK-013 remain successor slices and must not be implemented as
  part of TASK-011.

## Implementation handoff

Status: `READY_FOR_REVIEW`

### Change summary

`settings_ui.lua` now keeps an in-memory selected-control model
(`CONTROL_ORDER = { "dotfiles", "theme" }`, never persisted). Exactly one
visible `▶` indicator marks the selected row; Up/Down (and j/k) move focus
only between the two controls with consistent wraparound and never move the
buffer cursor through the rendered help section. Space/Enter activate the
selected control (dot-folder toggle or next-theme cycle); `t` remains a
direct dot-folder toggle. Left/Right (and h/l/[/]) change the theme only
while the theme control is selected and are inert otherwise. One-key `Esc`
still closes immediately through the unchanged `M.close()` path, and a new
right-aligned `Close [x]` affordance on the title row closes through the
same path when clicked (new `M.handle_click(line, column, winid)` hit-test,
also covering control-row clicks). Existing synchronous save/error behavior,
the settings persistence boundary, and all pane-geometry code are reused
unchanged. `keymaps.lua` settings help entries were rewritten to match the
real mappings in both directions. `M.close()` clears only its own state.

### Files changed

- `config/nvim/lua/novim/settings_ui.lua` — focus model, activation,
  theme-only arrows, mouse close affordance, focus-aware rendering.
- `config/nvim/lua/novim/keymaps.lua` — settings help entries updated to
  the real focus-model mappings.
- `tests/test_workbench.lua` — `buffer_map_callback` helper plus four new
  focused regression tests.
- `docs/tasks/current-task.md` — this handoff.

### Validation commands and results (local evidence only)

- `./tests/run_tests.sh` — PASS: 42/42 integration tests, offline package
  suite passed, 8/8 smoke tests, zero fixture residue.
- `luajit -bl` on `settings_ui.lua`, `keymaps.lua`, `test_workbench.lua` —
  PASS (Lua syntax).
- `bash -n` on `bin/novim-dev`, `bin/novim-dev-package`, and all three test
  runners — PASS (shell syntax).
- `python3 -m json.tool docs/project.json` — PASS.
- Version checks: `bin/novim-dev --version` → `novim-dev 0.1.7-dev (custom
  checkout)`; installed `/Users/mert/.local/bin/novim --version` →
  `novim 0.1.7` (installed release untouched); in-checkout upstream launcher
  `bin/novim --version` → `novim 0.1.0` (vendored upstream version string).
- `git diff --check` — PASS.
- Diff inspection: changes limited to the four task-owned files; no
  pane-geometry, settings-storage, network, plugin, Git-mutation, or
  installed-release changes.

### Acceptance-criterion evidence

| Criterion | Result | Evidence |
|---|---|---|
| Opens with exactly one visible selected control; indicator never selects help | PASS | `tests/test_workbench.lua` `test_settings_focus_indicator_rendering_and_movement`: opens with one `▶` on the dot row; headless render dump shows one indicator, `selected=dotfiles` |
| Up/Down changes only the selected control, wraps consistently, never moves cursor through help | PASS | Same test: Down/Up wrap dotfiles↔theme, exactly one indicator after each move, cursor position unchanged, indicator always above the help section; real `<Up>`/`<Down>` mapping callbacks asserted |
| Left/Right changes theme only when theme control is selected | PASS | `test_settings_arrow_theme_only_and_space_activation`: theme unchanged after Left/Right on dotfiles control; theme cycles tokyo_night→nord→tokyo_night with persistence once the theme control is selected |
| Space activates the selected control incl. dot-folder toggle, preserving synchronous save/error behavior | PASS | Same test: Space cycles theme and toggles dot-folder visibility with immediate persistence; `test_settings_focus_survives_failed_settings_writes`: blocked settings path renders the error, effective value and selected control stay coherent |
| One-key `Esc` closes immediately, restores workbench focus, remains documented | PASS | Existing `test_settings_single_esc_close_restores_workbench_focus` (unchanged, passing); help entry `q / Esc` still rendered via `keymaps.settings` |
| Visible top-right mouse close affordance closes through the same safe path without changing settings | PASS | `test_settings_mouse_close_affordance`: `Close [x]` rendered flush right on the title row; click closes, restores workbench focus, leaves theme/dot-folder values unchanged; off-control clicks never close |
| Existing theme catalog, dot-folder behavior, pane geometry, workbench contracts, launcher isolation, installed-release boundaries intact | PASS | Full 42/42 + 8/8 suites; `workbench.lua`, `settings.lua`, `themes.lua` untouched; version checks unchanged |

### Residual risks

- The mouse close hit-test is verified through `M.handle_click` with
  explicit coordinates plus the wired `<LeftMouse>` mapping; a real PTY
  mouse click on the button itself was not exercised headlessly (consistent
  with prior TASK-002 PTY-level mouse verification).
- `j`/`k` previously moved the free cursor inside the settings buffer; they
  now drive control focus instead. This is the intended focused-menu
  behavior, but it changes pre-existing incidental j/k cursor movement.
- Focus selection is intentionally session-only and never persisted, per
  the decision guardrails.

### Commit reference

HEAD (handoff commit)
