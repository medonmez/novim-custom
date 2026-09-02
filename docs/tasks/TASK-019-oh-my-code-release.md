# TASK-019 — strict oh-my-code release candidate and `v1.0.0` publication

- Status: `PLANNED`
- Delivery policy: `STRICT`
- Base branch: `main`
- Expected baseline: `ed5a35937d19982832fa0c770486d7496f93d21b`
- Task branch: `task/TASK-019-oh-my-code-release`
- PR target: `origin/main`
- Dependency: `TASK-018` (accepted in PR #34)

## Outcome

Run the strict hosted release gate for oh-my-code: prepare and verify the
`v1.0.0` candidate, rename the public GitHub repository, publish the GitHub
Release assets, and verify a fresh public installer path without changing the
independent installed upstream `novim` boundary.

## Context

TASK-018 made the README and real terminal demo public-safe while explicitly
leaving the hosted repository rename, release, and installer verification
unperformed. ADR-006 defines `oh-my-code`/`ohc`, the one-release `novim-dev`
alias, `v1.0.0`, and the separate installed `novim` boundary. TASK-017
prepared the allowlisted package, fail-closed installer, and tag-only release
workflow; this task is the first one allowed to exercise those hosted paths.

## In scope

- Verify the accepted `origin/main` baseline and run the local release
  preflight for package, smoke, full-suite, workflow, syntax, and invariance
  contracts.
- Bump the public release version to `1.0.0`; verify tag/workflow identity and
  generated `oh-my-code-1.0.0.tar.gz` plus checksum assets.
- Rename `medonmez/novim-custom` to `medonmez/oh-my-code` and read back the
  canonical provider state.
- Create and verify the hosted GitHub Release `v1.0.0` and its public assets.
- Run a fresh, user-authorized hosted installer verification with an existing
  Neovim, checking the managed oh-my-code root and `ohc`/`novim-dev` links.
- Record exact hosted release, rename, asset, checksum, and installer evidence
  separately from local or synthetic-fixture evidence.

## Out of scope

- New workbench behavior, internal `novim` Lua namespace migration, upstream
  synchronization, or changes to installed upstream `novim`.
- README redesign or replacement of the accepted package/installer contracts.
- Force-pushes, branch-protection bypass, unrelated GitHub mutations, secrets
  in logs/docs, or claims based only on local/synthetic checks.

## Acceptance criteria

- [ ] Fresh `origin/main` preflight passes package, smoke, full-suite,
      workflow, syntax, asset-integrity, and `git diff --check` validation.
- [ ] `VERSION` is `1.0.0`; exactly `v1.0.0` is accepted by the release
      workflow, which produces the public allowlisted archive and checksum
      without packaging or mutating `bin/novim`.
- [ ] The provider read-back confirms the repository is
      `medonmez/oh-my-code` with the expected default branch and merge state.
- [ ] The hosted `v1.0.0` release exists with the expected archive/checksum
      assets; names, sizes, and SHA-256 values match workflow output.
- [ ] A fresh, authorized installer run against the public release succeeds
      with existing Neovim, creates only the accepted managed root/links, and
      reports the public launcher and one-release alias. Declared asset-only
      download, checksum, collision, and updater boundaries are verified.
- [ ] Before/after read-backs prove installed `novim`, normal Neovim config,
      unrelated paths, and upstream boundaries remain untouched; hosted,
      production, recovery, and customer-acceptance evidence are classified
      separately.

## Guardrails

- Do not mark hosted or production criteria passed without real provider and
  public-installer read-back. Stop with `BLOCKED` when permission, required
  checks, release assets, or an authorized installer environment is missing.
- Preserve `ohc` as primary and `novim-dev` as a one-release compatibility
  alias. Never overwrite installed `novim` or the normal Neovim configuration.
- Installer network access is limited to the declared release archive and
  checksum. Do not run the upstream updater or replace unrelated links.
- Keep tokens, credentials, private fixture data, and user-authorized paths out
  of commits, PR text, logs, screenshots, and durable records.

## Relevant files and validation

- `VERSION`, `.github/workflows/release.yml`, `bin/oh-my-code-package`
- `install.sh`, `docs/install`
- `tests/run_package_tests.sh`, `tests/run_smoke_tests.sh`, `tests/run_tests.sh`
- `docs/LOCAL_DISTRIBUTION.md`, `docs/architecture.md`, ADR-006

The implementer must stop at a local handoff commit on the isolated task
branch. Repository rename, tag, GitHub Release, and fresh hosted installer
verification remain subject to this task's strict review and delivery gates.
