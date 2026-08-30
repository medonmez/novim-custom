# Architecture

Updated: 2026-08-31
Status: `OBSERVED_BASELINE_WITH_ACCEPTED_EXTENSION`

## Current system

The repository is a direct clone of upstream novim at tag `v0.1.7`.

### Public oh-my-code boundary

The public product identity is `oh-my-code` and its primary command is `ohc`,
launched in this checkout through the executable `bin/ohc`. The repository is
transitioning from `medonmez/novim-custom` to the public GitHub target
`medonmez/oh-my-code`; the hosted rename is a release-delivery action, not a
local assumption. `bin/novim-dev` remains a self-contained one-release
compatibility alias that explicitly labels its compatibility status. The
internal Lua modules under `config/nvim/lua/novim/` remain stable
implementation namespaces for this release.

The public installation root is `~/.local/share/oh-my-code` and the primary
link is `~/.local/bin/ohc`. The existing `~/.local/share/novim` and
`~/.local/bin/novim` installation remain independent and must not be replaced.

### Launcher

- `bin/novim` is a Bash wrapper, not a compiled editor.
- It resolves its own repository root and sets `XDG_CONFIG_HOME` to the
  bundled `config` directory.
- It also sets separate `XDG_DATA_HOME` and `XDG_STATE_HOME` directories below
  that config root, then executes `nvim "$@"`.
- The installed release is a separate extraction under
  `~/.local/share/novim`; this repository does not own or update that path.

### Neovim configuration

- `config/nvim/init.lua` contains the main behavior and visual configuration.
- The file defines the Tokyo Night-inspired palette, standard editing
  shortcuts, mouse behavior, safe quit flow, netrw-based file tree, dynamic
  help, and Git overlays.
- The file tree is built on netrw with tree view and a right-hand editor split.
- Git status, log, and diff are currently opened by running local Git commands
  in temporary Neovim floating terminal buffers.
- `gitsigns.nvim` is bundled under `config/nvim/pack/` for buffer-level Git
  change signs.

### Current derivative workbench baseline

- `novim.workbench` opens two windows and reads only the immediate entries of
  the root directory at startup and on every refresh through
  `browser.get_immediate_entries`; startup performs no recursive traversal, so
  launching from a large directory stays responsive.
- The project browser renders a lazy visible list. Double-clicking a folder
  expands one level at a time (immediate children only), double-clicking an
  expanded folder collapses it and removes its descendants, and expansion
  state lives in workbench memory for the current session only. Symlink loops
  are refused by comparing real paths against the folder's own ancestors.
- Settings persist dot-folder visibility and the selected built-in theme.
  The settings modal offers theme selection (six application-owned themes,
  Tokyo Night default), an embedded key-help section rendered below the
  controls, and immediate `Esc`/`q` close that restores workbench focus.
  Themes apply through `novim.themes` highlight mappings with no plugin
  dependency; theme state lives in the isolated settings file.
- The current Diff view keeps the changed-file list on the left and renders
  the selected file in separate old/HEAD and new/working-tree panes. Diff
  status is refreshed whenever the view is entered; binary, deleted, renamed,
  and untracked files use readable content or placeholders. Both visible
  boundaries have application-owned drag state: pressing a divider starts a
  drag, `<LeftDrag>` resizes the adjacent panes in both directions, and widths
  clamp to minimum pane widths (left 15, middle 20, right 20 columns) without
  `E21` or invalid-window failures.

### External boundaries

- Files are read and written through Neovim and the local filesystem.
- Git information is obtained through local Git subprocesses.
- Normal editor launch has no required hosted service or application database.
- The upstream wrapper also exposes update/statistics paths; the planned
  development command must not reuse those network-capable behaviors by
  default.

## Development boundary and launcher

`TASK-001` added a dedicated repository-local launcher via `bin/novim-dev`.
`TASK-015` promoted the public identity: `bin/ohc` is now the primary public
launcher of this checkout, and `bin/novim-dev` remains a self-contained
one-release compatibility alias. Both launchers provide the same isolation
guarantees:
- Resolves its repository root dynamically through symlinks and from any working directory.
- Sets `XDG_CONFIG_HOME` to this checkout's `config` directory (`config/nvim/init.lua`).
- Sets separate runtime paths `XDG_DATA_HOME` (`.dev-data/`), `XDG_STATE_HOME` (`.dev-state/`), and `XDG_CACHE_HOME` (`.dev-cache/`) inside the checkout root, keeping runtime state strictly isolated from installed `novim` and standard Neovim configurations.
- Excludes networking, update, and uninstallation routines.
- Forwards arbitrary Neovim flags (e.g. `--headless`, buffers, files) to `nvim`.
- On an interactive TTY launch, both commands render the bounded (approximately
  one second) oh-my-code ANSI startup splash before starting Neovim. The
  launcher consumes `--no-animation` (never forwarded to Neovim) and honors
  `OHC_NO_ANIMATION=1`; help, version, `--headless`, piped (non-TTY), and test
  launches skip the splash and start immediately. The splash performs no
  network call, credential flow, plugin load, or background process.

