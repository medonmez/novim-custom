# Current Task

Updated: 2026-08-31
Task ID: `TASK-017`
Status: `READY_FOR_REVIEW`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-017-oh-my-code-package-installer`
Expected baseline: `9904324ba79c666be46e6efe92e932eb1ea8e2d4`
Pull request: `https://github.com/medonmez/novim-custom/pull/31` (`MERGED`; follow-up PR pending)
PR target: `origin/main`
Dependency: `TASK-016` (accepted in PR #29)

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

## Implementation handoff

Implementer: `$stateless-implementer` (fresh context). Status:
`READY_FOR_REVIEW`. Branch:
`task/TASK-017-oh-my-code-package-installer`. The recorded expected baseline
`9904324` is an ancestor of the branch point; the branch starts at the
orchestrator planning merge `ced52a3` (PR #30) that created this task file,
so implementation began from the branch as checked out.

### Change summary

- Replaced the pre-release package helper with the public
  `bin/oh-my-code-package` (the old `bin/novim-dev-package` is removed;
  ADR-006 requires package identities to move to the `oh-my-code`/`ohc`
  identity). It builds the deterministic, byte-identical
  `oh-my-code-<VERSION>.tar.gz` rooted at `oh-my-code-<VERSION>/`, refuses to
  overwrite an existing output, and stages the allowlist: `bin/ohc`,
  one-release `bin/novim-dev`, the complete `config/nvim/` tree, `VERSION`,
  `LICENSE`, `THIRD_PARTY_LICENSES.md`. It rejects Git metadata, `.dev-*`
  state, credential-like entries, links, and special files.
- Replaced the legacy upstream installer with the public networked
  `install.sh` (synced to `docs/install`). It downloads only the declared
  release asset `oh-my-code-<VERSION>.tar.gz` plus its `.sha256` companion,
  verifies the checksum, validates the archive fail-closed (single exact
  root, strict allowlist, no traversal/absolute/backslash entries, no links
  or special files, no forbidden entries, staged extraction with top-level
  and `VERSION`-identity checks), installs only below
  `~/.local/share/oh-my-code`, and creates `~/.local/bin/ohc` plus the
  one-release `~/.local/bin/novim-dev` link only when absent or already
  pointing into the managed root. It requires Neovim >= 0.8.0 and never
  installs Neovim, uses `sudo`, or runs `novim --update`. All checks run
  before any target mutation, and a rollback trap removes partial temporary
  state. Local validation overrides (`OHC_INSTALL_ARCHIVE`,
  `OHC_RELEASE_URL`) exist for offline fixture testing only.
- Replaced `.github/workflows/release.yml`: tag-push (`v*`) only, verifies
  the tag matches the checkout `VERSION`, builds the archive with
  `bin/oh-my-code-package`, verifies the manifest (including the absence of
  `bin/novim` and a `git diff --exit-code bin/novim` guard), generates the
  checksum asset, syncs `docs/install`, and attaches both assets. No release
  is created by this task; execution is TASK-019 scope.
- Rewrote `tests/run_package_tests.sh` for the public archive, installer,
  alias, collision, hostile-archive, failed-download, and invariance
  boundaries. Updated `docs/LOCAL_DISTRIBUTION.md`, `docs/architecture.md`,
  `docs/repository.md`, `docs/UPSTREAM_SYNC.md`, and mechanically fixed the
  README's package commands (README redesign remains TASK-018). Added
  `bin/oh-my-code-package` to the CI ShellCheck job.

### Review follow-up (2026-08-31)

The local review verdict `CHANGES_REQUESTED` (review record `b501186`,
candidate `705abb5`) required two corrections; both are applied on this same
task branch:

- P1 (source-symlink leak): `bin/oh-my-code-package` now validates the source
  tree before any copy or archive byte is produced. Required inputs
  (`bin/ohc`, `bin/novim-dev`, `VERSION`, `LICENSE`,
  `THIRD_PARTY_LICENSES.md`) must be regular non-symlink files; `bin`,
  `config`, and `config/nvim` must be real directories (not symlinks); and
  every entry of the recursive `config/nvim` tree must be a regular
  non-symlink file or a real directory. Anything else fails closed with no
  staging directory, no output file, and no archive bytes. The reviewer's
  probe (symlinked `bin/ohc` holding `private-source`) now fails and
  produces nothing.
- P2 (offline VERSION identity): `install_package` now stages the archive's
  `oh-my-code-<VERSION>/VERSION` into its temporary directory and compares
  the normalized content with the expected version immediately after the
  structural validation and before any target mutation; a mismatch fails
  closed with the target unchanged.

Regression coverage added to `tests/run_package_tests.sh`:

- "Package source-tree fail-closed validation": a symlinked `bin/ohc` and a
  symlinked `config/nvim` entry (each pointing at a `private-source` file)
  are each rejected with no output archive and no `.oh-my-code-package.*`
  temporary bytes; a clean-tree repackage afterwards stays byte-identical to
  the deterministic archive.
- "Offline helper: archive VERSION identity mismatch" plus a new
  `wrong-version` hostile fixture (correct root, all required entries,
  `VERSION` content `wrong-version`): the offline helper refuses it while a
  nonexistent target stays absent and an existing empty target stays empty,
  and the networked installer path refuses the same fixture in the
  hostile-archive loop with an unchanged sandbox HOME.

Validation re-run after the corrections (local evidence only):
`./tests/run_package_tests.sh` pass with the deterministic archive SHA-256
unchanged (`7b9062c70e462289e16f9db1f8ea4b0cb276d169f11693f678b31bf28a1b9a7e`);
`./tests/run_smoke_tests.sh` pass; `./tests/run_tests.sh` pass (59/59
integration tests plus package and smoke runners); `bash -n` on `install.sh`,
`bin/oh-my-code-package`, `bin/ohc`, `bin/novim-dev`,
`tests/run_package_tests.sh`, `tests/run_smoke_tests.sh`, and
`tests/run_tests.sh` all pass; release-workflow YAML parse and structural
checks pass; `git diff --check` is clean; `cmp install.sh docs/install` is
byte-identical (no installer change was required); `bin/novim` SHA-256 is
unchanged (`cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321`);
the installed `novim` launcher is currently mode 755, has the recorded
`5955e1f2...` target hash, and reports `novim 0.1.7`; during this session a
stray probe briefly overwrote it through its symlink. It was restored
byte-identically from the verified upstream v0.1.7 release asset before the
validation rerun. The normal Neovim configuration remains absent on this
machine and untouched. Files changed in this follow-up:
`bin/oh-my-code-package`, `tests/run_package_tests.sh`, and this handoff.
`install.sh` and `docs/install` are byte-identical to the reviewed candidate.

### Post-merge CI follow-up (2026-08-31)

Local review approved the corrected candidate and PR #31 was merged as
`f070a74`, but the unprotected target allowed merge while its only CI check
was still queued. The `shellcheck` job then failed on `install.sh:171` with
`SC1003` for the backslash-regex literal; `docs/install` has the same line.
The task is not accepted; the same task was fixed on this branch as follows.

Root cause: the installer searched the tar manifest with the single-quoted
BRE literal `'\\'`. ShellCheck 0.10 flags a single-quoted token that ends
with a backslash before the closing quote (`SC1003`, "Want to escape a
single quote?"). The identical construct also exists at
`bin/oh-my-code-package:226`; CI failed on `install.sh` first and never
reported the second file.

Fix: `grep -q '\\'` became `grep -qF "\\"` in `install.sh`, `docs/install`,
and `bin/oh-my-code-package`. The double-quoted `"\\"` is a one-character
fixed-string pattern, and `grep -F` matches any manifest line containing a
literal backslash exactly as the previous BRE `\\` pattern did (verified on
a backslash manifest and a clean manifest), so backslash path entries are
still rejected fail-closed before the allowlist loop. A focused `backslash`
hostile fixture (entry `oh-my-code-<VERSION>/ba\d.txt`) was added to
`tests/run_package_tests.sh` and wired into both the offline-helper and the
networked-installer refusal loops; it is rejected with no install root and
no escaped files. No archive layout, allowlist, VERSION-identity check,
workflow, launcher, or other accepted surface was touched.

Validation rerun after the fix (local evidence only, ShellCheck 0.10.0 —
the same version Ubuntu `apt-get install shellcheck` provides on the CI
runner): `shellcheck install.sh`, `shellcheck bin/oh-my-code-package`, and
`shellcheck bin/novim` (the exact CI file list) plus `shellcheck
docs/install` are all clean; `bash -n` passes on `install.sh`,
`bin/oh-my-code-package`, `bin/ohc`, `bin/novim-dev`, `bin/novim`,
`tests/run_package_tests.sh`, `tests/run_smoke_tests.sh`, and
`tests/run_tests.sh`; `cmp install.sh docs/install` is byte-identical;
`./tests/run_package_tests.sh` passes with the deterministic archive SHA-256
unchanged (`7b9062c70e462289e16f9db1f8ea4b0cb276d169f11693f678b31bf28a1b9a7e`);
`./tests/run_smoke_tests.sh` passes (9/9 headless regression included);
`./tests/run_tests.sh` passes (59/59 integration tests plus the package and
smoke runners); `git diff --check` is clean. Before/after invariance holds:
`bin/novim` remains
`cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321`, the
installed `novim` launcher remains
`5955e1f2c223d13b024e263dca412f1acb96b69d4168b26b3fa3f7b14c1de26a` reporting
`novim 0.1.7` (verified before any edit and re-verified after the suites),
and the normal Neovim configuration remains absent and untouched. Handoff
status returns to `READY_FOR_REVIEW` for the same TASK-017.
`$project-orchestrator` handles the follow-up review/traceability PR.

### Files changed

- `bin/oh-my-code-package` (new, replaces `bin/novim-dev-package`)
- `install.sh` (replaced) and `docs/install` (synced copy)
- `.github/workflows/release.yml` (replaced)
- `.github/workflows/ci.yml` (ShellCheck list)
- `tests/run_package_tests.sh` (rewritten)
- `docs/LOCAL_DISTRIBUTION.md`, `docs/architecture.md`,
  `docs/repository.md`, `docs/UPSTREAM_SYNC.md`, `README.md`
- `docs/tasks/current-task.md` (this handoff)

### Validation performed (local evidence only)

- `bash -n install.sh bin/oh-my-code-package tests/run_package_tests.sh
  tests/run_tests.sh tests/run_smoke_tests.sh bin/ohc bin/novim-dev`: pass.
- PyYAML parse plus structural checks of `.github/workflows/release.yml`
  (tag-only trigger, pinned actions, no `bin/novim` mutation or packaging in
  any run step, checksum asset present): pass.
- `./tests/run_package_tests.sh`: pass. Covers byte-identical repeated
  packaging (SHA-256 `7b9062c7...`), overwrite refusal, full manifest
  inspection, offline helper install, both launcher identities
  (`oh-my-code (ohc) 0.1.7-dev`, `novim-dev 0.1.7-dev (custom checkout)`),
  splash bypasses, isolated config/data/state/cache stdpaths, hostile
  fixtures (traversal, absolute path, symlink member, allowlist violation,
  malformed), sandboxed installer happy path, owned-link reuse, reinstall
  refusal, collisions (unrelated file, unrelated link, symlinked root,
  nonempty root, symlinked bin dir) all failing closed with unchanged
  targets, networked download over a local fixture server with exactly two
  GET requests (asset + checksum), checksum digest- and name-mismatch
  refusals, 404 and unreachable-host download failures leaving the sandbox
  unchanged, and before/after snapshots proving installed `novim`,
  `~/.local/share/novim`, the normal Neovim configuration, `~/.local/bin/ohc`,
  `~/.local/bin/novim-dev`, `bin/novim`, and the checkout (HEAD + status)
  are unchanged.
- `./tests/run_smoke_tests.sh`: pass (CLI identities, isolation, passthrough,
  PTY splash matrix with duration bound and all bypasses, 9/9 headless
  regression suite, cleanup verification).
- `./tests/run_tests.sh`: pass (Lua unit/integration suite, package suite,
  full smoke runner).
- `git diff --check`: clean.

### Acceptance-criterion evidence

| Criterion | Result | Evidence |
|---|---|---|
| Byte-identical `oh-my-code-<VERSION>.tar.gz`, overwrite refusal | PASS | `run_package_tests.sh` "Deterministic public package" section: `cmp` equality, equal SHA-256, refused second `package` call. |
| Allowlisted archive, one safe root, no forbidden entries | PASS | Manifest assertions plus hostile-fixture refusals in the same suite. |
| Installer downloads/validates declared asset, installs below `~/.local/share/oh-my-code`, creates both links | PASS | Networked fixture-server happy path (exactly two GETs) and sandboxed local-mode happy path with link-target assertions. |
| Fail-closed collisions and failures | PASS | Collision, symlink, nonempty, hostile-archive, checksum-mismatch, 404, and unreachable-host cases all fail with unchanged sandbox snapshots. |
| Installed temporary package launches through `ohc` with alias identity, bypass controls, isolated paths | PASS | Headless launches through the installed `bin/ohc` asserting identities, `--no-animation`/`OHC_NO_ANIMATION=1` bypasses, `stdpath` isolation, Workbench/Settings commands, and `.dev-*` directories. |
| Release workflow builds from `VERSION`/`bin/ohc`, checksum asset, no `bin/novim` mutation, not executed | PASS | Workflow structure validation in the package suite; no tag or release was created. |
| Focused tests, full suite, syntax checks, `git diff --check`, invariance snapshots | PASS | Commands and results recorded above. |

### Residual risks and notes

- The hosted installer URL default points at the accepted public target
  `medonmez/oh-my-code`; that repository/rename and the `v1.0.0` release do
  not exist yet, so a real hosted install is intentionally expected to fail
  until TASK-019. All installer evidence here is local fixture evidence.
- The installer supports local validation overrides
  (`OHC_INSTALL_ARCHIVE`, `OHC_RELEASE_URL`); they are documented as
  local-evidence paths and perform the same fail-closed validation.
- Reinstall over an existing root is refused by design (no in-place update;
  update/uninstall commands are out of scope).
- `readdir`-order determinism relies on the existing
  fixed-timestamp/ustar/gzip-normalization approach; archives are verified
  byte-identical on this machine, not yet on the CI runner.
- The Python fixture server and hostile-archive fixtures require `python3`;
  the YAML structure check skips with a notice if PyYAML is unavailable.

### Commit

Commit reference: HEAD (handoff commit) on
`task/TASK-017-oh-my-code-package-installer`; the ShellCheck follow-up
commit is the new branch head after the prior handoff commit `8c1617c`. No
push, pull request, repository rename, tag, or GitHub Release was performed.
