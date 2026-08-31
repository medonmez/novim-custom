# Current Task

Updated: 2026-08-31
Task ID: `TASK-018`
Status: `PLANNED`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-018-oh-my-code-readme-demo-assets`
Expected baseline: `bad06b69c1d17879f18a3d4f9cfa537bfba6fba9`
Pull request: not opened
PR target: `origin/main`
Dependency: `TASK-017` (accepted in PR #32)
Detailed task record: `docs/tasks/TASK-018-oh-my-code-readme-demo-assets.md`

## Outcome

Replace the upstream-facing root README with a discoverable `oh-my-code`
product guide and real terminal evidence, while keeping the README honest
about local validation, hosted release availability, and the separate
installed upstream `novim` command.

## In scope

- Rewrite `README.md` as the public `oh-my-code` entry point: identity,
  audience, requirements, installation boundary, first launch, core Files /
  Preview and Source Control flows, settings/themes, editor interactions,
  shortcuts, compatibility alias, and attribution.
- Replace stale `docs/demo.gif` with a real terminal capture of this
  checkout's `ohc` surface using only public-safe fixture content.
- Add a compact Mermaid architecture explanation matching the accepted
  launcher, isolated runtime, package/installer, and separate installed
  `novim` boundaries.
- Keep installation/package documentation consistent with
  `docs/LOCAL_DISTRIBUTION.md`, distinguishing local validation from the
  not-yet-published hosted release.
- Preserve upstream and third-party attribution and resolve all README
  relative links and image references.

## Out of scope

- Changes to `bin/ohc`, `bin/novim-dev`, `bin/novim`, `config/nvim/`, installer
  logic, package allowlists, release workflow, or workbench behavior.
- GitHub repository rename, version bump, tag, GitHub Release, or hosted
  installer verification (`TASK-019`).
- Hosted, production, recovery, or customer-acceptance claims based on local
  commands, a local capture, or synthetic fixtures.
- Broad upstream documentation-site changes outside the root README and the
  explicitly required demo/architecture assets.

## Acceptance criteria

- [ ] README presents `oh-my-code`/`ohc` as the public product and does not
      leave upstream `novim` branding or its install/update path primary.
- [ ] `docs/demo.gif` is a valid, viewable capture from a real `ohc` terminal
      session, visibly demonstrates the public workbench, and contains no
      private data or unsupported hosted claims.
- [ ] The Mermaid architecture diagram accurately shows launcher, isolated
      config/data/state/cache, package/installer, and independent installed
      `novim` boundaries.
- [ ] Installation, alias, splash bypass, local Git-write, and privacy
      wording agrees with ADR-006, `docs/architecture.md`, and
      `docs/LOCAL_DISTRIBUTION.md`.
- [ ] Relative links/images resolve, attribution remains present, and the
      hosted rename/release is not presented as already complete.
- [ ] README/demo validation, relevant launcher/smoke checks, and
      `git diff --check` pass; `bin/novim`, installed `novim`, normal Neovim
      config, and upstream sync state remain unchanged.

## Guardrails

- Use only deliberately public text and a clean fixture; inspect the final
  README and GIF for paths, credentials, tokens, and private content.
- Preserve the one-release `novim-dev` compatibility wording and the separate
  installed upstream `novim` boundary.
- State that normal `ohc` launch is network-free, installer use requires an
  existing Neovim, and hosted publication belongs to TASK-019.
- Describe only accepted local Git behavior: file-level stage/unstage/commit,
  with no push or remote synchronization; retain splash bypass controls.

## Relevant files and discovery hints

- `README.md`, `docs/demo.gif`, `docs/logo.png`
- `docs/LOCAL_DISTRIBUTION.md`, `docs/architecture.md`,
  `docs/product/product.md`, `docs/adr/ADR-006-oh-my-code-public-identity.md`
- `tests/run_smoke_tests.sh`, `tests/run_tests.sh`

## Required validation

- Inspect rendered README/Markdown structure, every relative link/image target,
  and final GIF frames for public-safe content.
- Verify the demo was captured through a real `ohc` terminal session and does
  not use installed `novim`.
- Run `./bin/ohc --version`, `./bin/ohc --help`, relevant launcher/smoke checks,
  and `./tests/run_tests.sh` after the document/asset changes.
- Run `git diff --check` and before/after checks for `bin/novim`, installed
  `novim` when present, and the normal Neovim configuration.

## Implementation handoff

Implementer: `$stateless-implementer` (fresh context). Stop at a local
handoff commit on `task/TASK-018-oh-my-code-readme-demo-assets`. Do not rename
the repository, create a tag, publish a release, or claim hosted installer
acceptance.
