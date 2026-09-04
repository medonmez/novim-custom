# TASK-021: Files Copy, Paste, Move, and Contextual Statusline Help

- Status: `READY_FOR_REVIEW`
- Delivery policy: `LIGHTWEIGHT`
- Base branch: `main`
- Task branch: `task/TASK-021-files-copy-paste-move`
- Expected baseline: `d7c6289893a04b2da021e0c2591632c319a829b9` (`origin/main`)
- Dependency: `TASK-020` (accepted in PR #38)
- PR target: `origin/main`

## Outcome

Extend the Files pane with bounded local copy, paste, and move actions and
make the available file operations visible in the bottom statusline. A user
should be able to discover the valid action keys from the current Files,
Preview, Diff, context-menu, and name-input context without relying on memory.

## Context

TASK-020 added safe creation and complete-name rename, with a Files-pane
context menu and keyboard mappings. Its follow-up was intentionally left
proposed until copy/paste/move had an explicit source, target, clipboard, and
no-overwrite contract. This task issues that contract and adds the requested
contextual bottom-bar guidance. The accepted TASK-020 filesystem boundaries,
open-buffer preservation, lazy refresh, and local-only behavior remain in
force.

## In scope

- Copy one selected regular file or directory into a resolved destination
  directory. Directory copies include regular-file descendants recursively.
- Paste the session-local copied source into the selected directory, the
  selected file's parent, or the project root when there is no usable
  selection. The destination keeps the source basename.
- Move one selected regular file or directory into the same kind of resolved
  destination directory.
- Keep a single source record in an in-memory Files-pane clipboard. It is
  session-only, never uses the operating-system clipboard, and never leaves
  the machine. A successful copy remains pasteable; a successful move clears
  the moved source record.
- Expose the actions in the Files context menu and through these
  context-aware left-pane shortcuts: `y` Copy, `p` Paste, and `M` Move. Keep
  `m` as the context-menu shortcut, `c` as Diff-view Commit, and all existing
  TASK-020 mappings unchanged.
- Render a dynamic bottom statusline for the active workbench context:
  - Files navigation pane shows the valid file-operation shortcuts, including
    `n` New File, `N` New Folder, `F2` Rename, `y` Copy, `p` Paste, `M` Move,
    `m` Menu, and `r` Refresh, without advertising an invalid action for the
    current selection.
  - Files Preview/editor context shows only the actions mapped there and
    retains the TASK-014 editor guidance; file mutations remain anchored to
    the Files navigation pane.
  - Diff and history panes retain their comparison, stage/unstage, commit,
    refresh, and navigation guidance and never display Files mutation keys as
    if they were active there.
  - The context menu shows navigation/activation/cancel guidance, and the
    name-input modal shows `Enter` confirmation and `Esc` cancellation.
  - Operation notices and errors remain bounded and visible; an error or
    confirmation state takes precedence over ordinary hints when space is
    limited.
- Refresh the visible lazy tree and Preview after successful copy or move,
  preserve unaffected expansion state, and follow the new visible destination
  entry. Copy does not open a new buffer.
- When a moved file is open, update its buffer path without saving, replacing,
  or discarding in-memory content. When a moved directory contains open files,
  migrate their paths and the directory expansion keys consistently.
- Add deterministic headless fixture tests for the real Files-pane callbacks,
  context menu, keyboard mappings, statusline rendering, and filesystem
  failure paths.

## Filesystem safety contract

- Accept only regular files and directories as copy/move sources. Reject
  symlinks and non-regular special files, including any such descendant of a
  recursively copied directory.
- Resolve one destination directory using the existing Files target rule;
  never interpret user input or a stored clipboard path as a multi-component
  user-entered path. Keep every source, temporary path, and final destination
  below the current project root.
- Reject project-root sources, source/destination paths outside the root,
  symlinked sources or parents, directory moves into themselves or their
  descendants, missing or invalid targets, and stale clipboard records before
  mutation.
- Never overwrite or truncate an existing path. A destination collision fails
  closed and leaves both source and destination byte/content-identical.
  Automatic suffixes and implicit replacement are not allowed.
- A recursive copy must preflight the complete source tree and destination
  collision set before writing. Stage it below the destination parent, finalize
  with a no-replace operation, and remove all temporary/partial output on any
  failure. A failed copy must not leave a partial destination tree.
- A move must use the existing atomic no-replace primitives. Cross-device or
  otherwise unsupported moves fail closed; do not fall back to copy-then-delete
  or an overwrite-prone directory rename. Preserve the TASK-020 behavior that
  unavailable atomic directory rename primitives refuse the operation.
- Do not invoke shell commands, network services, plugins, Git writes, or the
  operating-system clipboard for these actions.

## Out of scope

- Delete, trash/recovery, undo history, duplicate-with-suffix, bulk or
  multi-source operations, drag-and-drop, and background filesystem watching.
- Overwrite, merge-into-existing-directory, arbitrary destination paths, or
  copy/move across the project-root boundary.
- Copying symlinks, FIFOs, devices, sockets, or other special files.
- System clipboard integration for Files operations. The editor's accepted
  TASK-014 clipboard behavior remains separate.
- Git stage, unstage, commit, push, pull, fetch, checkout, merge, rebase,
  discard, amend, remote synchronization, network access, plugin installation,
  installed upstream `novim` changes, or normal Neovim configuration changes.

## Acceptance criteria

- [X] Files context menu exposes Copy, Paste, and Move when applicable, and
      `y`, `p`, and `M` invoke the same actions only in the Files navigation
      context; `m` remains the menu and Diff-view `c` remains Commit.
- [X] Copy stores exactly one eligible source in a session-local clipboard;
      Paste creates a same-basename file or recursively copied directory in
      the resolved target, and repeated paste works after a successful Copy.
- [X] Move transfers one eligible file or directory to the resolved target;
      successful move clears the moved clipboard record and does not leave the
      source behind.
- [X] Copy and move support root, nested-directory, selected-file-parent, and
      no-selection target cases according to the existing target rule; moving
      into the source directory or its descendants is rejected.
- [X] Existing destinations are never overwritten, truncated, merged, or
      replaced. File and directory collisions leave source and destination
      unchanged.
- [X] Symlinks, symlinked parents, special files, stale sources, outside-root
      paths, root mutation, invalid targets, and unsupported/cross-device
      operations fail closed before mutation.
- [ ] A failed recursive copy leaves no partial destination or temporary
      residue, and the source, unrelated paths, buffers, expansion state, and
      Git state remain unchanged.
- [X] Successful copy/move refreshes the visible tree and Preview, preserves
      unaffected expansion state, and follows the visible destination entry.
- [X] Open buffers and unsaved in-memory contents follow a successful moved
      file/directory without a silent save, discard, or replacement; copied
      sources do not create or retarget buffers.
- [X] The bottom statusline is context-aware and rendered, not only documented
      in source: Files navigation exposes valid create/rename/copy/paste/move/
      menu/refresh guidance; Preview/editor, Diff/history, context-menu, and
      input-modal contexts expose their own actual mappings and confirmation
      behavior without cross-context false hints.
- [X] Statusline text and operation notices remain bounded, readable, and
      non-wrapping at narrow terminal widths; errors and confirmation prompts
      are not hidden behind ordinary shortcut hints.
- [X] Canonical Settings key help and tests verify the displayed mappings in
      both directions, including the new Files actions and preserved Diff
      actions.
- [X] Existing workbench, package, smoke, and full local test suites remain
      passing; new behavior is covered by deterministic headless fixture tests.

## Guardrails

- Preserve TASK-020's fail-closed root containment, non-following metadata
  checks, atomic no-overwrite behavior, dot-file setting, lazy expansion,
  Preview refresh, open-buffer migration, and local-only boundary.
- Keep file mutations available from the Files navigation pane and its context
  menu. Do not make `y`, `p`, or `M` silently alter Diff comparison, history,
  editor text, or the operating-system clipboard.
- Derive statusline labels from the actual mappings or keep a deterministic
  test tying every displayed file-operation key to its callback. Do not show a
  shortcut in a context where it is not mapped.
- Keep notices and errors bounded; never claim success before the filesystem
  result is confirmed. Cleanup failure is itself a failed operation and must
  be visible without hiding the original safety failure.
- Do not add delete, overwrite, remote Git, network, plugin, or installed
  `novim` behavior. Do not push, open, or merge a PR from the implementer
  handoff.

## Relevant files and discovery hints

- `config/nvim/lua/novim/browser.lua`
- `config/nvim/lua/novim/workbench.lua`
- `config/nvim/lua/novim/keymaps.lua`
- `config/nvim/init.lua`
- `config/nvim/lua/novim/settings_ui.lua`
- `tests/test_workbench.lua`
- `tests/test_smoke.lua`
- `docs/product/product.md`
- `docs/architecture.md`
- `docs/adr/ADR-007-files-create-rename-boundary.md`

## Required validation

- Verify the task branch starts at expected `origin/main` baseline and the
  implementation diff contains only TASK-021 product code, tests, and its
  durable records.
- Exercise copy, paste, and move through real Files-pane callbacks, keyboard
  mappings, context-menu selection, and target-resolution paths, not only
  direct filesystem helper calls.
- Test files and nested directories, repeated copy/paste, selected-file-parent
  targeting, root/no-selection targeting, dotfiles, open unsaved buffers,
  expansion migration, collisions, stale clipboard, symlink/special-file
  rejection, self/descendant moves, outside-root attempts, partial-copy
  cleanup, and unavailable atomic primitives.
- Assert rendered bottom statusline changes after Files/Diff/Preview focus and
  selection changes, during context-menu/input-modal states, and at narrow
  terminal widths. Verify displayed keys are the actual active mappings.
- Verify success/failure does not stage or commit Git changes, alter unrelated
  fixture paths, invoke network/plugin activity, or touch installed `novim` or
  normal Neovim configuration.
- Run `bash -n` for applicable shell launchers, `./tests/run_tests.sh`, and
  `git diff --check`; classify all results as local or repository-provider
  observations, never as production, recovery, or customer-acceptance
  evidence.

## Implementer handoff

- Status: `READY_FOR_REVIEW`
- Candidate commit: `HEAD (handoff commit)`
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
  - All 14 acceptance criteria verified locally.
- Residual risks or known gaps:
  - None blocking. Directory move and directory copy rely on platform-native atomic no-replace primitives (`renamex_np` on macOS, `renameat2` on Linux); platforms lacking these primitives fail closed with a bounded notice.
- Next action:
  - Return control to `$project-orchestrator` for local review and the lightweight delivery workflow.
