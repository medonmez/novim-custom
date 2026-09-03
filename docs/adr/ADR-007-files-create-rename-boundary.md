# ADR-007: Files Create and Rename Boundary

- Status: `ACCEPTED FOR IMPLEMENTATION`
- Date: 2026-09-03
- Scope: `TASK-020` and `TASK-021` bounded Files mutation slices

## Decision

1. The Files view becomes a bounded local filesystem surface in two stages.
   `TASK-020` adds creation of regular files and directories plus renaming of
   regular files and directories. `TASK-021` adds bounded copy, paste, and move
   for regular files and directories under the separate source/target and
   clipboard contract recorded in its task handoff.
2. The same actions are discoverable from a Files-pane context menu and from
   keyboard shortcuts. The planned shortcuts are `n` for New File, `N` for
   New Folder, and `F2` for Rename; the existing `r` refresh action remains
   refresh. New names are entered through a bounded input with `Enter` to
   confirm and `Esc` to cancel.
3. A selected directory is the target for a new child. A selected file uses
   its containing directory. With no usable selection, the project root is
   the target. Rename edits the complete single path component, including a
   file extension.
4. Every mutation is constrained to the current project root. Absolute paths,
   parent traversal, path separators in a prompted name, NUL characters,
   symlinked sources or parents, the project root itself, and targets outside
   the root are rejected before mutation. Existing targets are never
   overwritten; collisions fail closed with a bounded visible notice.
5. Dot-prefixed names may be created or renamed explicitly. They remain hidden
   when the existing dot-file setting is disabled and become visible only
   when that setting is enabled.
6. After a successful operation, the visible project tree and preview refresh
   without a background watcher. The selection follows the created or renamed
   entry where it remains visible. An open file buffer keeps its in-memory
   content and follows the new file path; no unsaved content is silently
   saved, discarded, or replaced.
7. Files operations are context-discoverable in the bottom statusline. The
   Files navigation pane shows only its active create, rename, copy, paste,
   move, menu, and refresh mappings; Preview/editor, Diff/history,
   context-menu, and bounded input contexts show their own real mappings and
   confirmation behavior. Hints and notices are bounded for narrow terminals,
   and errors or confirmation prompts take precedence over ordinary hints.
8. TASK-021 uses a session-local single-source clipboard, not the operating
   system clipboard. Copy retains the source for repeated paste; successful
   move clears the moved record. Copy/move never overwrite, truncate, merge,
   or replace an existing path. Recursive copies preflight regular-file and
   directory descendants, reject symlinks and special files, stage temporary
   output below the destination parent, and remove partial output on failure.
   Moves use atomic no-replace primitives and fail closed when unsupported.

## Rationale

The current Files view already owns project-root discovery, lazy expansion,
selection, preview rendering, and isolated local runtime state. Adding a small
and explicit create/rename surface makes it more useful for everyday project
work without importing a plugin or exposing broad filesystem operations.
Separating copy/paste/move kept the first mutation slice reviewable and gave
the clipboard semantics their own safety contract. Keeping operation hints in
the statusline makes the new mutation surface discoverable without adding a
permanent overlay or changing the established workbench layout.

## Consequences

- Files operations are local-only and do not stage, commit, push, pull, fetch,
  checkout, or otherwise mutate Git state.
- The implementation must use the existing Files view and preserve the
  lazy-tree, dot-folder, preview, pane, launcher-isolation, and installed
  `novim` boundaries.
- Failure paths must leave the project tree, open buffers, and unrelated paths
  unchanged apart from an explicit bounded notice.
- `TASK-021` is now planned future scope for copy, paste, move, and contextual
  statusline guidance. Its source/target selection, overwrite, clipboard,
  recursive-copy, and atomic-move behavior is defined in the task record before
  implementation.
