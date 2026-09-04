# Latest Review

Updated: 2026-09-04
Task ID: `TASK-021`
Local verdict: `CHANGES_REQUESTED`
Delivery policy: `LIGHTWEIGHT`
Baseline: `d7c6289893a04b2da021e0c2591632c319a829b9` (`origin/main`)
Reviewed candidate: `f7e1796998ca1fbcdca026467bb1b3d1121ac127`
Task branch: `task/TASK-021-files-copy-paste-move`
Pull request: none
Remote checks: none; delivery not started
Merge status: not applicable
Target branch contains change: `NO`

## Review result

The candidate was reviewed on the recorded isolated branch with a clean
worktree. Its merge base is exactly the expected `origin/main` baseline. The
complete delta is scoped to TASK-021 implementation, deterministic tests, and
the associated planning/current-task records. The normal copy, paste, move,
targeting, menu, statusline, buffer-preservation, and existing-suite checks
pass locally, but the filesystem failure boundary is not safe to accept yet.

## Findings

### P1 - A staging-name collision can delete a pre-existing unrelated path

`config/nvim/lua/novim/browser.lua:773-776` opens a file staging path
exclusively, but `copy_entry` unconditionally unlinks that path at
`1080-1081` when the open fails. The directory path has the same ownership
problem: `copy_directory_recursive` fails at `867-870`, then `copy_entry`
recursively removes the path at `1063-1066`. A failed operation must never
remove a path it did not create.

This was independently reproduced locally by fixing `uv.hrtime()` to
`123456`, pre-creating the target sentinel
`.tmp_copy_file_123456_source.txt`, and calling `browser.copy_entry`. The
operation returned the expected `EEXIST` failure, but the sentinel no longer
existed. This violates the no-overwrite and unrelated-path invariance
contract.

Required correction: reserve the staging path atomically and track ownership
of every created staging root/file. On any collision, fail without cleanup of
the pre-existing path; on later failures, clean only paths created by this
operation. Add deterministic file and directory staging-collision regressions.

### P1 - Directory read and cleanup errors are treated as success or hidden

`uv.fs_readdir()` returns an entries table plus optional error values; an empty
table is the end-of-directory result. The loops at
`browser.lua:734-735`, `824-825`, and `877-879` treat `nil` entries as normal
end-of-directory. A read/permission error can therefore make preflight pass or
finalize an incomplete recursive copy. In addition, cleanup results are
ignored at `1065`, `1071`, and `1080`, and `remove_path_recursive:726-727`
treats any `lstat` failure as if the path were already absent. Cleanup failure
can leave residue while the original operation still reports only its first
error.

Required correction: distinguish empty end-of-directory from read errors,
close handles on every error path, propagate cleanup failure (while retaining
the original failure context), and add deterministic read-failure and cleanup
failure/partial-residue coverage.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Files menu, `y`/`p`/`M`, preserved `m` and Diff `c` mappings | PASS locally | `test_task021_context_menu_copy_paste_move_and_shortcuts` passes. |
| Session clipboard, same-basename copy, repeated paste | PASS locally | `test_task021_copy_paste_files_and_directories_and_repeated_paste` passes. |
| File/directory move, source removal, clipboard clearing | PASS locally | `test_task021_move_file_and_directory_and_buffer_preservation` passes. |
| Root, nested, file-parent, no-selection targeting and descendant refusal | PASS locally | `test_task021_targeting_root_nested_file_parent_and_no_selection` passes. |
| Collision and ordinary no-overwrite invariance | PASS locally | `test_task021_collision_and_no_overwrite_invariance` passes. |
| Static symlink, special-file, stale-source, root, outside-root, and unavailable-primitive boundaries | PASS locally | `test_task021_fail_closed_security_boundaries` passes. |
| Recursive-copy preflight, partial cleanup, and staging ownership | FAIL / correction required | No mid-copy or staging-collision regression exists; the independent staging-collision probe deletes its sentinel. |
| Refresh, Preview, selection follow, and expansion migration | PASS locally | Copy/move integration tests pass. |
| Open moved buffers and unsaved content | PASS locally | File and descendant-buffer assertions pass. |
| Rendered context-aware statusline with no Diff/Preview mutation hints | PASS locally | `test_task021_context_aware_statusline_rendering_and_bounds` passes. |
| Narrow statusline/error visibility | PASS locally | The 26-column bounded/error-priority assertions pass. |
| Canonical key-help correspondence | PASS locally | Existing key-help and TASK-021 mapping checks pass. |
| Existing workbench/package/smoke compatibility | PASS locally | 72/72 workbench tests, offline package/installer suite, and 9/9 smoke tests pass. |

## Validation performed

- Read `AGENTS.md`, `docs/repository.md`, `project-state.md`, the current
  task, backlog, prior review, architecture, product brief, and ADR-007.
- Confirmed the checked-out branch is
  `task/TASK-021-files-copy-paste-move`, its worktree is clean, and
  `git merge-base HEAD origin/main` equals the recorded baseline.
- Inspected the complete baseline-to-candidate delta. Protected
  `bin/novim` and `config/nvim/init.lua` are unchanged.
- Reran `bin/novim-dev -u config/nvim/init.lua --headless -c "luafile
  tests/test_workbench.lua"`: 72/72 passed.
- Reran `./tests/run_tests.sh`: 72/72 workbench tests passed, the offline
  package/installer suite passed, and the regression smoke suite passed 9/9.
- Reran the applicable `bash -n` checks and `git diff --check`; both passed.
- Ran a local staging-collision probe; it reproduced deletion of a sentinel
  path as described in P1 above.

All test and probe results above are local observations. No production,
recovery, hosted, or customer-acceptance evidence is claimed. No push, PR, or
merge was performed.

## Delivery decision

`CHANGES_REQUESTED`. Keep TASK-021 active on the same isolated branch and
return it to `$stateless-implementer` for the two P1 corrections and focused
regressions. Do not push or open a PR until the corrected candidate receives a
new local `APPROVED` verdict.

## Next action

Implement the required staging ownership and read/cleanup error handling on
`task/TASK-021-files-copy-paste-move`, then rerun the focused and full local
validation before requesting review again.
