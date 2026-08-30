# Current Task

Updated: 2026-08-31
Task ID: `TASK-016`
Status: `READY_FOR_REVIEW`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-016-oh-my-code-startup-splash`
Expected baseline: `8457dbf0e0274d642e09481a01fa6b9d777b9377`
Pull request: not opened
PR target: `origin/main`
Dependency: `TASK-015` (accepted in PR #27)

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
- Update launcher and local distribution documentation without claiming
  hosted or release evidence.

## Out of scope

- Public archive naming, installer behavior, or GitHub Release asset
  generation (`TASK-017`).
- README redesign, architecture graphic, screenshots, or demo GIF (`TASK-018`).
- Version bump, GitHub repository rename, tag creation, GitHub Release, or
  hosted installer verification (`TASK-019`).
- Internal `config/nvim/lua/novim/` namespace migration.
- Changes to workbench/editor/Source Control behavior, package allowlist,
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

## Implementation handoff

Implemented by `$stateless-implementer` on 2026-08-31. Status:
`READY_FOR_REVIEW`. All evidence below is local evidence on this checkout and
machine; it is not hosted, production, recovery, or customer-acceptance
evidence.

### Change summary

- `bin/ohc` and `bin/novim-dev` now render a bounded (approximately one second,
  by construction 5 x 0.12s + 2 x 0.20s sleeps) ANSI "ohc" splash on the
  interactive TTY launch path before `exec nvim`. Eligibility is strict:
  stdout must be a TTY, `--headless` anywhere in the arguments disables it, and
  help/version exit before the splash code. The launcher consumes
  `--no-animation` (removed from the forwarded arguments, never passed to
  Neovim) and honors `OHC_NO_ANIMATION=1`. No network, credential, plugin, or
  background-process addition; the isolated config/data/state/cache boundary,
  version semantics, and workbench/editor behavior are untouched.
- `tests/run_smoke_tests.sh` gained Step 5: (5.1) a `vim.v.argv` assertion
  proving `--no-animation` is never forwarded, (5.2) splash-free help/version
  checks for both commands, and (5.3) a python3 PTY matrix run for both
  launchers covering interactive rendering, the duration bound, and the
  flag/env/headless/piped bypasses. Later steps renumbered 6/7; no existing
  assertion changed.
- `docs/architecture.md` documents the splash eligibility/disable behavior and
  the new smoke step; `docs/LOCAL_DISTRIBUTION.md` documents the splash and
  its script-safe bypasses for local verification. No hosted or release claims
  were added.

### Files changed

- `bin/ohc`
- `bin/novim-dev`
- `tests/run_smoke_tests.sh`
- `docs/architecture.md`
- `docs/LOCAL_DISTRIBUTION.md`
- `docs/tasks/current-task.md` (this handoff)

`tests/test_smoke.lua` needed no change: the splash is launcher-side, and all
Lua-side smoke launches are headless and therefore splash-free by design.

### Validation commands and results

- `bash -n bin/ohc bin/novim-dev tests/run_smoke_tests.sh` — passed.
- Direct PTY probes (python3, 40x120 PTY, `:qa!` quit): interactive final
  splash frame arrived at 0.863s (`ohc`) and 0.853s (`novim-dev`) with exit 0;
  `--no-animation` and `OHC_NO_ANIMATION=1` runs produced no splash frames and
  first Neovim output at <= 0.03s; `--headless -c qall!` under a real TTY
  stdout exited in 0.04s with no splash; piped `ohc -es` exited in 0.03s with
  no splash.
- `./tests/run_smoke_tests.sh` — passed twice, all steps: CLI identities,
  external-cwd/symlink resolution, installed-`novim` independence, file
  passthrough, new Step 5 splash coverage, 9/9 headless Lua smoke tests,
  cleanup, and product-tree integrity.
- `./bin/ohc --version` → `oh-my-code (ohc) 0.1.7-dev` / `powered by NVIM
  v0.12.5`; `./bin/ohc --help` → unchanged public identity text;
  `./bin/novim-dev --version` → `novim-dev 0.1.7-dev (custom checkout)` with
  the alias note (identity unchanged).
- Headless/file passthrough for both command names with a fixture file
  (`argc()==1`) — passed for `./bin/ohc` and `./bin/novim-dev`; smoke Steps
  3.1/3.2/4 cover the same paths from external directories and symlinks.
- `./tests/run_tests.sh` — exit 0: 59/59 integration tests, offline package
  and upstream-boundary suite passed, 9/9 smoke tests.
- `git diff --check` — clean (no whitespace errors).

### Acceptance-criterion evidence

- Interactive TTY splash then normal Neovim start: smoke Step 5.3 interactive
  mode for both launchers (splash rendered, final frame 0.60-1.80s bound met at
  ~0.86s, exit 0 after `:qa!`).
- `--no-animation` / `OHC_NO_ANIMATION=1` suppress the splash and the flag is
  consumed: smoke Step 5.1 (`vim.v.argv` assertion) and Step 5.3 flag/env
  modes (no splash bytes, first output <= 0.03s) for both launchers.
- Help, version, headless, piped, and test launches neither render nor wait:
  smoke Step 5.2 (help/version splash-free), Step 5.3 headless-under-TTY
  (0.04s) and piped (0.03s) modes, and the unchanged passing Step 1/2 CLI
  identity checks; test launches remain headless/piped (Step 6 suite green).
- `novim-dev` compatibility preserved with the same controls: identical
  eligibility/disable logic applied and verified for `novim-dev`; `--version`/
  `--help` identities unchanged (Step 2 assertions pass unchanged).
- Focused coverage present and all suites green: new smoke Step 5;
  `./tests/run_tests.sh` exit 0 with 59/59 integration, offline package suite,
  and 9/9 smoke tests.
- `bin/novim`, installed `novim`, and the normal Neovim configuration remain
  invariant: SHA-256 of `bin/novim` (`cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321`)
  and `/Users/mert/.local/bin/novim` (`5955e1f2c223d13b024e263dca412f1acb96b69d4168b26b3fa3f7b14c1de26a`)
  identical before and after validation; installed output `novim 0.1.7` /
  `powered by NVIM v0.12.5` unchanged; no `~/.config/nvim` exists before or
  after.

### Residual risks and known gaps

- The PTY duration window [0.60s, 1.80s] around the ~1.0s construction could
  trip on an extremely loaded machine (test-only flake risk; the launcher's
  sleeps are fixed).
- Splash redraw relies on cursor-up support; on terminals without it the
  frames stack visually while timing and bypass behavior stay correct. The art
  wraps cosmetically below ~22 columns.
- The smoke-runner PTY matrix is skipped with a warning when `python3` is
  absent; direct PTY validation was performed on this machine.
- The splash mechanics are intentionally duplicated in both launchers because
  the pre-release package allowlist stages only `bin/novim-dev`; consolidation
  belongs to the `TASK-017` package migration.

### Commit

`HEAD (handoff commit)` on `task/TASK-016-oh-my-code-startup-splash` — one
local commit staging only the files listed above; not pushed, no PR, tag, or
release action.
