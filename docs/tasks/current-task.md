# Current Task

Updated: 2026-09-03
Task ID: `TASK-019`
Status: `READY_FOR_REVIEW`
Delivery policy: `STRICT`
Base branch: `main`
Task branch: `task/TASK-019-oh-my-code-release`
Expected baseline: `ed5a35937d19982832fa0c770486d7496f93d21b`
Pull request: not opened
PR target: `origin/main`
Dependency: `TASK-018` (accepted in PR #34)
Detailed task record: `docs/tasks/TASK-019-oh-my-code-release.md`

## Outcome

Run the strict hosted release gate for oh-my-code: prepare and verify the
`v1.0.0` candidate, rename the public GitHub repository, publish the GitHub
Release assets, and verify a fresh public installer path without changing the
independent installed upstream `novim` boundary.

## In scope

- Re-fetch and verify the accepted `origin/main` baseline, then run the local
  release-candidate validation required by the package, smoke, and workflow
  contracts.
- Bump the public release version to `1.0.0` and verify the tag/workflow
  identity and generated `oh-my-code-1.0.0.tar.gz` plus checksum assets.
- Rename the GitHub repository from `medonmez/novim-custom` to the accepted
  public target `medonmez/oh-my-code` and verify the canonical remote state.
- Create and verify the hosted GitHub Release `v1.0.0` and its public assets.
- Run a fresh, user-authorized hosted installer verification with an existing
  Neovim, checking the managed `~/.local/share/oh-my-code` root and
  `~/.local/bin/ohc`/`novim-dev` links while preserving installed `novim`.
- Reconcile only after hosted read-back evidence is observed and record the
  release, rename, asset, checksum, and installer evidence distinctly.

## Out of scope

- New workbench behavior, branding migration of internal `novim` Lua modules,
  upstream synchronization, or changes to the installed upstream `novim`.
- Rewriting the README or replacing the accepted package/installer contracts.
- Claiming hosted, production, recovery, or customer acceptance from local
  tests, synthetic fixtures, or an unverified release page.
- Force-pushing, bypassing required branch protections/checks, exposing
  credentials, or mutating unrelated GitHub repositories and paths.

## Acceptance criteria

- [ ] The task starts from the verified `origin/main` merge containing
      TASK-018 and the strict local preflight passes, including package,
      smoke, full-suite, workflow, syntax, and `git diff --check` validation.
- [ ] `VERSION` is `1.0.0`; the release workflow accepts exactly `v1.0.0`,
      builds the public allowlisted archive, emits its checksum, and does not
      package or mutate `bin/novim`.
- [ ] The GitHub repository rename to `medonmez/oh-my-code` is actually
      observed through provider read-back; the old remote is not treated as
      the final public identity.
- [ ] The hosted `v1.0.0` GitHub Release exists with the expected archive and
      checksum assets, and their names, sizes, and SHA-256 read back from the
      provider match the release workflow output.
- [ ] A fresh, user-authorized installer run against the public release
      succeeds with an existing Neovim, creates only the accepted oh-my-code
      root/links, and reports the public launcher and one-release alias.
      Download scope, checksum verification, collision behavior, and no
      updater/network behavior beyond the declared assets are observed.
- [ ] Before/after checks prove the installed upstream `novim`, normal
      Neovim configuration, upstream remote, and unrelated paths remain
      outside the release mutation boundary; all hosted evidence is recorded
      separately from local/synthetic evidence.

## Guardrails

- This is the strict hosted task. Do not mark any hosted or production
  criterion passed until the provider state and public installer are read back
  from the real target.
- Preserve `ohc` as the public command and `novim-dev` as a one-release
  compatibility alias. Preserve installed `~/.local/share/novim`,
  `~/.local/bin/novim`, and the normal Neovim configuration.
- Use only the declared release archive and checksum for installer network
  access. Do not run the upstream updater or silently replace unrelated links.
- Keep tokens, credentials, private fixture data, and user-authorized paths
  out of commits, PR text, logs, screenshots, and durable records.
- Stop with `BLOCKED` if provider permission, required checks, release assets,
  authorized installer fixture, or an explicit release decision is missing.

## Relevant files and discovery hints

- `VERSION`
- `.github/workflows/release.yml`
- `bin/oh-my-code-package`
- `install.sh`, `docs/install`
- `tests/run_package_tests.sh`, `tests/run_smoke_tests.sh`,
  `tests/run_tests.sh`
- `docs/LOCAL_DISTRIBUTION.md`, `docs/architecture.md`,
  `docs/adr/ADR-006-oh-my-code-public-identity.md`
- `docs/tasks/TASK-018-oh-my-code-readme-demo-assets.md`

## Required validation

- Verify the task branch is isolated from the freshly fetched
  `origin/main` baseline and inspect the complete release diff.
- Run the strict local preflight: shell/YAML/workflow checks, package and
  smoke suites, full tests, README/link/asset integrity, and invariance probes.
- Verify `VERSION`/tag/archive/checksum identity before invoking any hosted
  rename or release mutation.
- Read back GitHub repository name, default branch, PR/check state, release
  tag, release assets, and checksums using the provider; preserve the exact
  observed URLs and timestamps without secrets.
- Use a fresh, controlled or explicitly user-authorized installer environment
  with an existing Neovim and capture both success and relevant negative
  boundary evidence without touching the installed upstream `novim`.
- Run `git diff --check` and final before/after invariance checks; classify
  local, hosted, production, recovery, and customer-acceptance evidence
  separately.

Implementation must stop at a local handoff commit on this branch. Hosted
rename, tag, GitHub Release, and fresh installer verification require the
strict review and delivery gates for this task.

## Implementation handoff

Status: `READY_FOR_REVIEW`
Handoff commit: HEAD (handoff commit) on
`task/TASK-019-oh-my-code-release` (baseline `0c0d0f96fdc0193bc33224ab8507afd55b43265e` on
`origin/main`). No push, PR, repository rename, tag, or GitHub Release was
performed.

Implementer: `$stateless-implementer` (fresh context).

### Changes

- `VERSION`: updated from `0.1.7` to `1.0.0` for the public `v1.0.0` release
  candidate.
- `docs/tasks/current-task.md`: updated status to `READY_FOR_REVIEW` and
  recorded implementation handoff.
- `docs/tasks/TASK-019-oh-my-code-release.md`: updated status to
  `READY_FOR_REVIEW`.

### Validation (all local evidence; no hosted/production/recovery/customer-acceptance claim)

| Check | Command | Result |
|---|---|---|
| Installed `novim` BEFORE edits | `shasum -a 256 ~/.local/bin/novim` + `--version` | `5955e1f2c223d13b024e263dca412f1acb96b69d4168b26b3fa3f7b14c1de26a`, prints `novim 0.1.7` — matches record; also `bin/novim` `cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321` |
| Installed `novim` AFTER changes | same | identical hashes and version; unchanged |
| Normal Neovim config | `ls ~/.config/nvim` before and after | absent at both points; unchanged |
| Script syntax | `bash -n bin/ohc bin/novim-dev bin/oh-my-code-package install.sh docs/install tests/run_tests.sh tests/run_package_tests.sh tests/run_smoke_tests.sh` | PASS (clean) |
| Release workflow dry-run | local execution of `.github/workflows/release.yml` steps | PASS: VERSION matches `1.0.0`, tag refs `refs/tags/v1.0.0` accepted, bad tag rejected, `bin/novim` protected, package built, manifest verified, SHA-256 emitted, `docs/install` synced |
| Package tests | `./tests/run_package_tests.sh` | PASS: deterministic package SHA-256 `e09ac6c524d507580ef886a6ad3b5a42aa89cd8ec9567c023966e70f0464ffd2`, hostile fixtures rejected, offline install verified, network install simulated, invariance preserved |
| Smoke tests | `./tests/run_smoke_tests.sh` | 9/9 passed: `ohc 1.0.0-dev` CLI/help, `novim-dev 1.0.0-dev` alias, splash PTY/duration/bypasses, 9 headless smoke tests, zero residue |
| Full suite | `./tests/run_tests.sh` | PASS: 59/59 workbench/git/settings integration tests, package tests PASS, smoke 9/9 PASS |
| Docs/install sync | `diff -u install.sh docs/install` | PASS (byte-for-byte identical) |
| Whitespace / git check | `git diff --check` | PASS (clean) |
| Remote invariance | `git remote -v` | origin `medonmez/novim-custom.git`, upstream `link2004/novim.git` unchanged |

### Acceptance-criterion evidence

- Strict local preflight: clean baseline `0c0d0f9` verified on `origin/main`;
  full test suites (59/59 integration, package suite, 9/9 smoke), script syntax,
  and invariance checks passed.
- `VERSION` is `1.0.0`: package helper builds `oh-my-code-1.0.0.tar.gz` with
  stable SHA-256 `e09ac6c524d507580ef886a6ad3b5a42aa89cd8ec9567c023966e70f0464ffd2`;
  release workflow simulation confirms exact `v1.0.0` match, allowlisted
  archive root, checksum generation, and `bin/novim` immutability.
- Repository rename, hosted `v1.0.0` release creation, and fresh public
  installer verification are deferred to the `$project-orchestrator` strict
  delivery gate in accordance with the task specification.

### Residual risks / known gaps

- The GitHub repository rename to `medonmez/oh-my-code`, the `v1.0.0` release tag
  push, GitHub Release asset publishing, and public networked installer run
  against the live release URL remain to be executed by `$project-orchestrator`
  during the strict delivery gate.
- Installed `novim` (`~/.local/bin/novim`) and checkout `bin/novim` remained
  strictly untouched during candidate generation and local validation.
