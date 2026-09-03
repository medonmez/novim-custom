# Current Task

Updated: 2026-09-03
Task ID: `TASK-021`
- Status: `PLANNED`
- Delivery policy: `LIGHTWEIGHT`
- Base branch: `main`
- Task branch: `task/TASK-021-files-copy-paste-move`
- Expected baseline: `d7c6289893a04b2da021e0c2591632c319a829b9`
- Pull request: none
- PR target: `origin/main`
- Dependency: `TASK-020` (accepted in PR #38)
- Detailed task record: `docs/tasks/TASK-021-files-copy-paste-move.md`

## Outcome

Extend the Files pane with bounded local copy, paste, and move actions and
make the available file operations visible in the bottom statusline. A user
should be able to discover the valid action keys from the current Files,
Preview, Diff, context-menu, and name-input context without relying on memory.

## Scope and contract

TASK-021 owns the explicit source/target and clipboard contract left proposed
after TASK-020:

- `y` copies one selected regular file or directory into a session-local
  single-source clipboard; `p` pastes it into the resolved target directory;
  `M` moves one selected regular file or directory. `m` remains the Files
  context-menu shortcut, and Diff-view `c` remains Commit.
- Directory copies recursively copy regular-file descendants only. Symlinks,
  special files, stale sources, self/descendant moves, outside-root paths,
  root mutations, invalid targets, collisions, and unsupported/cross-device
  operations fail closed.
- Copy and move never overwrite, truncate, merge, or replace an existing path.
  Failed recursive copies remove temporary/partial output and leave the source
  and destination unchanged.
- Successful operations refresh the visible lazy tree and Preview, preserve
  unaffected expansion state, and follow the visible destination. Moved open
  buffers and unsaved content follow the new path without save/discard.
- The bottom statusline is rendered dynamically for Files navigation,
  Preview/editor, Diff/history, context-menu, and input-modal contexts. It
  shows only actual valid mappings and keeps bounded operation/error feedback
  visible at narrow terminal widths.

The complete acceptance criteria and guardrails are in the detailed task
record. No product implementation has been started by this planning handoff.

## Required validation

- Inspect the real branch delta and exercise the Files callbacks, context menu,
  keyboard actions, target resolution, recursive copy, atomic move, buffer
  migration, and cleanup paths.
- Verify rendered statusline behavior after view/focus/selection changes and
  while context menus or input modals are active; assert no Diff/Preview
  cross-context false hints.
- Cover files, nested directories, repeated paste, root/no-selection and
  selected-file-parent targets, dotfiles, collisions, symlink/special-file
  rejection, self/descendant moves, stale clipboard, partial-copy cleanup,
  unavailable atomic primitives, and open unsaved buffers.
- Run applicable shell syntax checks, `./tests/run_tests.sh`, and
  `git diff --check`. Classify all evidence as local or repository-provider
  observations, never as production, recovery, or customer-acceptance
  evidence.

## Guardrails

- Preserve TASK-020's fail-closed root containment, non-following metadata
  checks, atomic no-overwrite behavior, dot-file setting, lazy expansion,
  Preview refresh, open-buffer migration, and local-only boundary.
- Do not use the OS clipboard for Files operations, invoke shell/network/
  plugins, mutate Git, add delete/overwrite/bulk behavior, or touch installed
  `novim` or the normal Neovim configuration.
- Do not weaken the unavailable-native-directory-rename failure behavior or
  use copy-then-delete as an unsafe move fallback.

## Implementer handoff

- Status: `READY_FOR_IMPLEMENTATION`
- Candidate commit: none; planning handoff only
- Baseline: `d7c6289893a04b2da021e0c2591632c319a829b9`
- Task branch: `task/TASK-021-files-copy-paste-move`
- Implementation agent: `$stateless-implementer`
- Next action: read `docs/tasks/TASK-021-files-copy-paste-move.md`, the
  repository instructions, and the latest accepted review, then implement only
  TASK-021 and return a local `READY_FOR_REVIEW` handoff.
