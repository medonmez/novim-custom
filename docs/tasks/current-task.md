# Current Task

Updated: 2026-08-30
Task ID: `TASK-015`
Status: `READY_FOR_REVIEW`
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

## Implementation handoff

Status: `READY_FOR_REVIEW`
Updated: 2026-08-30

### Change summary

The checkout now launches as the public `oh-my-code` product through the new
executable `bin/ohc`, which reuses the proven `novim-dev` launch mechanics:
repository-root resolution across symlinks and external working directories,
Neovim argument forwarding, and the same isolated `.dev-data`/`.dev-state`/
`.dev-cache` runtime boundary with `config/nvim` as the configuration root and
no network activity. `ohc --version` reports `oh-my-code (ohc) <VERSION>-dev`
and `ohc --help` names `oh-my-code` as the public command. `bin/novim-dev`
keeps its exact launch behavior and `novim-dev <VERSION>-dev (custom checkout)`
version identity (preserving the pre-release package contract) while its
version and help output now explicitly label it as a one-release compatibility
alias for `ohc`. Both commands share the same isolated runtime boundary, so
persisted settings survive the identity switch.

Technical choices:

- `bin/ohc` is self-contained rather than a wrapper: the pre-release package
  allowlist stages only `bin/novim-dev`, so the packaged launcher must keep
  working where `bin/ohc` is absent; a shared sourced helper would break the
  package, and the mechanics duplication is bounded (~45 lines).
- `ohc` reuses the `.dev-*` runtime paths instead of introducing an
  oh-my-code-specific prefix: the task permits this ("may use"), the package
  suite asserts the `.dev-*` boundary for the staged launcher, and a shared
  boundary gives the alias identical data/state/cache behavior with settings
  continuity across the identity switch.

### Files changed

- `bin/ohc` (new executable public launcher)
- `bin/novim-dev` (compatibility-alias identity/help labeling; mechanics
  unchanged)
- `tests/run_smoke_tests.sh` (public command, compatibility alias, dual-command
  external-cwd/symlink isolation, file-argument passthrough, headless suite
  under `ohc`, product-tree integrity check)
- `tests/test_smoke.lua` (suite identity comments only; behavior unchanged)
- `docs/architecture.md` (public boundary, launcher identity boundary, smoke
  layer description, pre-release packaging note)
- `docs/LOCAL_DISTRIBUTION.md` (checkout identity, package/alias boundary,
  checkout-level verification)
- `docs/tasks/current-task.md` (status and this handoff)

Not changed by design: `bin/novim`, the installed `novim` release, the user's
normal Neovim config, `bin/novim-dev-package`, `tests/run_package_tests.sh`,
`tests/run_tests.sh`, and everything under `config/nvim/`.

### Validation commands and results

| Command | Result |
|---|---|
| `bash -n bin/ohc bin/novim-dev tests/run_smoke_tests.sh tests/run_tests.sh tests/run_package_tests.sh` | PASS (syntax OK) |
| `./bin/ohc --version` and `./bin/ohc -v` | PASS: `oh-my-code (ohc) 0.1.7-dev` plus `powered by NVIM v0.12.5` |
| `./bin/ohc --help` | PASS: public identity, usage, isolated runtime paths, alias note |
| `./bin/novim-dev --version`, `-v`, `--help` | PASS: `novim-dev 0.1.7-dev (custom checkout)` identity kept; explicit one-release alias labeling added |
| `luajit -bl tests/test_smoke.lua` | PASS (Lua syntax) |
| `./tests/run_tests.sh` | PASS: 59/59 integration tests; offline package suite (deterministic archive, allowlist, install isolation, sync fixtures, invariance); smoke runner all steps including 9/9 headless smoke tests under `ohc` |
| `git diff --check` | PASS (no whitespace errors) |
| Before/after `bin/novim` sha256 | PASS: `cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321` unchanged (2026-08-30T20:09Z vs 20:17Z) |
| Before/after installed `novim` sha256 and `--version` | PASS: `5955e1f2c223d13b024e263dca412f1acb96b69d4168b26b3fa3f7b14c1de26a` unchanged; output `novim 0.1.7` / `powered by NVIM v0.12.5` unchanged; `~/.local/share/novim` still present |

All evidence is local. No hosted, production, recovery, or customer-acceptance
claim is made.

### Acceptance-criterion evidence

| Criterion | Result | Evidence |
|---|---|---|
| `bin/ohc` executable; launches bundled `config/nvim` from another working directory and through a symlink | PASS | Smoke runner Step 3.1/3.2 headless stdpath assertions from an external cwd and via a symlink; `bin/ohc` is mode 755 |
| `ohc --version`/`--help` identify `oh-my-code`/`ohc`, preserve checkout version semantics, exit without an interactive editor | PASS | Smoke runner Step 1.1-1.3 asserts `oh-my-code`, `ohc`, `0.1.7-dev` (derived from `VERSION`), `powered by NVIM`, usage, and runtime paths; the flag branches exit before any `nvim` exec |
| `novim-dev --version`/`--help` remain usable and explicitly identify compatibility status | PASS | Smoke runner Step 2.1-2.3 asserts the preserved `novim-dev 0.1.7-dev (custom checkout)` identity plus `one-release compatibility alias` and `ohc` labeling |
| `ohc --headless` forwards Neovim arguments and resolves all writable runtime paths below the checkout's isolated boundary without network activity | PASS | Smoke runner Step 3.1 asserts config/data/state/cache equal the checkout `config/nvim` and `.dev-*` paths; Step 4 asserts file-argument forwarding via `argc`/realpath; the launchers contain no network or update code paths and all validations ran offline |
| Existing file arguments and Neovim flags pass through both command names without changing workbench behavior | PASS | Smoke runner Step 4 for both launchers; Step 3 headless runs forward `--headless`/`-c` for both; 59/59 integration tests confirm unchanged workbench behavior |
| Focused smoke coverage: public command, compatibility alias, external cwd, symlink invocation, isolated paths, installed `novim` invariance; package suite green | PASS | Smoke runner Steps 1-4; `tests/run_package_tests.sh` green inside `./tests/run_tests.sh` without modification |
| `bin/novim`, installed `novim`, and the normal Neovim config are byte/output invariant before and after validation | PASS | sha256 before/after identical for `bin/novim` and `~/.local/bin/novim`; installed `--version` output identical; the launchers set their own `XDG_CONFIG_HOME` so the normal config (absent `~/.config/nvim/init.lua` on this machine) is never read or written |

### Residual risks and known gaps

- `bin/ohc` and `bin/novim-dev` intentionally duplicate the launcher mechanics
  to keep `novim-dev` self-contained for the pre-release package; consolidation
  belongs to the TASK-017 package migration.
- The `0.1.7-dev` version semantics are unchanged by design; the public
  `v1.0.0` version bump is TASK-019.
- Installed-`novim` independence is a local-machine check, not hosted or
  customer-acceptance evidence.

### Commit

`HEAD (handoff commit)` — `task(TASK-015): oh-my-code identity`
