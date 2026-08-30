# Latest Review

Updated: 2026-08-30
Task ID: `TASK-013`
Local verdict: `APPROVED`
Delivery policy: `LIGHTWEIGHT`
Baseline: `9006898cee62a7e39f08619528be927e2768a965` (`origin/main`)
Candidate: `4fef7ef6dc65259b12327718c7c5beaa9693a393`
Task branch: `task/TASK-013-local-git-writes`
Pull request: `NOT_OPEN` at review time
Remote checks: `OPTIONAL / NOT_RUN`
Merge status: `NOT_ATTEMPTED` at review time
Target branch contains change: `NO` at review time

## Review result

The candidate was independently inspected against its recorded baseline and
the prior review parent. The actual product diff remains scoped to the
TASK-013 local stage/unstage/commit surface; the three findings from the
previous `CHANGES_REQUESTED` review are corrected on the same task branch.
The accepted write boundary is unchanged: structured `vim.system` argument
vectors for `git add -- <path>`, `git reset -- <path>` (rename-aware),
`git rm --cached --force -- <path>` before the first commit, and
`git commit -m <message>`. No remote, checkout, history-rewriting, discard,
bulk/partial-line, or unrelated mutation path was found.

The restored history-pane endpoint mapping, clean-state write notices, and
selected-path preservation after commit refresh are each covered by a focused
regression. The complete local validation suite passes, including the prior
TASK-012 behavior. No unresolved correctness, scope, security, data-integrity,
or public-contract issue remains in the reviewed candidate.

## Previous findings reverified

### High — history-pane `N` mapping restored

`config/nvim/lua/novim/workbench.lua:1323` maps history-pane `N` to
`assign_compare_endpoint("new", "history")` beside `O`; `D` remains the
comparison reset. The regression
`test_history_pane_new_endpoint_mapping_restored` checks the buffer-local map,
invokes it for a selected history commit, verifies the new endpoint and
rendered marker, and verifies that the old endpoint remains `HEAD`.

### High — write notices render after the changes list empties

`config/nvim/lua/novim/workbench.lua:358-372` renders the bounded write notice
inside the clean-working-tree branch as well as the populated-changes branch.
The regression `test_write_notice_renders_when_changes_list_empties` verifies
the final local commit's visible success notice and an empty-index commit's
visible bounded failure notice, while checking that the failed attempt leaves
`HEAD` unchanged.

### Medium — selected path survives commit refresh

`config/nvim/lua/novim/workbench.lua:1243-1286` retains the selected path
around the staged commit and restores it with `file_index_for_path` after
`M.refresh()` when the path remains changed. The regression
`test_commit_refresh_preserves_selected_change_path` stages an earlier row,
selects a later changed row, commits only the staged row, and verifies the
selected path, `▶` render, comparison content, `HEAD`, and remaining status.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| File-level stage/unstage with visible staged state | PASS | Existing focused stage/unstage test passes with raw porcelain, index, worktree-byte, staged-tag/count, and selection assertions. |
| Tracked, untracked, deleted, renamed, and special paths | PASS | Special-path round-trips cover spaces, quotes, tabs, Unicode, leading dashes, arrows, deletion, and rename handling. |
| Non-empty commit message, visible rejection, and cancel | PASS | Commit-input test covers blank/whitespace rejection, transient cleanup, Esc cancellation, and no-mutation assertions. |
| Local staged commit and refresh | PASS | Local commit, unstaged-file exclusion, history refresh, endpoint preservation, clean-state notice, and selected-path regression all pass. |
| Failed writes remain consistent with bounded errors | PASS | Failure tests verify bounded notices, repository/index/HEAD invariance, staged-state retention, and clean-state error visibility. |
| TASK-012 history/comparison and existing boundaries | PASS | All 45 prior integration tests pass unchanged; restored history `N` mapping is explicitly covered. |
| No excluded Git mutation or unsafe path handling | PASS | Product diff inspection found only the four authorized local Git write forms, all through structured argv; no shell interpolation of paths/messages. |
| Focused and full local validation | PASS | `./tests/run_tests.sh` passes 52/52 integration tests, offline package tests, and 8/8 smoke tests; syntax, JSON, version, and diff checks pass. |

## Validation performed

- Read `AGENTS.md`, `docs/repository.md`, `project-state.md`, the current
  task, backlog, prior review, architecture, and ADR-004 before review.
- Confirmed the checkout is `task/TASK-013-local-git-writes`, clean, and based
  on `9006898` through the candidate; the candidate's direct parent is
  `0b58051` and its product predecessor is `c90f863`.
- Inspected the complete product diff from `origin/main` and the correction
  diff from `0b58051` to `4fef7ef`. The correction commit changes only
  `workbench.lua`, `tests/test_workbench.lua`, and this task handoff's
  `current-task.md`.
- Ran `./tests/run_tests.sh` independently: 52/52 integration tests passed,
  offline package tests passed with installed/source invariance, and 8/8
  smoke tests passed with zero fixture residue and a clean source tree.
- Ran Lua parse checks on the changed Lua files, `bash -n` on the test and
  launcher scripts, `python3 -m json.tool docs/project.json`, and
  `git diff --check`; all passed.
- Confirmed `./bin/novim-dev --version` reports
  `novim-dev 0.1.7-dev (custom checkout)` and the installed
  `/Users/mert/.local/bin/novim --version` remains `novim 0.1.7`.
- Confirmed at review time that `origin/main` remained `9006898` and the
  remote task branch remained `f6b1135`; no PR existed and no remote mutation
  had been attempted.

All evidence above is local review evidence. It is not hosted, production,
recovery, or customer-acceptance evidence.

## Delivery decision

The candidate is locally `APPROVED`. LIGHTWEIGHT delivery is authorized:
push this task branch, open one PR targeting `main`, and merge promptly if it
is mergeable and no explicit repository/provider rule blocks the merge. Do
not wait for optional checks or invent a second approval gate.

## Post-merge requirement

Only after the remote default branch contains the merged result, update
`project-state.md`, `docs/tasks/backlog.md`, `docs/tasks/current-task.md`,
`docs/project.json`, and this review record to the accepted merged state. Do
not issue a successor task until the merge is verified; no later task is
currently defined in the backlog.
