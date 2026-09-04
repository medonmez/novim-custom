# Current Task

Updated: 2026-09-04
Task ID: `TASK-021`
- Status: `CHANGES_REQUESTED`
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
record. The first implementation candidate was reviewed and has two blocking
filesystem failure-boundary findings recorded in
`docs/reviews/latest-review.md`.

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

- Status: `CHANGES_REQUESTED`
- Candidate commit: `f7e1796998ca1fbcdca026467bb1b3d1121ac127`
- Baseline: `d7c6289893a04b2da021e0c2591632c319a829b9`
- Task branch: `task/TASK-021-files-copy-paste-move`
- Implementation agent: `$stateless-implementer`
- Change summary:
  - Implemented bounded local copy, paste, and move in `browser.lua` (`validate_copy_source`, `validate_move_source`, `copy_entry`, `move_entry`, `remove_path_recursive`), using staged temp files/folders, preflight checking for symlinks and non-regular descendants, atomic no-replace finalization, and fail-closed cleanup.
  - Added session-local in-memory Files clipboard (`files_clipboard`), left-pane shortcuts `y` Copy, `p` Paste, `M` Move, and context menu options for Copy, Paste, Move in `workbench.lua`.
  - Added dynamic, context-aware bottom statusline rendering across Files navigation, Preview/editor, Diff/history, context menu, and modal contexts in `workbench.lua` (`update_statusline`, `get_statusline_text`), bounded for narrow terminals with error/notice priority.
  - Documented `y`, `p`, `M` in `keymaps.lua` workbench key-help, preserving bidirectional test correspondence.
  - Added 7 deterministic integration test suites covering all criteria.
- Files changed:
  - `config/nvim/lua/novim/browser.lua`
  - `config/nvim/lua/novim/keymaps.lua`
  - `config/nvim/lua/novim/workbench.lua`
  - `tests/test_workbench.lua`
  - `docs/tasks/TASK-021-files-copy-paste-move.md`
  - `docs/tasks/current-task.md`
- Validation commands and results:
  - `bin/novim-dev -u config/nvim/init.lua --headless -c "luafile tests/test_workbench.lua"`: 72/72 PASS (0 failed).
  - `./tests/run_tests.sh`: 72/72 integration tests PASS, offline package/installer suite PASS, 9/9 smoke tests PASS.
  - `git diff --check`: PASS (0 warnings/errors).
  - `bash -n bin/ohc bin/novim-dev bin/oh-my-code-package install.sh tests/run_tests.sh tests/offline_package_test.sh`: PASS.
- Review result: `CHANGES_REQUESTED`; see `docs/reviews/latest-review.md`.
- Blocking findings:
  - Staging-path collisions can delete a pre-existing unrelated temporary path;
    staging ownership must be tracked and cleanup must be limited to paths
    created by the operation.
  - Directory read and cleanup errors are treated as success or hidden;
    distinguish read errors from end-of-directory and propagate visible cleanup
    failures.
- Local evidence: 72/72 focused workbench tests, the full offline
  package/installer suite, 9/9 smoke tests, shell syntax checks, and
  `git diff --check` pass; an independent staging-collision probe fails the
  required invariant.
- Next action:
  - Return the same task branch to `$stateless-implementer` for the blocking
    corrections and focused regressions. Do not push or open a PR yet.