Identity boundary:

- `ohc --version` reports `oh-my-code (ohc) <VERSION>-dev` with the Neovim
  engine line, and `ohc --help` names `oh-my-code` as the public command.
- `novim-dev --version` keeps the `novim-dev <VERSION>-dev (custom checkout)`
  identity and explicitly labels itself as a one-release compatibility alias
  for `ohc`; `novim-dev --help` repeats the alias status.
- Both commands resolve the same isolated runtime boundary below the checkout,
  so settings persisted through either command name remain valid.
- `bin/novim` remains the preserved upstream reference and is not modified by
  either launcher.

### Local installation / linking

To make the public launcher accessible from any terminal without overwriting
the installed `novim`:

```bash
ln -sf /Users/mert/novim-custom/bin/ohc ~/.local/bin/ohc
```

Verification:
- `ohc --version` reports the public launcher without network activity.
- `novim-dev --version` remains available and explicitly labels the one-release compatibility alias.

### Local derivative packaging

`bin/novim-dev-package` is the pre-release offline, allowlist-based
distribution helper. The public package/installer migration is planned
separately. The pre-release package continues to stage `bin/novim-dev` and its
`<VERSION>-dev (custom checkout)` identity; migrating the packaged launcher and
installer to the public `ohc` identity is part of the separate package-migration
task (`TASK-017`):

- `package ARCHIVE` stages `bin/novim-dev`, the complete `config/nvim` tree,
  `VERSION`, `LICENSE`, and `THIRD_PARTY_LICENSES.md` into a deterministic
  `novim-custom-<VERSION>.tar.gz` archive;
- the archive excludes Git metadata, `.dev-*` state, credentials, and private
  runtime data and does not include the upstream `bin/novim` command; and
- `install ARCHIVE INSTALL_ROOT` extracts only into a new or empty, explicitly
  named derivative root. A launcher link, when desired, is user-created at
  `~/.local/bin/novim-dev`; the installed `novim` path is never a target.

Package creation and installation perform no network or Git history action.
The manifest, temporary-target verification, and removal boundaries are
documented in `docs/LOCAL_DISTRIBUTION.md`. Explicit upstream comparison and
integration is documented separately in `docs/UPSTREAM_SYNC.md`.

## Local testing and regression smoke layer

Deterministic local validation is provided through standalone scripts without external dependencies:

- `./tests/run_tests.sh`: runs all test suites, including the unit/integration suite (`tests/test_workbench.lua`) and the regression smoke runner. Supports `--smoke` / `-s` to run only smoke checks, or `--all` / `-a` to run both.
- `./tests/run_smoke_tests.sh`: dedicated end-to-end regression smoke runner. It exercises:
  1. Public CLI identity (`ohc --version`, `-v`, `--help`), including checkout version semantics and the compatibility note.
  2. Compatibility alias CLI identity (`novim-dev --version`, `-v`, `--help`), including the explicit one-release alias labeling.
  3. Working directory independence (invoking from `/tmp`) and symlink path resolution for both commands, with exact isolated config/data/state/cache paths.
  4. Isolation from installed `novim` (`~/.local/share/novim` remains untouched).
  5. File-argument passthrough for both commands.
  6. Interactive splash coverage: a PTY matrix renders the bounded splash,
     measures its duration against the one-second bound, and verifies the
     `--no-animation` and `OHC_NO_ANIMATION=1` bypasses plus the help, version,
     `--headless` (even with a TTY stdout), and piped non-TTY bypasses for both
     commands.
  7. Headless Neovim execution of `tests/test_smoke.lua` under the public `ohc` launcher against isolated temporary Git/project fixtures, verifying two-pane layout, divider constraints, independent Files/Diff geometry persistence and clamping, view switching, source preview/editing handoff, unsaved buffer preservation, settings persistence/malformed fallback, and byte-for-byte Git read-only invariance.
  8. Post-run artifact cleanup verification ensuring zero fixture residue and an unchanged tracked product source tree.

