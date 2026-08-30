# TASK-015 — oh-my-code identity and `ohc` launcher

- Status: `PLANNED`
- Delivery policy: `LIGHTWEIGHT`
- Base branch: `main`
- Expected baseline: `99056a51c3e25bfbd05758371eb47ec7085917bb`
- Task branch: `task/TASK-015-oh-my-code-identity`
- PR target: `origin/main`
- Dependency: none
- Follow-up: `TASK-016` startup splash

## Outcome

Make the checkout launch as the public `oh-my-code` product through an
`ohc` command while preserving the installed upstream `novim` command and a
one-release `novim-dev` compatibility path. The launcher must retain the
existing robust root resolution and isolated Neovim runtime boundary.

## Context

The accepted public direction is recorded in
[ADR-006](../adr/ADR-006-oh-my-code-public-identity.md). The current checkout
still exposes `bin/novim-dev` as its derivative launcher, while `bin/novim`
and the installed `novim` release are separate upstream surfaces. This task
establishes the public command and identity before adding the splash, public
installer, README assets, and hosted release.

## In scope

- Add the executable `bin/ohc` public launcher.
- Move the checkout launcher identity and visible `--help`/`--version` output
  to `oh-my-code` and `ohc`, deriving the development suffix from `VERSION`.
- Keep `novim-dev` as a compatibility alias with the same configuration,
  data, state, cache, file-argument, symlink, and external-working-directory
  behavior. Its compatibility status must be visible rather than misleading.
- Keep checkout runtime paths isolated from the user's normal Neovim paths;
  the public launcher may use an oh-my-code-specific runtime prefix.
- Update focused launcher, smoke, and current project documentation so the
  new public command is the primary path and the compatibility boundary is
  explicit.

## Out of scope

- The one-second startup animation and its disable controls (`TASK-016`).
- Public package naming, networked installer behavior, or GitHub Actions
  release asset generation (`TASK-017`).
- README redesign, architecture graphic, screenshots, or demo GIF (`TASK-018`).
- Version bump, GitHub repository rename, tag creation, GitHub Release, or
  hosted installer verification (`TASK-019`).
- Renaming the internal `config/nvim/lua/novim/` module namespace.
- Any change to `bin/novim`, `~/.local/bin/novim`, `~/.local/share/novim`, the
  user's normal Neovim configuration, or upstream synchronization behavior.

## Acceptance criteria

- [ ] `bin/ohc` is executable and launches the bundled `config/nvim` from the
      repository root when invoked from another working directory or through a
      symlink.
- [ ] `ohc --version` and `ohc --help` identify `oh-my-code`/`ohc`, preserve
      the current checkout version semantics, and exit without starting an
      interactive editor. `novim-dev --version` and `novim-dev --help` remain
      usable as an explicitly labeled compatibility alias.
- [ ] `ohc --headless` forwards Neovim arguments and resolves configuration,
      data, state, and cache below the checkout's isolated runtime boundary;
      no normal launch performs a network action.
- [ ] Existing file arguments and Neovim flags continue to pass through both
      command names without changing workbench behavior.
- [ ] Focused smoke checks cover the public command, compatibility alias,
      external working directory, symlink invocation, isolated paths, and
      installed `novim` invariance. Existing package checks remain green until
      the package migration task replaces their pre-release identity.
- [ ] `bin/novim`, the installed `novim` command, and the user's normal
      Neovim configuration are byte/output invariant before and after the
      focused validation.

## Guardrails

- Preserve all accepted workbench, editor, Source Control, clipboard, and
  unsaved-buffer behavior.
- Do not silently overwrite an existing unrelated command or install path.
- Keep local validation distinct from the later hosted repository rename and
  `v1.0.0` release evidence.

## Relevant files and discovery hints

- `bin/novim-dev`
- new `bin/ohc`
- `tests/run_smoke_tests.sh`
- `tests/test_smoke.lua`
- `tests/run_package_tests.sh` (preserve its pre-release boundary)
- `docs/architecture.md`
- `docs/LOCAL_DISTRIBUTION.md`

## Required validation

- `bash -n bin/ohc bin/novim-dev tests/run_smoke_tests.sh`
- `./bin/ohc --version` and `./bin/ohc --help`
- `./tests/run_tests.sh`
- `git diff --check`
- explicit before/after checks for `bin/novim` and the installed `novim`
  command when present

The implementer must stop at a local handoff commit on this branch. No push,
PR, repository rename, or release action is part of implementation.
