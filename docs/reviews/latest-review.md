# Latest Review

Updated: 2026-09-03
Task ID: `TASK-020`
Local verdict: `APPROVED`
Delivery policy: `LIGHTWEIGHT`
Baseline: `6b8ca01312fcb1052b2fa8021606354636037b98` (`origin/main`)
Candidate: `48c9c642d98b4ac8c98922dbb73dcd2d108540fe`
Task branch: `task/TASK-020-files-create-rename`
Pull request: `PENDING LIGHTWEIGHT DELIVERY`
Remote checks: `OPTIONAL / NOT_RUN`
Merge status: `NOT_ATTEMPTED`
Target branch contains change: `NO`

## Review result

The candidate is on the recorded isolated branch with a clean worktree. Its
merge base is exactly the fetched `origin/main` baseline, and the complete
delta is scoped to TASK-020 implementation, tests, and project records. The
previous four blocking findings are corrected. Directory renames now use the
native atomic no-replace primitive or fail closed with a bounded error; the
fallback regression confirms no unsafe directory rename occurs. No unresolved
correctness, security, data-integrity, regression, public-contract, or scope
issue remains for local review.

## Findings

None blocking.

Non-blocking boundary: directory rename is intentionally unavailable on
platforms without a native atomic no-replace primitive. Regular-file rename
retains the POSIX `link(2)` plus `unlink(2)` no-overwrite fallback. Copy, paste,
and move remain deferred to proposed TASK-021.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Files context menu, shortcuts, and key-help documentation | PASS locally | Context-menu and mapping regressions pass; Diff-view `N` keeps the comparison action and Files-view `N` opens New Folder. |
| Create file/folder at resolved root, directory, and file-parent targets | PASS locally | Real Files-pane input tests pass, including root, nested directory, and file-parent targeting. |
| Complete-name file/directory rename | PASS locally | File, extension, directory, expansion, and open-buffer preservation tests pass; FIFO rename is rejected. |
| Validation, cancellation, collisions, and visible errors | PASS locally | Input, cancellation, invalid names, symlink preflight, sequential collisions, and exclusive file creation pass. |
| Symlink, root, and outside-root fail-closed boundaries | PASS locally | Symlinked New Folder targets, symlink sources/parents, project-root rename, and outside-root attempts are covered. |
| Dot-prefixed visibility behavior | PASS locally | `test_task020_dotfile_creation_and_visibility` passes. |
| Refresh, preview, expansion, and visible selection | PASS locally | Create/rename refresh and selection-follow behavior pass in the focused suite. |
| Open-buffer and unsaved-content preservation | PASS locally | `test_task020_rename_file_and_directory_and_buffer_preservation` passes. |
| Failure invariance and existing-suite compatibility | PASS locally | FIFO and collision failures preserve source/destination content; unavailable directory primitives fail closed without creating a destination. |
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
- Verified the new deterministic fallback tests: native directory collision
  refusal, unavailable-native directory fail-closed behavior, regular-file
  link/unlink fallback, and fallback collision invariance.

All evidence above is local review evidence. No hosted, production, recovery,
or customer-acceptance claim is made.

## Delivery decision

`APPROVED` for lightweight delivery. The implementation is not yet accepted:
no PR has been opened and the candidate is not on the remote default branch.
Push the reviewed task branch, open or reuse one PR against `main`, confirm it
is mergeable without bypassing repository rules, merge promptly, and verify
`origin/main` before reconciling acceptance records.

## Next action

Proceed with the lightweight PR delivery workflow for
`task/TASK-020-files-create-rename`.
