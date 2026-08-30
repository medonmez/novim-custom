# ADR-006: oh-my-code Public Identity and Release Boundary

- Status: `ACCEPTED FOR IMPLEMENTATION`
- Date: 2026-08-30
- Scope: public product identity, launcher, and first release

## Decision

1. The public application and repository name is `oh-my-code`. The GitHub
   rename from `medonmez/novim-custom` to `medonmez/oh-my-code` is authorized
   for the release sequence and remains a delivery action.
2. `ohc` is the public launcher. `novim-dev` remains a one-release
   compatibility alias using the same bundled configuration and runtime
   boundary. The installed upstream `novim` command and its paths are never
   overwritten.
3. A public installation uses `~/.local/share/oh-my-code` and
   `~/.local/bin/ohc`. A `novim-dev` compatibility link is created only when
   absent or already pointing to this release.
4. The first public release is `v1.0.0`, distributed through a GitHub Release
   and a separate networked installer.
5. The launcher shows a one-second animated ANSI splash only for an
   interactive TTY launch. `--no-animation` and `OHC_NO_ANIMATION=1` disable
   it; help, version, headless, piped, and test launches skip it.
6. The public README is the product entry point and uses real terminal
   evidence, a short feature explanation, and a real `ohc` usage capture. It
   must not claim hosted, production, or customer-acceptance evidence that has
   not been observed.

## Boundaries

- The internal Lua module namespace under `config/nvim/lua/novim/` remains an
  implementation detail for this release; a namespace migration is not
  implied by the brand rename.
- The upstream `bin/novim` launcher, installed `novim` release, and user's
  normal Neovim configuration remain outside the public release mutation path.
- Normal `ohc` startup has no required hosted service, credential flow, or
  network action.
- The release installer may download only the declared GitHub Release asset;
  it must not run the upstream updater or silently replace an unrelated
  existing command.

## Rationale

The workbench has grown beyond a local experiment and needs a memorable public
identity, while the existing installed `novim` remains a useful independent
fallback. Separating the public command and install root makes the rename
reversible for existing users and keeps the release contract explicit.

## Consequences

- Visible launcher, package, installer, test, and current documentation
  identities must move from `novim-dev`/`novim-custom` to `ohc`/`oh-my-code`.
- Historical task records may retain the names that were true when those
  tasks were delivered.
- Repository rename, GitHub release creation, and fresh installer download
  are hosted delivery evidence and must be verified separately from local
  tests.
