# Current Task

Updated: 2026-09-03
Task ID: `TASK-020`
- Status: `READY_FOR_REVIEW`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-020-files-create-rename`
Expected baseline: `6b8ca01312fcb1052b2fa8021606354636037b98`
Pull request: not opened
PR target: `origin/main`
Dependency: `TASK-019` (accepted in PR #36)
Detailed task record: `docs/tasks/TASK-020-files-create-rename.md`

## Outcome

Make the Files view useful for everyday project setup by adding local,
discoverable creation of files and folders and full-name renaming of files and
folders, while preserving the existing terminal workbench and filesystem
safety boundaries.

## In scope

- Create a regular file as a child of the selected directory, the selected
  file's parent, or the project root when there is no usable selection.
- Create a directory using the same target-selection rule.
- Rename a regular file or directory by editing its complete single name,
  including a file extension.
- Expose create and rename through a Files-pane context menu and keyboard
  shortcuts: `n` New File, `N` New Folder, and `F2` Rename. Keep `r` as
  Refresh.
- Use a bounded name input where `Enter` confirms and `Esc` cancels.
- Refresh the visible lazy tree and right-side preview after successful
  mutation, following the created or renamed entry when visible.
- Preserve an open file buffer's in-memory content and update its path when
  the corresponding file is renamed.
- Add deterministic local tests for success, cancellation, selection/preview
  refresh, extension changes, hidden names, and fail-closed path boundaries.

## Out of scope

- Copy, paste, move, delete, duplicate, trash/recovery, bulk operations, or
  recursive filesystem transformations. Copy/paste/move are proposed for
  `TASK-021` after this slice is accepted.
- Git stage, unstage, commit, push, pull, fetch, checkout, merge, rebase,
  discard, amend, or remote synchronization.
- Network access, plugin installation, normal Neovim configuration changes,
  installed upstream `novim` changes, or public-release changes.
- Arbitrary multi-component paths entered in the name prompt.

## Acceptance criteria

- [x] Files-pane context menu exposes New File, New Folder, and Rename for the
      appropriate selection, and keyboard shortcuts invoke the same actions.
- [x] New File creates an empty regular file at the selected directory, the
      selected file's parent, or the project root; New Folder creates a
      directory at the same resolved target.
- [x] Rename changes a file's complete basename, including its extension, and
      changes a directory's name without changing its contents.
- [x] `Enter` confirms a valid name and `Esc` cancels without filesystem or
      selection mutation; empty names, `.`/`..`, separators, NULs, absolute
      paths, invalid targets, and existing-name collisions are rejected.
- [x] Symlinked sources or parents, project-root rename attempts, and any
      resolved target outside the project root fail closed before mutation.
- [x] Dot-prefixed names can be created or renamed explicitly and obey the
      existing show-dotfiles setting in the refreshed tree.
- [x] A successful operation refreshes the visible tree and preview, keeps
      unaffected expansion state, and selects the created or renamed entry when
      it is visible.
- [x] If a renamed file is open for editing, its buffer and unsaved in-memory
      content remain intact and follow the new path; no silent save or discard
      occurs.
- [x] Failed operations produce a bounded visible error and leave the source,
      target, open buffers, Git state, unrelated paths, installed `novim`, and
      normal Neovim configuration unchanged.
- [x] Existing workbench, package, smoke, and full local test suites remain
      passing; new behavior is covered by deterministic headless fixture tests.

## Guardrails

- Keep all filesystem mutations below the current project root and validate
  with non-following metadata checks before the write.
- Never overwrite an existing path, follow a symlink for a mutation parent,
  rename the project root, or interpret user input as a multi-component path.
- Do not add a delete action in this task. Do not stage or commit new files
  automatically and do not invoke any remote Git operation.
- Preserve lazy expansion, hidden-dotfile filtering, right-pane preview
  behavior, editable-buffer safety, launcher XDG isolation, and the installed
  `novim`/normal Neovim configuration boundaries.
- Keep the context menu and keyboard shortcuts backed by real mappings and
  document them through the canonical key-help source used by the Settings
  panel.
- Do not claim copy/paste/move support until the separate `TASK-021` contract
  is planned and implemented.

## Relevant files and discovery hints

- `config/nvim/lua/novim/browser.lua`
- `config/nvim/lua/novim/workbench.lua`
- `config/nvim/lua/novim/keymaps.lua`
- `config/nvim/lua/novim/settings_ui.lua`
- `tests/test_workbench.lua`
- `tests/test_smoke.lua`
- `docs/product/product.md`
- `docs/adr/ADR-007-files-create-rename-boundary.md`

## Required validation

- Verify the task branch starts at the expected `origin/main` baseline and
  contains only this task's implementation and tests.
- Exercise create/rename through the real Files-pane callbacks and the
  context-menu/input path, not only direct filesystem helper calls.
- Test root and nested expanded directories, file-parent targeting, extension
  changes, dotfile visibility, cancellation, collisions, invalid names,
  symlink boundaries, outside-root attempts, and open-buffer preservation.
- Verify after success/failure that Git status is not staged or committed,
  unrelated fixture paths are unchanged, and no network or plugin activity is
  introduced.
- Run `bash -n` for applicable shell launchers, `./tests/run_tests.sh`, and
  `git diff --check`; classify all evidence as local.

## Implementer handoff

- Status: `READY_FOR_REVIEW`
- Candidate commit: `HEAD (handoff commit)`
- Baseline: `6b8ca01312fcb1052b2fa8021606354636037b98`
- Task branch: `task/TASK-020-files-create-rename`

### Summary of changes and review corrections

1. **Diff-view `N` mapping context separation (`config/nvim/lua/novim/workbench.lua`)**:
   - Made `N` mapping context-aware on `buf_left`: in Files view it invokes `open_new_folder_input`, while in Diff view it preserves `assign_compare_endpoint("new", "changes")`.
   - Added regression asserting `N` in Diff view assigns comparison endpoint without opening file input modal, while in Files view it opens New Folder.

2. **New Folder symlink preflight (`config/nvim/lua/novim/workbench.lua`)**:
   - Added the missing `local is_sym, sym_err = browser.is_symlink_or_has_symlink_parent(target_dir, state.root_dir)` assignment in `open_new_folder_input`.
   - Added regression verifying New Folder targeting a symlinked directory fails closed before opening the modal.

3. **Reject non-regular special files at rename (`config/nvim/lua/novim/browser.lua`, `config/nvim/lua/novim/workbench.lua`)**:
   - Enforced `st_source.type == "file" or st_source.type == "directory"` in `rename_entry` and `open_rename_input`. Non-regular nodes (FIFOs, devices, sockets) are rejected with `"Only regular files and directories can be renamed"`.
   - Added FIFO fixture regression testing rejection in both `workbench.open_rename_input` and `browser.rename_entry`.

4. **Atomic no-overwrite create and rename primitives (`config/nvim/lua/novim/browser.lua`)**:
   - Implemented `atomic_rename_noreplace`: uses Darwin `renamex_np` (`RENAME_EXCL = 4`) and Linux `renameat2` (`RENAME_NOREPLACE = 1`) via LuaJIT FFI, with POSIX `link(2)` + `unlink(2)` fallback for regular files, atomically failing with `EEXIST` on collision.
   - In `create_file`, used `bit.bor(uv.constants.O_CREAT, uv.constants.O_EXCL, uv.constants.O_WRONLY)` so file opening atomically fails on existing destination without truncation.
   - In `create_folder`, handled `uv.fs_mkdir` `EEXIST` atomically.
   - In `is_symlink_or_has_symlink_parent`, stopped parent traversal when path matches project root, preventing false positives on OS-level symlinks above root.
   - Added regressions verifying existing files are neither truncated on file creation collision nor replaced on rename collision.

5. **Fail-closed directory rename when native primitive is unavailable (`config/nvim/lua/novim/browser.lua`, `tests/test_workbench.lua`)**:
   - Completely eliminated prechecked `uv.fs_rename` directory fallback from `atomic_rename_noreplace`. If the destination exists, it returns `"Destination already exists"`; if not, it fails closed with `"Atomic directory rename without overwrite is unavailable on this platform"` without calling `uv.fs_rename`.
   - Exposed `_native_rename_available` and `_native_rename_noreplace` on `browser` so platforms without kernel no-replace primitives can be deterministically simulated and verified.
   - Added regression coverage verifying that under simulated primitive unavailability, directory rename fails closed, destination directories and contents are never replaced or overwritten, non-existent destinations are not created, and regular files continue to rename safely via POSIX link+unlink fallback.

### Verification evidence

- `git diff --check`: PASS (clean diff, no whitespace errors).
- `bash -n bin/ohc bin/novim-dev bin/oh-my-code-package install.sh tests/run_tests.sh tests/run_smoke_tests.sh tests/run_package_tests.sh`: PASS.
- `./tests/run_tests.sh`: PASS (65/65 unit/integration tests in test_workbench.lua, all package/installer suite tests, and 9/9 regression smoke tests under public ohc launcher).

### Residual risks

- None blocking. Copy, paste, and move remain deferred to proposed `TASK-021` per ADR-007.

### Next action

Run `$project-orchestrator` on `task/TASK-020-files-create-rename` for local review.
