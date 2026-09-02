# TASK-019 — strict oh-my-code release candidate and `v1.0.0` publication

- Status: `ACCEPTED`
- Delivery policy: `STRICT`
- Base branch: `main`
- Expected baseline: `0c0d0f96fdc0193bc33224ab8507afd55b43265e`
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

- [x] Fresh `origin/main` preflight passes package, smoke, full-suite,
      workflow, syntax, asset-integrity, and `git diff --check` validation.
- [x] `VERSION` is `1.0.0`; exactly `v1.0.0` is accepted by the release
      workflow, which produces the public allowlisted archive and checksum
      without packaging or mutating `bin/novim`.
- [x] The provider read-back confirms the repository is
      `medonmez/oh-my-code` with the expected default branch and merge state.
- [x] The hosted `v1.0.0` release exists with the expected archive/checksum
      assets; names, sizes, and SHA-256 values match workflow output.
- [x] A fresh, authorized installer run against the public release succeeds
      with existing Neovim, creates only the accepted managed root/links, and
      reports the public launcher and one-release alias. Declared asset-only
      download, checksum, collision, and updater boundaries are verified.
- [x] Before/after read-backs prove installed `novim`, normal Neovim config,
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

The implementer stopped at a local handoff commit on the isolated task branch.
The strict review and delivery gates are complete: the repository rename, tag,
GitHub Release, and fresh hosted installer verification were performed and
read back.

## Delivery evidence

- Local review was `APPROVED` at review record `260cf29`; PR #36 passed the
  required ShellCheck job and merged at `8f50c01c0f1480e04b4b3b8031d23c461a7d0fc1`.
- Provider read-back confirms public repository
  `https://github.com/medonmez/oh-my-code`, default branch `main`, and public
  visibility. The former `medonmez/novim-custom` name resolves to the renamed
  repository.
- Release workflow run `33686893104` for tag `v1.0.0` passed. The release at
  `https://github.com/medonmez/oh-my-code/releases/tag/v1.0.0` was published at
  `2026-09-02T21:46:00Z`. Its archive asset is 184,780 bytes with SHA-256
  `b4958e2fe42ac599eb39dbac26d65def8da5ef00f368de353ab39d4c849d224d`; its
  90-byte checksum asset has provider SHA-256
  `9b0ce73fdbf8d83ca2ad29fbe3a73448a13a1e8db568ba8a65da38a39ec32687`. The
  downloaded archive digest matches the workflow checksum output.
- The exact version-pinned public command
  `curl -fsSL https://raw.githubusercontent.com/medonmez/oh-my-code/v1.0.0/install.sh | bash -s -- v1.0.0`
  passed in a fresh physical temporary HOME with existing Neovim `0.12.5`. It
  downloaded only the release archive and checksum, verified and validated the
  archive, created the managed root and both accepted links, and reported `ohc`
  plus the one-release `novim-dev` alias. A real-release unrelated-link
  collision was rejected without creating the install root or replacing the
  preserved marker.
- Before/after read-backs preserved the installed upstream `novim`
  (`5955e1f2c223d13b024e263dca412f1acb96b69d4168b26b3fa3f7b14c1de26a`,
  `novim 0.1.7`), checkout `bin/novim`, the absent normal Neovim config, the
  upstream remote, and unrelated fixture paths.

Hosted evidence is distinct from local and synthetic-fixture evidence. This
task does not establish production, recovery, or customer acceptance.
