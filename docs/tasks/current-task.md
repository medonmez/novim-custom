# Current Task

Updated: 2026-09-03
Task ID: `TASK-019`
Status: `ACCEPTED`
Delivery policy: `STRICT`
Base branch: `main`
Task branch: `task/TASK-019-oh-my-code-release`
Expected baseline: `0c0d0f96fdc0193bc33224ab8507afd55b43265e`
Pull request: `#36 <https://github.com/medonmez/oh-my-code/pull/36>` (`MERGED` at
`8f50c01c0f1480e04b4b3b8031d23c461a7d0fc1`)
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

- [x] The task starts from the verified `origin/main` merge containing
      TASK-018 and the strict local preflight passes, including package,
      smoke, full-suite, workflow, syntax, and `git diff --check` validation.
- [x] `VERSION` is `1.0.0`; the release workflow accepts exactly `v1.0.0`,
      builds the public allowlisted archive, emits its checksum, and does not
      package or mutate `bin/novim`.
- [x] The GitHub repository rename to `medonmez/oh-my-code` is actually
      observed through provider read-back; the old remote is not treated as
      the final public identity.
- [x] The hosted `v1.0.0` GitHub Release exists with the expected archive and
      checksum assets, and their names, sizes, and SHA-256 read back from the
      provider match the release workflow output.
- [x] A fresh, user-authorized installer run against the public release
      succeeds with an existing Neovim, creates only the accepted oh-my-code
      root/links, and reports the public launcher and one-release alias.
      Download scope, checksum verification, collision behavior, and no
      updater/network behavior beyond the declared assets are observed.
- [x] Before/after checks prove the installed upstream `novim`, normal
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

Implementation stopped at the local handoff commit on the isolated task
branch. The strict review and delivery gates are complete; hosted evidence is
recorded below and in the detailed TASK-019 record.

## Implementation and delivery record

Implementer: `$stateless-implementer` (fresh context). Local handoff commit:
`25768fd2fb3db7f4ff938e90821e4b115d7809ba`. Local review record:
`260cf29c1bcc8cd3577f3c60a8e086738990e591` (`APPROVED`).

The reviewed branch was delivered through PR #36, merged at
`8f50c01c0f1480e04b4b3b8031d23c461a7d0fc1`, and verified in `origin/main`.
Required PR ShellCheck CI passed. The repository was renamed and read back as
public `medonmez/oh-my-code` with default branch `main`.

### Local evidence

The local evidence remains classified separately from hosted evidence:

- `bash -n`, PyYAML workflow parsing, the workflow tag/manifest/checksum dry-run,
  `./tests/run_package_tests.sh`, `./tests/run_smoke_tests.sh` (9/9),
  `./tests/run_tests.sh` (59/59 plus package and smoke),
  `diff -u install.sh docs/install`, and `git diff --check` passed.
- The macOS-local deterministic package digest was
  `e09ac6c524d507580ef886a6ad3b5a42aa89cd8ec9567c023966e70f0464ffd2`.
  The hosted Ubuntu workflow produced the separate provider asset digest
  recorded below.
- Installed `novim` stayed SHA-256
  `5955e1f2c223d13b024e263dca412f1acb96b69d4168b26b3fa3f7b14c1de26a` and
  `novim 0.1.7`; checkout `bin/novim` stayed
  `cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321`; and
  the normal Neovim config remained absent.

### Hosted evidence

- Release workflow run `33686893104` for tag `v1.0.0` passed every step,
  including tag identity, archive manifest, `bin/novim` guard, checksum, docs
  sync, and release creation. Its checksum output was
  `b4958e2fe42ac599eb39dbac26d65def8da5ef00f368de353ab39d4c849d224d`.
- The public release is
  `https://github.com/medonmez/oh-my-code/releases/tag/v1.0.0`, published at
  `2026-09-02T21:46:00Z`, with `oh-my-code-1.0.0.tar.gz` (184,780 bytes,
  provider SHA-256 `b4958e2fe42ac599eb39dbac26d65def8da5ef00f368de353ab39d4c849d224d`)
  and `oh-my-code-1.0.0.tar.gz.sha256` (90 bytes, provider SHA-256
  `9b0ce73fdbf8d83ca2ad29fbe3a73448a13a1e8db568ba8a65da38a39ec32687`).
  Downloading the assets and recomputing the archive digest matched the
  workflow checksum.
- The exact version-pinned public command
  `curl -fsSL https://raw.githubusercontent.com/medonmez/oh-my-code/v1.0.0/install.sh | bash -s -- v1.0.0`
  succeeded in a fresh physical temporary HOME with existing Neovim `0.12.5`.
  The installer downloaded only the archive and checksum URLs, verified the
  checksum, validated the allowlist, created only the managed
  `~/.local/share/oh-my-code` root plus `~/.local/bin/ohc` and
  `~/.local/bin/novim-dev`, and reported both public and one-release alias
  identities. A real-release unrelated `ohc` collision was rejected after
  validation without creating the install root or replacing the marker file.
- Hosted-install before/after checks preserved the real installed `novim`
  hash/version, upstream remote `https://github.com/link2004/novim.git`, and
  absent normal `~/.config/nvim`; the unrelated fixture marker also remained.

No hosted, production, recovery, or customer-acceptance claim is made beyond
the provider and installer observations above. TASK-019 is accepted.
