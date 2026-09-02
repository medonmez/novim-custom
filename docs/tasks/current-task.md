# Current Task

Updated: 2026-09-03
Task ID: `TASK-019`
Status: `PLANNED`
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
