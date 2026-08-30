# TASK-017 — oh-my-code public package and safe installer

- Status: `PLANNED`
- Delivery policy: `LIGHTWEIGHT`
- Base branch: `main`
- Expected baseline: `9904324ba79c666be46e6efe92e932eb1ea8e2d4`
- Task branch: `task/TASK-017-oh-my-code-package-installer`
- PR target: `origin/main`
- Dependency: `TASK-016` (accepted in PR #29)
- Follow-up: `TASK-018` README and real demo assets

## Outcome

Turn the pre-release local package helper into a public `oh-my-code` package
and a safe installer that targets only the accepted `oh-my-code` paths. Prepare
deterministic GitHub Release asset generation without publishing a release or
changing the installed upstream `novim` command.

## Context

The current `bin/novim-dev-package` is an offline, allowlist-based helper for
the pre-release `novim-custom-<VERSION>.tar.gz` archive and stages only
`bin/novim-dev`. The legacy root `install.sh` still downloads and replaces
`~/.local/share/novim` and `~/.local/bin/novim`; it is not a safe installer for
the accepted public product. ADR-006 fixes the public install root at
`~/.local/share/oh-my-code`, the primary link at `~/.local/bin/ohc`, and the
one-release `novim-dev` compatibility boundary.

## In scope

- Replace or extend the package helper with a public, deterministic archive
  named `oh-my-code-<VERSION>.tar.gz`, rooted at `oh-my-code-<VERSION>`.
- Allowlist the public `bin/ohc` launcher, the one-release `bin/novim-dev`
  compatibility launcher, the complete `config/nvim/` tree, `VERSION`, `LICENSE`,
  and `THIRD_PARTY_LICENSES.md`; exclude `bin/novim`, Git metadata, runtime
  state, credentials, environment files, private data, and special files.
- Replace the legacy public installer path with a networked installer that
  downloads only the declared `oh-my-code` Release asset, validates its archive
  root and contents, stages extraction safely, and installs only below
  `~/.local/share/oh-my-code`.
- Create `~/.local/bin/ohc` only when absent or already pointing into the
  managed `oh-my-code` root. Handle the `novim-dev` compatibility link with the
  same absent-or-owned rule. Refuse unrelated existing files, links, nonempty
  targets, path traversal, and archive content outside the allowlist.
- Preserve `~/.local/bin/novim`, `~/.local/share/novim`, the normal Neovim
  configuration, and all upstream synchronization boundaries. The installer
  must not invoke `novim --update`, install Neovim through a package manager,
  use `sudo`, or silently overwrite unrelated paths.
- Replace the stale release workflow so it builds the public archive and a
  checksum/release asset from `VERSION` and `bin/ohc` without editing or
  packaging `bin/novim`. The workflow is preparation for TASK-019; this task
  does not create a tag or publish a GitHub Release.
- Update package tests and `docs/LOCAL_DISTRIBUTION.md` for public archive,
  installer, alias, collision, and installed-`novim` boundaries. Keep the
  upstream-facing documentation scope explicit; README redesign remains
  TASK-018.

## Out of scope

- GitHub repository rename, version bump to `v1.0.0`, tag creation, GitHub
  Release publication, or fresh hosted installer download verification
  (`TASK-019`).
- README redesign, architecture graphic, screenshots, or real terminal demo
  capture (`TASK-018`).
- Changes to `config/nvim/lua/novim/`, workbench/editor/Source Control behavior,
  the installed `novim` command, the user's normal Neovim configuration, or
  upstream synchronization.
- Package-manager distribution, Homebrew formulae, automatic Neovim
  installation, update/uninstall commands, or background services.

## Acceptance criteria

- [ ] A public package command creates a byte-identical
      `oh-my-code-<VERSION>.tar.gz` on repeated runs and refuses to overwrite
      an existing output.
- [ ] The archive contains both public/compatibility launchers and the complete
      bundled runtime/license allowlist, has one safe root, and contains no
      `bin/novim`, Git metadata, `.dev-*` state, credentials, traversal entry,
      link, or special file.
- [ ] The installer downloads only the declared public Release asset, validates
      it before extraction, installs below `~/.local/share/oh-my-code`, and
      creates `~/.local/bin/ohc` plus the permitted `novim-dev` compatibility
      link without touching unrelated paths.
- [ ] Collision and failure cases are fail-closed: unrelated existing command
      files/links, nonempty or symlinked install roots, malformed archives,
      traversal entries, and failed downloads leave the target and temporary
      state safe and unchanged.
- [ ] An installed temporary package launches through `ohc`, retains the
      one-release `novim-dev` identity and splash bypass controls, uses isolated
      config/data/state/cache paths, and never targets installed `novim`.
- [ ] Release workflow assets build from the public package and `VERSION`,
      produce a checksum, and do not mutate or package `bin/novim`; the workflow
      is not executed as a hosted release in this task.
- [ ] Focused package/installer tests, the full local suite, shell/YAML syntax
      checks, and `git diff --check` pass. Before/after snapshots prove that
      installed `novim`, the normal Neovim configuration, and unrelated links
      remain unchanged.

## Guardrails

- Treat archive validation and install-path ownership as security boundaries;
  reject ambiguity rather than overwriting or guessing.
- Network access is limited to the explicitly declared public Release asset in
  the installer. Normal `ohc`/`novim-dev` startup remains network-free.
- Keep local package/install evidence separate from hosted release and customer
  acceptance evidence.
- Preserve the current one-release `novim-dev` compatibility boundary while
  making `ohc` the only primary public command.

## Relevant files and discovery hints

- `bin/novim-dev-package`
- `install.sh` and `docs/install`
- `.github/workflows/release.yml`
- `tests/run_package_tests.sh`
- `docs/LOCAL_DISTRIBUTION.md`
- `docs/architecture.md`
- `docs/repository.md`
- ADR-006 public identity and release boundary

## Required validation

- `bash -n` for the package helper and installer; YAML syntax/action structure
  validation for the release workflow when an available local validator exists.
- Repeated local package creation, archive manifest inspection, checksum
  verification, and temporary-root install tests.
- Negative tests for collisions, symlinks, nonempty targets, malformed and
  traversal archives, failed downloads, and preservation of installed `novim`
  and normal Neovim paths.
- `./tests/run_package_tests.sh`, `./tests/run_smoke_tests.sh`,
  `./tests/run_tests.sh`, and `git diff --check`.

The implementer must stop at a local handoff commit on this branch. No
repository rename, tag, GitHub Release, or hosted installer acceptance is part
of implementation.
