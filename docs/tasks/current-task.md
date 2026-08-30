# Current Task

Updated: 2026-08-30
Task ID: `TASK-015`
Status: `PLANNED`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-015-oh-my-code-identity`
Expected baseline: `99056a51c3e25bfbd05758371eb47ec7085917bb`
Pull request: not opened

## Outcome

Make the checkout launch as `oh-my-code` through the public `ohc` command,
while retaining `novim-dev` as a one-release compatibility alias and keeping
the installed upstream `novim` command independent.

## In scope

- Add an executable `bin/ohc` launcher with the existing robust repository-root
  resolution, external-working-directory support, symlink support, Neovim
  argument forwarding, and isolated config/data/state/cache paths.
- Move visible checkout-launcher identity and help/version output to
  `oh-my-code`/`ohc` while retaining a clearly labeled `novim-dev` alias.
- Update focused launcher/smoke documentation and tests for the public command
  and compatibility boundary.

## Out of scope

- Startup animation (`TASK-016`).
- Public archive, installer, and release workflow (`TASK-017`).
- README redesign and demo assets (`TASK-018`).
- GitHub repository rename, version bump, tag, GitHub Release, and hosted
  installer verification (`TASK-019`).
- Internal `config/nvim/lua/novim/` namespace migration.
- Changes to `bin/novim`, installed `novim`, normal Neovim config, upstream
  synchronization, or accepted workbench/editor behavior.

## Acceptance criteria

- [ ] `bin/ohc` is executable and launches bundled `config/nvim` from another
      working directory and through a symlink.
- [ ] `ohc --version` and `ohc --help` identify `oh-my-code`/`ohc`, preserve
      current checkout version semantics, and exit without an interactive
      editor. `novim-dev --version` and `novim-dev --help` remain usable and
      explicitly identify compatibility status.
- [ ] `ohc --headless` forwards Neovim arguments and resolves all writable
      runtime paths below the checkout's isolated boundary without network
      activity.
- [ ] Existing file arguments and Neovim flags continue to pass through both
      command names without changing workbench behavior.
- [ ] Focused smoke coverage includes public command, compatibility alias,
      external cwd, symlink invocation, isolated paths, and installed `novim`
      invariance; the existing pre-release package suite remains green.
- [ ] `bin/novim`, installed `novim`, and the user's normal Neovim config are
      byte/output invariant before and after validation.

## Guardrails

- Preserve accepted workbench, editor, Source Control, clipboard, and
  unsaved-buffer behavior.
- Do not silently overwrite unrelated existing commands or install paths.
- Local validation is not hosted release evidence.

## Relevant files

- `bin/novim-dev`
- new `bin/ohc`
- `tests/run_smoke_tests.sh`
- `tests/test_smoke.lua`
- `tests/run_package_tests.sh`
- `docs/architecture.md`
- `docs/LOCAL_DISTRIBUTION.md`

## Required validation

- `bash -n bin/ohc bin/novim-dev tests/run_smoke_tests.sh`
- `./bin/ohc --version` and `./bin/ohc --help`
- `./tests/run_tests.sh`
- `git diff --check`
- explicit before/after checks for `bin/novim` and installed `novim` when
  present

The implementer must stop at a local handoff commit on this branch. No push,
PR, repository rename, or release action is part of implementation.
