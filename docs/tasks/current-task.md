# Current Task

Updated: 2026-09-05
Task ID: `TASK-021`
- Status: `READY_FOR_REVIEW`
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
record. The correction candidate was independently reviewed and approved;
the earlier staging-collision, directory-read, and cleanup-lstat findings are
resolved. The lightweight delivery path is now pending.

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

- Status: `READY_FOR_REVIEW`
- Candidate commit: `d9dfdda78d273660a817bf726a3c7807fa2042a8`
- Baseline: `d7c6289893a04b2da021e0c2591632c319a829b9`
- Task branch: `task/TASK-021-files-copy-paste-move`
- Implementation agent: `$stateless-implementer`
- Change summary:
  - Implemented bounded local copy, paste, and move in `browser.lua` (`validate_copy_source`, `validate_move_source`, `copy_entry`, `move_entry`, `remove_path_recursive`), using staged temp files/folders, preflight checking for symlinks and non-regular descendants, atomic no-replace finalization, and fail-closed cleanup.
  - Corrected staging-path ownership (P1): staging paths are reserved exclusively (`uv.fs_open` with `"wx"` for files and `uv.fs_mkdir` for directories), and neither `copy_file_contents` nor `copy_entry` unlinks or removes staging paths that collided on creation; only paths created by this operation are ever cleaned up on failure. Pre-existing sentinel files and directories survive staging collisions untouched.
  - Corrected directory read and cleanup error handling (P1): `uv.fs_readdir` distinguishes EOF (`nil, nil`) from read errors (`nil, err`) across `remove_path_recursive`, `preflight_directory`, and `copy_directory_contents`; handles are closed on all error paths; `remove_path_recursive` treats only `ENOENT` as absent and returns failure on other `lstat` errors; directory cleanup failures are propagated alongside the original failure reason.
  - Corrected cleanup lstat error propagation (P1): implemented `cleanup_unlinked_file` in `browser.lua` which treats only an explicit `ENOENT` from `lstat` as confirmation that cleanup completed. On unlink failure, if `lstat` returns non-ENOENT (such as `EACCES` or inspection errors) or confirms file existence, `cleanup failed: <un_err> (inspection failed: <st_err>)` is propagated alongside the original failure reason, preventing hidden cleanup failures and unnoticed staging residue. Applied across `copy_file_contents`, `copy_entry` (file rename failure), and `remove_path_recursive`.
  - Added session-local in-memory Files clipboard (`files_clipboard`), left-pane shortcuts `y` Copy, `p` Paste, `M` Move, and context menu options for Copy, Paste, Move in `workbench.lua`.
  - Added dynamic, context-aware bottom statusline rendering across Files navigation, Preview/editor, Diff/history, context menu, and modal contexts in `workbench.lua` (`update_statusline`, `get_statusline_text`), bounded for narrow terminals with error/notice priority.
  - Documented `y`, `p`, `M` in `keymaps.lua` workbench key-help, preserving bidirectional test correspondence.
  - Added 9 deterministic integration test suites in `tests/test_workbench.lua`, including `test_task021_staging_collisions_and_cleanup_error_propagation` and `test_task021_copy_and_rename_cleanup_lstat_error_handling` which tests `cleanup_unlinked_file` direct branches, copy-failure cleanup paths, and rename-failure cleanup paths.
- Files changed:
  - `config/nvim/lua/novim/browser.lua`
  - `config/nvim/lua/novim/keymaps.lua`
  - `config/nvim/lua/novim/workbench.lua`
  - `tests/test_workbench.lua`
  - `docs/tasks/TASK-021-files-copy-paste-move.md`
  - `docs/tasks/current-task.md`
- Validation commands and results:
  - `bin/novim-dev -u config/nvim/init.lua --headless -c "luafile tests/test_workbench.lua"`: 74/74 PASS (0 failed).
  - `./tests/run_tests.sh`: 74/74 integration tests PASS, offline package/installer suite PASS, 9/9 smoke tests PASS.
  - `git diff --check`: PASS (0 warnings/errors).
  - `bash -n bin/ohc bin/novim-dev bin/oh-my-code-package install.sh tests/run_tests.sh tests/offline_package_test.sh`: PASS.
  - Acceptance evidence:
  - All 13 acceptance criteria listed in the canonical task record verified locally.
- Residual risks or known gaps:
  - None blocking. Directory move and directory copy rely on platform-native atomic no-replace primitives (`renamex_np` on macOS, `renameat2` on Linux); platforms lacking these primitives fail closed with a bounded notice.
- Next action:
  - Proceed with the authorized lightweight delivery workflow.
