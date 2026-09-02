# Latest Review

Updated: 2026-09-03
Task ID: `TASK-020`
Local verdict: `CHANGES_REQUESTED`
Delivery policy: `LIGHTWEIGHT`
Baseline: `6b8ca01312fcb1052b2fa8021606354636037b98` (`origin/main`)
Candidate: `80ae55fc2a5cee4fd199c06b92e6e175e5bb49b3`
Task branch: `task/TASK-020-files-create-rename`
Pull request: `NOT_OPEN`
Remote checks: `OPTIONAL / NOT_RUN`
Merge status: `NOT_ATTEMPTED`
Target branch contains change: `NO`

## Review result

The candidate is on the recorded isolated branch with a clean worktree. Its
merge base is exactly the fetched `origin/main` baseline, and the complete
delta is scoped to TASK-020 implementation, tests, and workflow records. The
full local runner passes, but the real diff contains regressions and missing
filesystem-boundary checks. Delivery is not approved until the same branch is
corrected and returned for review.

## Findings

### High — preserve the Diff-view left-pane `N` mapping

`config/nvim/lua/novim/workbench.lua:3215-3218` maps `N` to the existing
Source Control new-comparison endpoint, but `:3227-3231` then installs the
Files New Folder mapping on the same left buffer without a Files-view guard.
This overrides the accepted Diff-view mapping. A focused headless probe found
`DIFF_N_FOLDER_CALLED=true COMPARE_CALLED=false`; in Diff view the new-folder
handler then returns false, so `N` silently stops assigning the new comparison
endpoint.

Required change: make the mapping context-aware so Files view invokes New
Folder and Diff view preserves the existing comparison action. Add a real
buffer-map behavior regression.

### High — preflight symlinked New Folder targets

`config/nvim/lua/novim/workbench.lua:1933-1944` references `is_sym` and
`sym_err` without assigning them. Consequently `open_new_folder_input` skips
the symlink-parent preflight and opens its modal for a symlinked target. A
focused probe returned `NEW_FOLDER_SYMLINK_PREFLIGHT=true` for a selected
symlink directory. The lower-level `create_folder` check still prevents the
normal confirm from mutating that path, but the UI boundary does not fail
closed at target resolution as required by ADR-007.

Required change: perform the same `browser.is_symlink_or_has_symlink_parent`
check used by New File before opening the New Folder modal, report the bounded
error, and cover the refusal through the Files callback.

### High — reject non-regular special files at rename

`config/nvim/lua/novim/browser.lua:560-563` checks only that the source
`lstat` succeeds. The browser represents non-directory entries as files,
so a FIFO or other special node can reach `rename_entry` and be renamed. A
focused probe successfully renamed a temporary FIFO
(`SPECIAL_FILE_RENAME=true`). This violates the task's regular-file-or-
directory scope and expands the mutation surface to special filesystem nodes.

Required change: require the source metadata type to be a regular file or
directory, reject other types with a bounded error, and add a special-file
fixture regression.

### High — make collision handling genuinely no-overwrite

`config/nvim/lua/novim/browser.lua:458-471` performs an `lstat` precheck and
then opens the path with `"w"`, which truncates an existing path if it appears
between those operations. Similarly, `:568-577` prechecks the rename
destination and then calls `uv.fs_rename`, whose normal POSIX behavior
replaces a destination that appears after the check. The sequential collision
tests pass, but these are not atomic no-overwrite mutations and violate the
explicit collision/overwrite guardrail under a local race.

Required change: use exclusive/no-follow-safe creation and a platform-safe
no-replace rename strategy, or otherwise prove an equivalent fail-closed
primitive. Add focused coverage for the no-overwrite contract where the
platform permits deterministic simulation.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Files context menu, shortcuts, and key-help documentation | PARTIAL | The Files context menu and new actions pass the focused suite, but the Diff-view left-pane `N` mapping is overridden. |
| Create file/folder at resolved root, directory, and file-parent targets | PASS for sequential paths | `test_task020_new_file_and_folder_creation_and_preview` passes; New Folder symlink preflight is missing. |
| Complete-name file/directory rename | PARTIAL | File, extension, directory, expansion, and buffer-preservation tests pass; special-file rename is not rejected. |
| Validation, cancellation, collisions, and visible errors | PARTIAL | Input/cancellation/sequential collision tests pass; race-safe no-overwrite and New Folder preflight are incomplete. |
| Symlink, root, and outside-root fail-closed boundaries | PARTIAL | Covered file/symlink/root/outside cases pass; New Folder target preflight is missing. |
| Dot-prefixed visibility behavior | PASS | `test_task020_dotfile_creation_and_visibility` passes. |
| Refresh, preview, expansion, and visible selection | PASS for covered operations | Create/rename refresh and expansion assertions pass in the focused suite. |
| Open-buffer and unsaved-content preservation | PASS | `test_task020_rename_file_and_directory_and_buffer_preservation` passes. |
| Failure invariance and existing-suite compatibility | PARTIAL | Existing sequential failures and invariance pass; the special-file and race boundary are not covered. |
| Focused/full local validation | PASS | `./tests/run_tests.sh` passed 65/65 workbench tests, the offline package suite, and 9/9 smoke tests; shell syntax and `git diff --check` passed. |

## Validation performed

- Read `AGENTS.md`, `docs/repository.md`, `project-state.md`, the current
  task, backlog, previous review, architecture, and ADR-007.
- Fetched `origin/main` and confirmed it remains
  `6b8ca01312fcb1052b2fa8021606354636037b98`; confirmed that it is the
  candidate's merge base. The branch is clean after validation.
- Inspected the complete candidate diff: 12 changed files, limited to the
  TASK-020 product code, deterministic tests, and scoped project records.
- Reran `git diff --check` and the applicable shell syntax checks.
- Reran `./tests/run_tests.sh` independently: 65/65 workbench tests passed,
  the offline package/installer suite passed, and the smoke suite passed 9/9.
- Ran focused local headless probes for the New Folder symlink preflight, the
  Diff-view `N` mapping, and special-file rename. These are temporary local
  fixtures only; they are not hosted, production, recovery, or
  customer-acceptance evidence.

All evidence above is local review evidence. No hosted, production, recovery,
or customer-acceptance claim is made.

## Delivery decision

`CHANGES_REQUESTED`. No PR, push, merge, repository rename, tag, release, or
other remote delivery action was attempted. Keep TASK-020 active on the same
branch and return it to `$stateless-implementer` for the four findings above.

## Next action

Revise TASK-020 on `task/TASK-020-files-create-rename`: preserve the Diff-view
`N` action, restore New Folder symlink preflight, reject special-file rename,
and implement no-overwrite create/rename semantics with focused regressions.
Rerun `./tests/run_tests.sh` and the required local checks, then request a new
review of the same task.
