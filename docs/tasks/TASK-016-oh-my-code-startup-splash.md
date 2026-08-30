# TASK-016 — oh-my-code interactive startup splash

- Status: `PLANNED`
- Delivery policy: `LIGHTWEIGHT`
- Base branch: `main`
- Expected baseline: `8457dbf0e0274d642e09481a01fa6b9d777b9377`
- Task branch: `task/TASK-016-oh-my-code-startup-splash`
- PR target: `origin/main`
- Dependency: `TASK-015` (accepted in PR #27)
- Follow-up: `TASK-017` public package and installer

## Outcome

Give an interactive `ohc` launch a short, recognizable oh-my-code opening
screen while keeping every non-interactive and diagnostic invocation immediate
and script-safe. The one-release `novim-dev` compatibility alias must retain
the same no-delay controls and remain usable.

## Context

`TASK-015` established `ohc` as the public checkout launcher and preserved
`novim-dev` as an alias. ADR-006 accepts a one-second animated ANSI splash only
for an interactive TTY launch, with explicit `--no-animation` and
`OHC_NO_ANIMATION=1` controls. Help, version, headless, piped, and test
launches must not wait for or render the splash.

## In scope

- Add the bounded one-second ANSI startup splash to the normal interactive
  launch path of `bin/ohc`.
- Keep `--no-animation` as a launcher control and honor
  `OHC_NO_ANIMATION=1`; neither control may be forwarded to Neovim.
- Apply the same eligibility and disable behavior to `bin/novim-dev` so the
  compatibility alias does not diverge in script-sensitive startup behavior.
- Extend focused smoke/PTY coverage for interactive display, duration bound,
  disable controls, piped/headless/help/version bypasses, and argument
  forwarding.
- Update the launcher and local distribution documentation without claiming
  hosted or release evidence.

## Out of scope

- Public archive naming, installer behavior, or GitHub Release asset
  generation (`TASK-017`).
- README redesign, architecture graphic, screenshots, or demo GIF (`TASK-018`).
- Version bump, GitHub repository rename, tag creation, GitHub Release, or
  hosted installer verification (`TASK-019`).
- Internal `config/nvim/lua/novim/` namespace migration.
- Changes to the workbench/editor/Source Control behavior, package allowlist,
  installed `novim`, normal Neovim configuration, or upstream synchronization.

## Acceptance criteria

- [ ] A normal interactive TTY launch of `ohc` renders the intended ANSI
      splash for approximately one second and then starts Neovim normally.
- [ ] `--no-animation` and `OHC_NO_ANIMATION=1` suppress the splash; the
      explicit flag is consumed by the launcher and is not passed to Neovim.
- [ ] Help, version, headless, piped, and test launches do not render or wait
      for the splash, and existing flags/files remain correctly forwarded.
- [ ] `novim-dev` preserves compatibility behavior and the same no-delay and
      disable controls without changing its one-release identity boundary.
- [ ] Focused smoke/PTY coverage verifies the interactive and bypass paths,
      while the full integration, offline package, and existing public `ohc`
      smoke suites remain green.
- [ ] `bin/novim`, installed `novim`, and the user's normal Neovim
      configuration remain byte/output invariant before and after validation.

## Guardrails

- Keep startup delay strictly bounded to the accepted one-second interactive
  path; never delay automation or diagnostics.
- Do not add a network call, credential flow, plugin dependency, or background
  process for the splash.
- Preserve the isolated config/data/state/cache boundary and all accepted
  workbench, editor, Source Control, clipboard, and unsaved-buffer behavior.
- Keep local validation distinct from hosted release evidence.

## Relevant files and discovery hints

- `bin/ohc`
- `bin/novim-dev`
- `tests/run_smoke_tests.sh`
- `tests/test_smoke.lua`
- `docs/architecture.md`
- `docs/LOCAL_DISTRIBUTION.md`
- ADR-006 public identity and release boundary

## Required validation

- `bash -n bin/ohc bin/novim-dev tests/run_smoke_tests.sh`
- Direct TTY/PTY checks for the splash, elapsed duration, and all bypass and
  disable controls.
- `./bin/ohc --version`, `./bin/ohc --help`, and headless/file passthrough
  checks for both command names.
- `./tests/run_tests.sh`
- `git diff --check`
- Explicit before/after checks for `bin/novim` and installed `novim` when
  present, plus the normal Neovim configuration.

The implementer must stop at a local handoff commit on this branch. No push,
PR, repository rename, or release action is part of implementation.
