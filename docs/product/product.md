# Product Brief

Updated: 2026-08-30
Status: `ACCEPTED FOR IMPLEMENTATION`

## Outcome

Create oh-my-code, a friendly terminal-first code workbench that feels like
the VS Code workbench inside a terminal: browse a project lazily, read code,
edit files, and inspect local Git changes through a responsive multi-pane
interface.

The public product must be runnable through `ohc` so it cannot overwrite the
installed upstream `novim` configuration or the user's personal Neovim
configuration. The old `novim-dev` name remains a one-release compatibility
alias.

## Users and problem

- Primary users: terminal-first developers who want a friendly editor without
  learning Vim modes.
- Problem: the current novim experience is pleasant for basic editing, but
  some repository navigation, code-review, and project-specific workflows need
  a more deliberate interface.

## Required behavior

- Preserve the existing novim-friendly editing model and standard shortcuts
  unless a task explicitly changes them.
- Launch through the independent public `ohc` command. Keep `novim-dev` as a
  compatibility alias for the first public release only.
- Keep development configuration, writable runtime data, and state isolated
  from installed upstream `novim` and the user's normal Neovim configuration.
- Show a VS Code-like workbench. Files view has a project tree on the left and
  a source preview on the right. Diff view has three areas: changed files on
  the left, the old file in the middle, and the new file on the right.
- Start the project browser with only immediate visible entries from the
  working directory. Do not recursively scan descendants until a folder is
  expanded; folder expansion/collapse is triggered by double-click and is
  session-only.
- Let each visible pane boundary be resized with the mouse by dragging it
  wider or narrower, with sensible minimum widths.
- Provide a visible settings menu/panel with six built-in themes, beginning
  with Tokyo Night as the default and including Nord, Gruvbox Dark, Catppuccin
  Mocha, One Dark, and Solarized Light.
- Show a key-help section below the settings controls. It must document the
  actual navigation, toggle, refresh, pane, and close shortcuts, including
  that `Esc` closes settings immediately.
- Support local repository browsing and read-only Git inspection without
  sending source code or credentials to a service by default.
- Keep Git operations local and bounded: status, history, diff inspection,
  file-level stage/unstage, and local staged commits are in scope; push, pull,
  fetch, merge, rebase, checkout, discard, amend, remote synchronization,
  credentials, and partial-line staging are out of scope.
- Use the working tree compared with `HEAD` as the initial diff baseline, and
  include untracked files in the review surface.
- Refresh Git status and the selected diff when entering the Diff view. A
  continuous background polling loop is not required for this slice; `r`
  remains the explicit manual refresh command.
- Render text diffs side-by-side with the old content on the left and the new
  content on the right. Removed lines use red styling and added lines use
  green styling. There is no user-selectable unified-diff fallback.
- Persist display settings locally between launches.
- Hide dot-prefixed files and folders by default, with a settings toggle to
  reveal them; no special allowlist is required in the first slice.
- Keep the initial feature set self-contained; no plugin manager or third-party
  Neovim plugin is required for the planned workbench.
- Make every new workflow observable and testable from a local terminal.

## Non-goals and constraints

- Do not attempt to reproduce all of VS Code, an IDE debugger, or a hosted code
  review service in the first milestone.
- Do not add a unified-diff display mode to the initial side-by-side contract.
- Do not add unbounded Git mutations, remote operations, AI execution, or
  credential handling without a separate explicit decision.
- Do not modify the installed release under `~/.local/share/novim` or the
  installed `novim` command as part of the public workflow.
- Do not require users to learn Vim commands for the core editing path.
- Do not introduce plugins merely to implement the first workbench slice.
- Keep upstream attribution and MIT license notices intact.

## Accepted scope decisions

The next workbench milestone is split into three implementation slices:

1. Fast startup with a root-only, lazy project tree and session-only
   double-click expansion.
2. Six built-in themes, settings key help, immediate settings close, and
   reliable mouse resizing.
3. A three-area, read-only side-by-side Git diff with refresh on entry.

Comparing selected branches or historical commits remains future scope and is
not part of this milestone.

## Successor brief (accepted 2026-08-30)

The 2026-08-30 usability milestone was split into ordered slices. TASK-010
delivered independent Files and Git Diff pane geometry persistence. TASK-011
now makes Settings act like a focused option menu rather than a freely
navigable text buffer. The Settings interaction should use a visible
selected-control arrow; Up/Down
should move only between controls; Left/Right should change the theme only
when the theme control is selected; Space should activate the selected
control; `Esc` should close immediately and be documented; and a top-right
mouse close affordance should be available.

