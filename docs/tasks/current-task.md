# Current Task

Updated: 2026-08-31
Task ID: `TASK-018`
Status: `READY_FOR_REVIEW`
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

Status: `READY_FOR_REVIEW`
Handoff commit: HEAD (handoff commit) on
`task/TASK-018-oh-my-code-readme-demo-assets` (baseline `bad06b69c1d17879f18a3d4f9cfa537bfba6fba9` via
`06440e07d2946ba480ab3c098624b9369dfc8bdf`). No push, PR, rename, tag, or
release was performed.

Implementer: `$stateless-implementer` (fresh context).

### Changes

- `README.md`: full rewrite as the public `oh-my-code` entry point — identity
  (`ohc`), audience, requirements (existing Neovim 0.8.0+, POSIX shell),
  installation boundary (no hosted release yet; checkout launcher; offline
  package path; installer prepared but unpublished), first launch (splash +
  all bypasses), Files/Preview and Source Control flows (lazy root-only tree,
  session-only expansion, refresh-on-entry diff vs HEAD with untracked,
  file-level stage/unstage/commit, read-only history, no remote actions),
  settings/themes (six themes, key help, immediate Esc, persistence), editor
  interactions (auto-copy selection, Esc-to-Preview, unsaved confirm), three
  shortcut tables from the canonical keymap source and `init.lua`, a Mermaid
  architecture diagram (launcher → isolated config/data/state/cache → Neovim;
  offline package; prepared installer; untouched installed `novim` and normal
  Neovim config), `novim-dev` one-release alias section, privacy section,
  and preserved upstream/third-party attribution. Upstream `novim` install
  path (`curl novim.dev/install`, `ow version`) removed; the upstream NOVIM
  logo image (`docs/logo.png`) is deliberately no longer featured (upstream
  branding must not be primary); the file itself is unchanged.
- `docs/demo.gif`: replaced with a genuine 1400x700, 464-frame vhs capture of
  a real interactive PTY session of this checkout's `./bin/ohc` (started as
  `../ohc`, a symlink invocation, from a clean fixture project at
  `/tmp/ohc-demo/demo-project` — four public-safe sample files, local Git
  identity `Demo User <demo@example.com>`). The capture shows the splash,
  Files preview, editor handoff, Source Control staging and a local commit
  ("Add average helper"), and a theme change in Settings. The installed
  `novim` was never used. Capture artifacts (tape, fixture, frames, venv)
  live only under `/tmp/ohc-demo` and are not committed.

### Validation (all local evidence; no hosted/production/recovery/customer-acceptance claim)

| Check | Command | Result |
|---|---|---|
| Installed `novim` BEFORE edits | `shasum -a 256 ~/.local/bin/novim` + `--version` | `5955e1f2c223d13b024e263dca412f1acb96b69d4168b26b3fa3f7b14c1de26a`, prints `novim 0.1.7` — matches record; also `bin/novim` `cb8e878515cc1874eb792693b03b3803e7f823c8e6af71dfab89fa3bff048321` |
| Installed `novim` AFTER changes | same | identical hashes and version; unchanged |
| Normal Neovim config | `ls ~/.config/nvim` before and after | absent at both points; unchanged |
| README render/structure | throwaway `/tmp/mdcheck-venv` (`markdown` 3.10.3): tables/fenced_code/toc render; heading/TOC-anchor scan | 29 headings rendered; 15 TOC anchors, 0 unresolved |
| Relative links/images | scripted check of rendered `href`/`src` targets | 6 unique relative targets (`LICENSE`, `THIRD_PARTY_LICENSES.md`, `docs/HOW_IT_WORKS.md`, `docs/LOCAL_DISTRIBUTION.md`, `docs/architecture.md`, `docs/demo.gif`), all resolve |
| Mermaid syntax | render in isolated headless Chrome with mermaid 11 (`file:///tmp/ohc-demo/mermaid.html`) | `MERMAID_OK`, 1 SVG; screenshot inspected |
| GIF validity | `ffprobe -count_frames` on committed `docs/demo.gif` | GIF89a 1400x700, 464 frames |
| GIF frame audit | ffmpeg frame extraction + visual inspection (~35 frames incl. splash, preview, editor, Source Control, commit, settings, quit) | no credentials, tokens, usernames, hostnames, or private paths; only synthetic `/tmp/ohc-demo/...` fixture paths; no hosted claims |
| Launcher identity | `./bin/ohc --version`, `./bin/ohc --help` | `oh-my-code (ohc) 0.1.7-dev`; help names oh-my-code and the `novim-dev` alias |
| Smoke suite | `./tests/run_smoke_tests.sh` | 9/9 passed, zero fixture residue, source tree clean |
| Full suite | `./tests/run_tests.sh` | integration 59/59, package runner PASS, smoke 9/9 |
| Whitespace | `git diff --check` | clean |
| Working tree | `git status --porcelain` | exactly `README.md`, `docs/demo.gif`, `docs/tasks/current-task.md` |
| Upstream sync state | `git remote -v` | `origin`/`upstream` unchanged; no fetch/pull performed |

### Local tool installs (disclosed)

- `brew install vhs` (vhs 0.11.0 with ttyd 1.7.7 dependency) for the scripted
  deterministic terminal capture; `ffmpeg` was already present.
- Temporary `/tmp/mdcheck-venv` with `markdown` 3.10.3 for the rendered
  README check. Both are local validation tooling only; no repo files depend
  on them.

### Acceptance-criterion evidence

- oh-my-code/ohc primacy: README title/tagline/commands are `oh-my-code`/`ohc`;
  no upstream install/update path remains; upstream NOVIM logo not featured.
- Real demo GIF: captured from this checkout's `ohc` in a vhs PTY (bypasses
  untouched; splash visible), public-safe frames audited (table above).
- Mermaid diagram: shows launcher (`bin/ohc`, `bin/novim-dev`), isolated
  `config/nvim` + `.dev-data`/`.dev-state`/`.dev-cache`, offline package
  helper/archive, prepared-but-unpublished installer and `~/.local` roots,
  and the untouched installed `novim` + normal Neovim config; rendered OK.
- Consistency with ADR-006 / architecture.md / LOCAL_DISTRIBUTION.md: wording
  for installation, alias, splash bypass, local Git writes, and privacy was
  drafted directly from those documents (no invented behavior).
- Links/attribution/hosted honesty: all targets resolve; attribution and
  license links preserved; README states no hosted release exists yet and
  never implies the rename or `v1.0.0` publication has happened.

### Residual risks / known gaps

- The Settings modal title inside the capture reads "novim-dev Settings &
  Preferences" — the real, accepted implementation surface; `config/nvim/`
  rebranding is out of scope for this task.
- The captured theme starts from a previously persisted palette (isolated
  `.dev-state`), not factory-default Tokyo Night; theme cycling itself is
  shown working, and the shipped default is covered by the test suite.
- Preview headers in the capture display the synthetic fixture path
  `/private/tmp/ohc-demo/demo-project/...` — deliberate public-safe fixture
  content, no user-identifying data.
- vhs/tabby rendering may differ slightly from other terminals; the GIF is a
  faithful capture of one real session, not a portable recording.

Next: run `$project-orchestrator` for local review and the lightweight
delivery path (PR to `origin/main` when approved).
