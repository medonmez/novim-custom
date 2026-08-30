# Latest Review

Updated: 2026-08-30
Task ID: `TASK-013`
Local verdict: `CHANGES_REQUESTED`
Delivery policy: `LIGHTWEIGHT`
Baseline: `9006898cee62a7e39f08619528be927e2768a965` (`origin/main`)
Candidate: `c90f863b77aebbb5f07e69e8d86e3ffff0d5e998`
Task branch: `task/TASK-013-local-git-writes`
Pull request: `NOT_OPEN`
Remote checks: `OPTIONAL / NOT_RUN`
Merge status: `NOT_ATTEMPTED`
Target branch contains change: `NO`

## Review result

The candidate was inspected against its planning parent `f6b1135` and the
recorded `origin/main` baseline `9006898`. The product diff is scoped to the
TASK-013 local stage/unstage/commit surface, its focused integration tests, and
the current-task handoff. The structured Git write boundary is limited to
`add --`, `reset --`, `rm --cached --force --`, and `commit -m`; no remote,
checkout, history-rewriting, discard, or partial-line operation was found.

The deterministic suite passes, including the new special-path, repository
invariance, message-validation, commit, and failure tests. However, the real
diff contains one TASK-012 comparison regression and two TASK-013 UI/context
gaps. These must be corrected on the same task before delivery.

## Findings

### High — restore the history-pane `N` mapping

`config/nvim/lua/novim/workbench.lua:1295-1303` keeps the history-pane `O`
mapping but removes the existing `N` mapping that assigned the selected
history commit as the new comparison endpoint. The candidate's live buffer
probe reports `history_N=false`, while the parent maps `N` at its corresponding
`install_history_maps` block. The help and canonical keymap documentation still
promise `O / N`, so a user focused on the history pane can no longer complete
the accepted TASK-012 two-endpoint workflow.

Required change: preserve the history-pane `N` mapping and add a focused
regression assertion that invoking it assigns the selected history entry to the
new endpoint.

### High — render write notices when the changes list becomes empty

`config/nvim/lua/novim/workbench.lua:358-371` takes the clean-working-tree
branch before the `write_notice` rendering added at `:385-391`. The commit
success path sets `state.write_notice` and refreshes, but if the commit consumed
the final change the left buffer contains no `Committed:` notice. A direct
temporary-repository probe observed `notice_state=Committed: 38a48da probe
commit` and `notice_visible=false`. The same branch hides a failed empty-index
commit notice, even though `M.commit_staged()` sets the bounded error at
`:1242-1248`.

Required change: render the bounded success/error notice in the clean state
after a write attempt, and add buffer-level assertions for both a successful
commit that leaves no changes and a failed commit from an empty staged index.

### Medium — preserve the selected path across commit refresh

`config/nvim/lua/novim/workbench.lua:1256-1259` calls `M.refresh()` after a
successful commit without capturing and restoring the selected entry by path.
`M.refresh()` only clamps the numeric `state.selected_index` at `:1622-1628`.
A direct temporary-repository probe with several changed files observed
`selected_before=c.txt` and `selected_after=d.txt` when an earlier staged file
was committed and `c.txt` still existed. This violates the handoff's stated
selection-preservation contract and can move the comparison panes to a
different file after commit.

Required change: capture the selected path before the commit, refresh status and
history, and restore that path when it remains in the changed-file list; add a
regression assertion covering removal of an earlier staged entry.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| File-level stage/unstage with visible staged state | PASS | `tests/test_workbench.lua:test_stage_unstage_file_level_mutations_and_invariance`; raw porcelain state, `[M+]`, staged count, index, HEAD, worktree bytes, and selection checks pass. |
| Tracked, untracked, deleted, renamed, and special paths | PASS | `tests/test_workbench.lua:test_stage_unstage_special_paths_untracked_deleted_renamed`; spaces, quote, tab, Unicode, leading dash, arrow, deletion, and rename round-trips pass. |
| Non-empty commit message, visible rejection, cancel | PASS | `tests/test_workbench.lua:test_commit_message_validation_cancel_and_local_commit`; blank/whitespace rejection, Esc cancellation, transient-buffer cleanup, and no-mutation assertions pass. |
| Local staged commit and refresh | PARTIAL | Repository commit, staged-index behavior, history refresh, comparison direction, and pane validity pass; final-clean notice rendering and selected-path preservation fail as described above. |
| Failed writes remain consistent with bounded errors | PARTIAL | Repository/index/HEAD invariance and bounded state notices pass; a failed commit with no changed rows is not visible in the left buffer. |
| TASK-012, settings, geometry, launcher, and release boundaries | FAIL | The existing history-pane `N` endpoint mapping is removed, despite the rest of the prior 45 integration tests and smoke checks passing. |
| No excluded Git mutation or unsafe path handling | PASS | Product diff inspection found only the four authorized local Git invocation forms, all through structured `vim.system` argv. |
| Focused and full local validation | PASS | `./tests/run_tests.sh` passed 49/49 integration tests, offline package tests, and 8/8 smoke tests; syntax, JSON, version, ancestry, and `git diff --check` passed. |

## Validation performed

- Confirmed checkout `task/TASK-013-local-git-writes` is clean and exactly one
  local handoff commit ahead of `origin/task/TASK-013-local-git-writes` at
  `f6b1135`; the remote task branch and `origin/main` were not changed.
- Inspected `AGENTS.md`, `docs/repository.md`, `project-state.md`, the current
  task, backlog, previous review, architecture, ADR-004, the complete
  `c90f863` diff, and the changed product files.
- Ran `./tests/run_tests.sh` independently: 49/49 integration tests passed,
  offline package tests passed with source/installed invariance, and all 8
  smoke tests passed with zero fixture residue.
- Ran Lua load/syntax checks on changed Lua files, `bash -n` on launcher,
  package, and test scripts, `python3 -m json.tool docs/project.json`, and
  `git diff --check`.
- Confirmed `./bin/novim-dev --version` reports `novim-dev 0.1.7-dev
  (custom checkout)` and `/Users/mert/.local/bin/novim --version` reports
  `novim 0.1.7`.
- Confirmed `9006898` is an ancestor of the candidate and the product diff
  leaves settings, themes, launchers, and package files untouched.
- Ran direct headless probes for the history mapping, final-clean notice, and
  post-commit selection path. These probes use temporary repositories and are
  local review evidence only.

All evidence is local. No hosted, production, recovery, or customer-acceptance
claim is made.

## Delivery decision

Delivery is not authorized from this candidate. No push, PR, or merge was
attempted because the local review is `CHANGES_REQUESTED`. The same
`TASK-013` branch remains active for `$stateless-implementer`; no successor
task was issued.

## Next action

Restore the history-pane `N` mapping, make write notices visible when no change
rows remain, and preserve the selected change path across commit refresh. Add
focused regressions for all three cases, rerun `./tests/run_tests.sh` and the
required local checks, then return the same task for review.
