# TASK-018 — oh-my-code README and real terminal demo assets

- Status: `PLANNED`
- Delivery policy: `LIGHTWEIGHT`
- Base branch: `main`
- Expected baseline: `bad06b69c1d17879f18a3d4f9cfa537bfba6fba9`
- Task branch: `task/TASK-018-oh-my-code-readme-demo-assets`
- PR target: `origin/main`
- Dependency: `TASK-017` (accepted in PR #32)
- Follow-up: `TASK-019` strict release candidate, repository rename, and
  `v1.0.0` publication

## Outcome

Replace the upstream-facing root README with a discoverable `oh-my-code`
product guide and real terminal evidence, while keeping the README honest
about local validation, hosted release availability, and the separate
installed upstream `novim` command.

## Context

The root README still presents the upstream `novim` product and its hosted
installer, while the accepted public product is now `oh-my-code` launched by
`ohc`. TASK-017 established the public package and safe installer contracts;
TASK-016 established the interactive splash and its bypass controls. The
README must explain those accepted surfaces without making TASK-019's hosted
rename or release appear complete.

## In scope

- Rewrite the root `README.md` as the public `oh-my-code` entry point: identity,
  audience, requirements, installation boundary, first launch, core Files /
  Preview and Source Control flows, settings/themes, editor interactions,
  shortcuts, compatibility alias, and attribution.
- Replace the stale upstream `docs/demo.gif` with a real terminal capture of
  this checkout's `ohc` surface. The capture must use a public-safe fixture or
  otherwise contain no private source, credentials, user paths, or unrelated
  project data.
- Add a compact Mermaid architecture explanation to the README that matches
  the accepted launcher, isolated runtime, package/installer, and separate
  installed-`novim` boundaries.
- Document the release installer and package commands consistently with
  `docs/LOCAL_DISTRIBUTION.md`, clearly distinguishing the not-yet-published
  hosted release from local validation. Do not invent hosted evidence.
- Preserve upstream and third-party license/attribution links and make all
  README-relative links and image references resolve within the repository.

## Out of scope

- Changes to `bin/ohc`, `bin/novim-dev`, `bin/novim`, `config/nvim/`, installer
  logic, package allowlists, release workflow, or workbench behavior.
- GitHub repository rename, version bump, tag creation, GitHub Release
  publication, or fresh hosted installer verification (`TASK-019`).
- Claiming production, hosted, recovery, or customer-acceptance evidence from
  local commands, a local terminal capture, or synthetic fixtures.
- A broad upstream documentation-site rewrite outside the root README and the
  explicitly required demo/architecture assets.

## Acceptance criteria

- [ ] The root README presents `oh-my-code` and `ohc` as the public product,
      accurately describes the accepted workflows and requirements, and does
      not leave upstream `novim` branding or the upstream install/update path
      as the product's primary command.
- [ ] `docs/demo.gif` is a valid, viewable capture from a real `ohc` terminal
      session in this checkout, visibly demonstrates the public workbench, and
      contains no private data or unsupported hosted/production claims.
- [ ] The README's Mermaid architecture diagram accurately shows the public
      launcher, isolated config/data/state/cache boundary, package/installer
      boundary, and independent installed `novim` path.
- [ ] Installation, first-launch, compatibility-alias, splash bypass, local
      Git-write, and privacy boundaries agree with ADR-006,
      `docs/architecture.md`, and `docs/LOCAL_DISTRIBUTION.md`.
- [ ] All README-relative links and image references resolve, attribution and
      license links remain present, and the document does not claim that the
      hosted rename or `v1.0.0` release has already occurred.
- [ ] README/demo validation, relevant launcher/smoke checks, and
      `git diff --check` pass; no installed `novim`, normal Neovim config,
      `bin/novim`, or upstream synchronization state is changed.

## Guardrails

- Treat the README and demo as public surfaces: use only deliberately public
  text and a clean fixture; inspect the final rendered/captured asset for
  paths, credentials, tokens, and private content.
- Preserve the one-release `novim-dev` compatibility wording and never imply
  that it replaces the installed upstream `novim` command.
- State that normal `ohc` launch is network-free, the installer requires an
  existing Neovim, and hosted release publication belongs to TASK-019.
- Keep feature descriptions bounded to accepted behavior: local file-level
  stage/unstage/commit only, no push or remote synchronization, and the
  accepted splash bypass controls.

## Relevant files and discovery hints

- `README.md`
- `docs/demo.gif`
- `docs/logo.png`
- `docs/LOCAL_DISTRIBUTION.md`
- `docs/architecture.md`
- `docs/product/product.md`
- `docs/adr/ADR-006-oh-my-code-public-identity.md`
- `tests/run_smoke_tests.sh`
- `tests/run_tests.sh`

## Required validation

- Inspect the rendered README or equivalent Markdown structure, every relative
  link/image target, and the final GIF frames for public-safe content.
- Verify the demo was captured through a real `ohc` terminal session and does
  not use the installed `novim` path.
- Run `./bin/ohc --version`, `./bin/ohc --help`, the relevant launcher/smoke
  checks, and `./tests/run_tests.sh` when the asset/document changes are
  complete.
- Run `git diff --check` and explicit before/after checks for `bin/novim`, the
  installed `novim` release when present, and the normal Neovim configuration.

The implementer must stop at a local handoff commit on this branch. No push,
repository rename, tag, GitHub Release, or hosted installer acceptance is
part of implementation.
