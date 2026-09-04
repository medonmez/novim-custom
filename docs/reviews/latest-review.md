# Latest Review

Updated: 2026-09-04
Task ID: `TASK-021`
Local verdict: `CHANGES_REQUESTED`
Delivery policy: `LIGHTWEIGHT`
Baseline: `d7c6289893a04b2da021e0c2591632c319a829b9` (`origin/main`)
Reviewed candidate: `79d5bd6d54ade980cbe550f9ee93dd4edd7b56ba`
Task branch: `task/TASK-021-files-copy-paste-move`
Pull request: none
Remote checks: none; delivery not started
Merge status: not applicable
Target branch contains change: `NO`

## Review result

The correction candidate was reviewed on the recorded isolated branch with a
clean worktree. Its merge base is exactly the expected `origin/main` baseline.
The staging-collision and directory-read paths from the prior review are
covered by the correction and pass locally. The normal copy, paste, move,
targeting, menu, statusline, buffer-preservation, and existing-suite checks
also pass locally, but one cleanup failure boundary remains unsafe to accept.

## Findings

### Resolved from the prior review

The candidate now reserves file staging paths with exclusive creation and
directory staging roots with exclusive `mkdir`, and leaves pre-existing
collision sentinels untouched. It also distinguishes `fs_readdir` errors from
EOF, rejects non-ENOENT cleanup inspection failures, closes directory handles
on the reported error paths, and propagates the directory cleanup failure
tested by `test_task021_staging_collisions_and_cleanup_error_propagation`.

### P1 - A cleanup lstat error can hide cleanup failure and leave staging residue

After a file-copy failure, `copy_file_contents` unlinks the staging path at
`config/nvim/lua/novim/browser.lua:817`, but only reports `cleanup failed` when
the following `uv.fs_lstat(dst_path) ~= nil` succeeds at line 818. If unlink
fails and lstat itself fails with a non-ENOENT error, the expression is false,
so the function returns only the original copy error even though the staging
file may still exist. The file rename-failure cleanup at lines 1118-1119 has
the same error-classification problem.

This was independently reproduced locally with a temporary fixture by
injecting a source read error, an `EACCES` unlink failure, and an `EACCES`
staging-path lstat failure. The result was:
`ok=false err=Failed to read from source: EIO staging_exists=true`.
The required cleanup context was absent and the staging file remained.

Required correction: after an unsuccessful unlink, treat only an explicit
ENOENT result from lstat as confirmation that cleanup completed; propagate a
non-ENOENT lstat error as `cleanup failed` (including the original operation
error), and add deterministic coverage for both copy-failure and
rename-failure cleanup paths.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Files menu, `y`/`p`/`M`, preserved `m` and Diff `c` mappings | PASS locally | `test_task021_context_menu_copy_paste_move_and_shortcuts` passes. |
| Session clipboard, same-basename copy, repeated paste | PASS locally | `test_task021_copy_paste_files_and_directories_and_repeated_paste` passes. |
| File/directory move, source removal, clipboard clearing | PASS locally | `test_task021_move_file_and_directory_and_buffer_preservation` passes. |
| Root, nested, file-parent, no-selection targeting and descendant refusal | PASS locally | `test_task021_targeting_root_nested_file_parent_and_no_selection` passes. |
| Collision and ordinary no-overwrite invariance | PASS locally | `test_task021_collision_and_no_overwrite_invariance` passes. |
| Static symlink, special-file, stale-source, root, outside-root, and unavailable-primitive boundaries | PASS locally | `test_task021_fail_closed_security_boundaries` passes. |
| Recursive-copy preflight, partial cleanup, and staging ownership | FAIL / correction required | Collision and directory-read corrections pass, but an independent cleanup-lstat probe leaves a staging file and hides the cleanup failure. |
| Refresh, Preview, selection follow, and expansion migration | PASS locally | Copy/move integration tests pass. |
| Open moved buffers and unsaved content | PASS locally | File and descendant-buffer assertions pass. |
| Rendered context-aware statusline with no Diff/Preview mutation hints | PASS locally | `test_task021_context_aware_statusline_rendering_and_bounds` passes. |
| Narrow statusline/error visibility | PASS locally | The 26-column bounded/error-priority assertions pass. |
| Canonical key-help correspondence | PASS locally | Existing key-help and TASK-021 mapping checks pass. |
| Existing workbench/package/smoke compatibility | PASS locally | 73/73 workbench tests, offline package/installer suite, and 9/9 smoke tests pass. |

## Validation performed

- Read `AGENTS.md`, `docs/repository.md`, `project-state.md`, the current
  task, backlog, prior review, architecture, product brief, and ADR-007.
- Confirmed the checked-out branch is
  `task/TASK-021-files-copy-paste-move`, its worktree is clean, and
  `git merge-base HEAD origin/main` equals the recorded baseline.
- Inspected the complete baseline-to-candidate delta. Protected
  `bin/novim` and `config/nvim/init.lua` are unchanged.
- Reran `bin/novim-dev -u config/nvim/init.lua --headless -c "luafile
  tests/test_workbench.lua"`: 73/73 passed.
- Reran `./tests/run_tests.sh`: 73/73 workbench tests passed, the offline
  package/installer suite passed, and the regression smoke suite passed 9/9.
- Reran the applicable `bash -n` checks and `git diff --check`; both passed.
- Ran a local cleanup-lstat probe; it reproduced hidden cleanup failure and
  staging residue as described in P1 above.

All test and probe results above are local observations. No production,
recovery, hosted, or customer-acceptance evidence is claimed. No push, PR, or
merge was performed.

## Delivery decision

`CHANGES_REQUESTED`. Keep TASK-021 active on the same isolated branch and
return it to `$stateless-implementer` for the remaining P1 cleanup-error
correction and focused regressions. Do not push or open a PR until the
corrected candidate receives a new local `APPROVED` verdict.

## Next action

Implement the remaining cleanup-lstat error handling on
`task/TASK-021-files-copy-paste-move`, add copy- and rename-cleanup regression
coverage, then rerun the focused and full local validation before requesting
review again.