The requested Git direction is a terminal version of the VS Code Source
Control workflow: current changes/status above, current-branch commit and
merge history below, and selectable history entries. The full graph reachable
from the current branch is shown, including merge nodes. The user chooses two
revision/location endpoints for comparison; the default remains the current
working tree versus `HEAD`, and selecting history must never check out a
branch. Local stage/unstage and a user-entered local staged commit are
authorized. Push, pull, fetch, merge, rebase, branch checkout, discard,
amend, remote synchronization, credential handling, and partial-line staging
remain excluded unless separately authorized.

This accepted successor direction is recorded in ADR-004. It expands the
future workbench scope without changing the already accepted behavior of
TASK-001 through TASK-009.

## Editor interaction brief (TASK-014, accepted 2026-08-30)

TASK-014 makes the existing Files-view preview/edit handoff feel more direct
for terminal-first users. `Space` continues to show the selected file in the
read-only Preview; opening a regular file continues to load its real editable
buffer in the right pane.

- A mouse-completed text selection in an editable file buffer is copied
  automatically to the local system clipboard. Preview and read-only Diff
  panes do not auto-copy, and keyboard-only selection does not gain a new
  automatic side effect. Existing explicit Ctrl/Cmd copy, cut, paste, save,
  and undo behavior remains available.
- `Esc` returns directly from Insert, Normal, or Visual mode to the same
  file's Preview. It does not pause in Normal mode first.
- If the editable buffer has unsaved changes, `Esc` first asks whether to
  return to Preview without saving. Confirming returns to Preview without
  saving or discarding the in-memory buffer; `No` or `Esc` cancels the prompt
  and keeps the editable buffer active.
- The existing bottom editor statusline hint area also explains the mouse
  auto-copy behavior and `Esc: Preview`, alongside the existing copy, cut,
  paste, save, and undo hints.

This decision is recorded in ADR-005. It changes only the local editor
interaction contract; no hosted clipboard, background synchronization,
credential handling, or unrelated workbench behavior is implied.

## Public release brief (accepted 2026-08-30)

The product is now named `oh-my-code` and is intended for terminal-first
developers who want a discoverable, VS Code-like code interface without
leaving the terminal. The public command is `ohc`; `novim-dev` remains a
one-release compatibility alias, while the installed upstream `novim` stays
untouched.

The first public release target is `v1.0.0`. It will use a dedicated
`~/.local/share/oh-my-code` installation root and `~/.local/bin/ohc` command
link, with safe handling for the compatibility alias. A one-second animated
ANSI opening screen is shown only on interactive TTY launches and can be
disabled with `--no-animation` or `OHC_NO_ANIMATION=1`; non-interactive,
help/version, headless, and test launches do not wait for it.

The release README is a public product surface. It will explain the terminal
workbench, Files/Preview and Source Control flows, standard shortcuts,
installation boundaries, and local-only behavior using a real terminal demo
GIF and a compact architecture graphic. It must keep upstream and third-party
attribution and distinguish local validation from hosted release evidence.

## Files mutation brief (TASK-020/TASK-021, accepted 2026-09-03)

The Files view will evolve from a browser and preview surface into a bounded
local project panel in two stages. `TASK-020` adds creation of regular files
and directories plus complete-name renaming of files and directories.
`TASK-021` adds bounded copy, paste, and move now that the first mutation slice
is accepted, together with contextual bottom-bar guidance for file operations.

The actions are discoverable through a Files-pane context menu and through
these context-aware shortcuts: `n` creates a file, `N` creates a folder, and
`F2` renames the selected item. The existing `r` refresh shortcut remains
unchanged. Name entry is bounded: `Enter` confirms and `Esc` cancels.

Creation targets the selected directory, the containing directory of a
selected file, or the project root when no usable selection exists. Rename
edits one complete name component, so changing a file extension is supported.
Dot-prefixed names are allowed explicitly and continue to follow the existing
dot-file visibility setting.

All current-stage mutations remain local and fail closed. Absolute paths,
parent traversal, path separators, NUL characters, symlinked sources or
parents, project-root mutation, outside-root resolution, special files, and
existing targets are rejected without overwrite. TASK-021 keeps one copied
source in a session-local clipboard, supports regular files and directories,
and uses atomic no-replace moves; it does not use the operating-system
clipboard. Successful operations refresh the visible lazy tree and preview,
keep unaffected expansion state, and follow the new selection. An open moved
file preserves its in-memory buffer and unsaved content under the new path; it
is never silently saved or discarded.

The bottom statusline is context-aware. The Files navigation pane displays the
actual valid create, rename, copy, paste, move, menu, and refresh shortcuts;
Preview/editor and Diff/history panes display their own mappings; context menus
and name inputs display navigation and confirmation/cancellation keys. Text
and notices remain bounded at narrow terminal widths, with errors and
confirmation states taking priority over ordinary hints.

Deletion, overwrite, duplication-with-suffix, bulk actions, drag-and-drop, Git
writes, remote operations, system-clipboard integration, and network access are
not part of this brief. Recursive directory copy is limited to regular-file
and directory descendants with preflight and cleanup on failure.
