# Latest Review

Updated: 2026-09-03
Task ID: `TASK-020`
Local verdict: `CHANGES_REQUESTED`
Delivery policy: `LIGHTWEIGHT`
Baseline: `6b8ca01312fcb1052b2fa8021606354636037b98` (`origin/main`)
Candidate: `fc1ccad215b4646e7e36f3eefb37d28d10cac0ec`
Task branch: `task/TASK-020-files-create-rename`
Pull request: `NOT_OPEN`
Remote checks: `OPTIONAL / NOT_RUN`
Merge status: `NOT_ATTEMPTED`
Target branch contains change: `NO`

## Review result

The candidate is on the recorded isolated branch with a clean worktree. Its
merge base is exactly the fetched `origin/main` baseline, and the complete
delta is scoped to TASK-020 implementation, tests, and project records. The
three behavioral corrections pass the focused/full local coverage, and the
supported macOS no-replace path is exercised. Delivery is not approved because
the directory fallback still violates the task's fail-closed no-overwrite
contract.

## Findings

### High — directory rename fallback is still check-then-rename

`config/nvim/lua/novim/browser.lua:79-90` handles the directory case after the
Darwin/Linux FFI path by checking `uv.fs_lstat(new_path)` and then calling
`uv.fs_rename(old_path, new_path)`. Ordinary `uv.fs_rename` may replace a
destination that appears after the check, so this reachable fallback is not an
atomic no-replace operation. The same function is documented as an atomic,
fail-closed rename primitive, while the task guardrail says never overwrite an
existing path.

Required change: use a genuinely no-replace directory primitive on every
supported execution path, or fail closed with a bounded error when such a
primitive is unavailable. Do not fall back to prechecked `uv.fs_rename` for a
directory. Add or retain a regression that proves the fallback cannot replace
a destination when the platform-native primitive is unavailable.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Files context menu, shortcuts, and key-help documentation | PASS locally | Context-menu and mapping regressions pass; Diff-view `N` keeps the comparison action and Files-view `N` opens New Folder. |
| Create file/folder at resolved root, directory, and file-parent targets | PASS locally | Real Files-pane input tests pass, including root, nested directory, and file-parent targeting. |
| Complete-name file/directory rename | PASS locally | File, extension, directory, expansion, and open-buffer preservation tests pass; FIFO rename is rejected. |
| Validation, cancellation, collisions, and visible errors | PASS for covered paths | Input, cancellation, invalid names, symlink preflight, sequential collisions, and exclusive file creation pass. Directory fallback race remains blocking. |
| Symlink, root, and outside-root fail-closed boundaries | PASS locally | Symlinked New Folder targets, symlink sources/parents, project-root rename, and outside-root attempts are covered. |
| Dot-prefixed visibility behavior | PASS locally | `test_task020_dotfile_creation_and_visibility` passes. |
| Refresh, preview, expansion, and visible selection | PASS locally | Create/rename refresh and selection-follow behavior pass in the focused suite. |
| Open-buffer and unsaved-content preservation | PASS locally | `test_task020_rename_file_and_directory_and_buffer_preservation` passes. |
| Failure invariance and existing-suite compatibility | PARTIAL | Existing local suites pass, but the directory fallback does not meet the no-overwrite race contract. |
| Focused/full local validation | PASS | `./tests/run_tests.sh` passed 65/65 workbench tests, the offline package/installer suite, and 9/9 smoke tests; shell syntax and `git diff --check` passed. |

## Validation performed

- Read `AGENTS.md`, `docs/repository.md`, `project-state.md`, the current
  task, backlog, prior review, architecture, and ADR-007.
- Fetched `origin/main` and confirmed it remains
  `6b8ca01312fcb1052b2fa8021606354636037b98`; confirmed that it is the
  candidate's merge base. The branch is clean after validation.
- Inspected the complete candidate diff: 13 changed files, limited to the
  TASK-020 product code, deterministic tests, ADR/product records, and scoped
  project records.
- Reran `git diff --check` and the applicable shell syntax checks.
- Reran `./tests/run_tests.sh` independently: 65/65 workbench tests passed,
  the offline package/installer suite passed, and the smoke suite passed 9/9.
- Independently confirmed the checkout's macOS FFI `renamex_np` symbol is
  available and that the focused collision regressions pass. The fallback
  code path was reviewed statically because it is not active on this checkout.

All evidence above is local review evidence. No hosted, production, recovery,
or customer-acceptance claim is made.

## Delivery decision

`CHANGES_REQUESTED`. No PR, push, merge, repository rename, tag, release, or
other remote delivery action was attempted. Keep TASK-020 active on the same
branch and return it to `$stateless-implementer` for the directory fallback
correction.

## Next action

Revise `atomic_rename_noreplace` so directory renames never use a prechecked
ordinary rename as a no-overwrite fallback. Rerun `./tests/run_tests.sh` and
the required local checks, then request a new review of the same task.
