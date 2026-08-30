# Current Task

Updated: 2026-08-30
Task ID: `TASK-011`
Status: `PLANNED`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-011-settings-focus-close`
Expected baseline: `a039f29` (`origin/main`)
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

Status: `PLANNED` (awaiting implementation on the recorded isolated branch)

Implement TASK-011 only after reading this task, the repository instructions,
and the latest review. Return a local `READY_FOR_REVIEW` handoff; do not push,
open a PR, merge, or mark the task accepted as the implementer.
