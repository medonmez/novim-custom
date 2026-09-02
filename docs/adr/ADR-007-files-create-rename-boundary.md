# ADR-007: Files Create and Rename Boundary

- Status: `ACCEPTED FOR IMPLEMENTATION`
- Date: 2026-09-03
- Scope: `TASK-020` Files create/rename slice

## Decision

1. The Files view becomes a bounded local filesystem surface in two stages.
   `TASK-020` adds creation of regular files and directories plus renaming of
   regular files and directories. Copy, paste, and move are deferred to
   `TASK-021` and are not part of the current implementation task.
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

## Rationale

The current Files view already owns project-root discovery, lazy expansion,
selection, preview rendering, and isolated local runtime state. Adding a small
and explicit create/rename surface makes it more useful for everyday project
work without importing a plugin or exposing broad filesystem operations.
Separating copy/paste/move keeps the first mutation slice reviewable and gives
the later clipboard semantics their own safety contract.

## Consequences

- Files operations are local-only and do not stage, commit, push, pull, fetch,
  checkout, or otherwise mutate Git state.
- The implementation must use the existing Files view and preserve the
  lazy-tree, dot-folder, preview, pane, launcher-isolation, and installed
  `novim` boundaries.
- Failure paths must leave the project tree, open buffers, and unrelated paths
  unchanged apart from an explicit bounded notice.
- `TASK-021` remains proposed future scope for copy, paste, and move; its
  source/target selection, overwrite, and clipboard behavior must be defined
  before implementation.