## Accepted target direction

The accepted next target is a read-only multi-pane diff workbench:

- Files view: left lazy project tree and right source preview;
- Diff view: left changed-file list, middle old-file content, and right
  new-file content;
- every visible pane boundary: mouse-draggable and width-constrained;
- project tree: root-only at launch, with session-only double-click folder
  expansion and on-demand child scanning;
- settings: an in-app panel with six built-in themes, dot-folder visibility,
  and an accurate key-help section;
- Git: local status/history/diff inspection plus file-level stage/unstage and
  local staged commit, with no push, pull, checkout, discard, amend, or other
  unbounded repository mutation;
- initial diff baseline: working tree versus `HEAD`, including untracked files;
- diff entry: refresh Git status and selected content on entry, while keeping
  continuous background polling out of scope;
- text diff presentation: old content on the left and new content on the
  right, with red removed lines and green added lines;
- settings: persisted locally between launches;
- dot-folders: hidden by default and revealed through a settings toggle;
- extensions: no plugin manager or third-party plugin dependency for the first
  workbench slices.

Selected branch or historical-commit comparisons are future scope and are not
required for the first workbench slice.

## Implemented successor behavior

- `TASK-010` persists logical, per-view pane geometry in the isolated settings
  file. Files stores its left/right split; Diff stores its two visible
  boundaries. Window and buffer IDs remain runtime-only, and values are
  clamped against the current terminal width and pane minimums. Missing,
  malformed, or impossible values fall back safely without replacing the live
  layout on a settings-write failure.
- `TASK-011` gives Settings a session-only focused-control model, immediate
  Esc close, context-aware theme navigation, and a visible mouse close
  affordance while preserving persisted settings and geometry.
- `TASK-012` provides the four-area Source Control layout with current
  changes above a full current-branch history graph and read-only two-endpoint
  comparison.
- `TASK-013` provides file-level local stage/unstage and local staged commit
  with a transient message input, bounded notices, and no remote or
  history-rewriting Git actions.

## Accepted successor slices (not yet implemented)

- `TASK-014` will make the Files-view preview/edit handoff more direct:
  mouse-completed selections in editable file buffers auto-copy to the local
  system clipboard, `Esc` returns directly from every editor mode to the same
  file's Preview, and modified buffers require explicit confirmation before
  returning without saving. The bottom editor statusline will explain these
  controls. Preview/Diff read-only panes, keyboard-only auto-copy, auto-save,
  and remote clipboard synchronization remain outside this slice.

## Preserved contracts

- Public/user command: `ohc` is the public command; `novim-dev` is a temporary
  compatibility alias; installed `novim` remains unchanged.
- Configuration isolation: the derivative must not load or overwrite the
  user's normal Neovim config.
- Editing behavior: Ctrl/Cmd save, undo, copy, paste, mouse interaction, and
  safe quit remain available unless an accepted task changes them.
- License and attribution: retain MIT and third-party notices.
- Privacy: no source, credentials, or raw private data leave the machine by
  default.

## Accepted public release direction

- Implemented in `TASK-016`: `ohc` and `novim-dev` render a bounded
  approximately-one-second ANSI splash on interactive TTY launches only.
  `--no-animation` and `OHC_NO_ANIMATION=1` disable it, the flag is consumed by
  the launcher and never forwarded to Neovim, and help, version, headless,
  piped, and test launches skip it. A local PTY smoke matrix verifies the
  rendering, the duration bound, and every bypass; hosted demo capture remains
  `TASK-018` scope.
- The first public release is `v1.0.0`, delivered through a GitHub Release
  and a dedicated installer. Release assets use the `oh-my-code` identity and
  never target the installed upstream `novim` paths.
- The public README uses a real terminal GIF and explanatory architecture
  graphic; synthetic or unobserved hosted claims are not release evidence.

## Known risks and unknowns

- The current config is intentionally compact but monolithic; plugin growth
  could make behavior harder to reason about.
- netrw and floating terminal buffers may not provide the full file/diff
  navigation expected from VS Code.
- No dedicated repository test suite was observed in the upstream clone.
- The three-area layout must remain usable at narrow terminal widths; minimum
  pane widths and behavior when a file is binary or deleted need explicit
  local tests.
