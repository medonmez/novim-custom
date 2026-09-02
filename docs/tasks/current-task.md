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

### Summary of changes

1. **Core filesystem validation and mutations (`config/nvim/lua/novim/browser.lua`)**:
   - Implemented `validate_name`: rejects empty/whitespace, `.`, `..`, path separators (`/`, `\`), and NUL bytes (`\0`).
   - Implemented `is_path_outside_root`: fail-closed realpath and parent-path traversal guarding against project-root escapes.
   - Implemented `is_symlink_or_has_symlink_parent`: non-following `uv.fs_lstat` checks ensuring neither the target path nor any directory component below `root_dir` is a symlink.
   - Implemented `resolve_create_target`: resolves target directory to selected folder, file's parent folder, or project root when no selection.
   - Implemented `create_file`, `create_folder`, and `rename_entry` with fail-closed collision, symlink, and root boundaries.

2. **Context menu and keyboard shortcuts (`config/nvim/lua/novim/workbench.lua`)**:
   - Added `n` (New File), `N` (New Folder), `<F2>` (Rename), `m` (Context Menu), and `<RightMouse>` on the Files navigation pane (`buf_left`).
   - Implemented `open_context_menu`: floating popup menu displaying New File and New Folder (plus Rename when a file or folder is selected). Navigable with `j`/`k`, `Enter`/`Space`, direct keys `n`/`N`/`<F2>`, mouse click, and cancelled with `Esc`/`q`.
   - Implemented single-line bounded name input modal (`open_file_input_modal`) with `Enter` confirmation, `Esc` cancellation, live title error feedback, and `TextChanged` error clearing.
   - Implemented open buffer migration on rename (`migrate_open_buffers_on_rename`): updates buffer name via `nvim_buf_set_name` and runs `filetype detect`, preserving in-memory unsaved content and modified state without silent save or discard.
   - Implemented directory expansion migration (`migrate_expanded_dirs_on_rename`): preserves expansion state of renamed folders and their children.
   - Connected tree refresh (`rebuild_project_view`), selection follow for visible created/renamed entries, right-pane preview refresh, and bounded visible write notice rendering.

3. **Keymap documentation (`config/nvim/lua/novim/keymaps.lua`)**:
   - Added `n`, `N`, `<F2>`, and `m or Right Click` to canonical `keymaps.workbench` documentation, preserving bidirectional sync with Settings key help.

4. **Deterministic test suite (`tests/test_workbench.lua`)**:
   - Added 6 comprehensive test suites covering context menu actions and shortcuts, file and folder creation with preview inspection, file and directory rename with buffer preservation and expansion migration, input validation and cancellation, fail-closed security boundaries, and dotfile creation and visibility.

### Verification evidence

- `git diff --check`: PASS (clean diff, no whitespace errors).
- `bash -n bin/ohc bin/novim-dev bin/oh-my-code-package install.sh tests/run_tests.sh tests/run_smoke_tests.sh tests/run_package_tests.sh`: PASS.
- `./tests/run_tests.sh`: PASS (65/65 unit/integration tests in test_workbench.lua, all package/installer suite tests, and 9/9 regression smoke tests under public ohc launcher).

### Residual risks

- None blocking. Copy, paste, and move remain deferred to proposed `TASK-021` per ADR-007.

### Next action

Run `$project-orchestrator` on `task/TASK-020-files-create-rename` for local review.
