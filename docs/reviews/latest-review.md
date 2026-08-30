# Latest Review

Updated: 2026-08-30
Task ID: `TASK-014`
Local verdict: `APPROVED`
Delivery policy: `LIGHTWEIGHT`
Baseline: `2f72937134a3965a8c5294641c1589dd38a6a04c` (`origin/main`)
Candidate: `f4413b7` (`task/TASK-014-auto-copy-preview-exit`)
Pull request: `NOT_OPEN` at review time
Remote checks: `OPTIONAL / NOT_RUN`
Merge status: `NOT_ATTEMPTED` at review time
Target branch contains change: `NO` at review time

## Review result

The candidate was independently inspected against the recorded `origin/main`
baseline and its immediate planning parent `779749a`. The implementation
diff is limited to the TASK-014 editor interaction surface, focused tests,
and the current-task handoff. The Source Control, launcher, package,
settings/geometry, and installed-release areas remain untouched by the
implementation commit.

`workbench.lua` scopes the new mappings to the editable regular-file buffer.
`<LeftRelease>` performs one local `+` clipboard yank only while a Visual
selection is active, then reselects it; plain clicks, keyboard-only
selections, Preview, and Diff buffers do not invoke the new side effect. The
provider-unavailable path records a bounded failure notice. `Esc` returns
directly to the selected file's read-only Preview from Normal, Insert, and
Visual editor modes. Modified buffers open a bounded confirmation; Enter/y
returns without saving or discarding, while Esc/n/q restores editor focus
without changing content or the modified flag. The hidden file buffer stays
loaded for later recovery.

The statusline guidance is conditional on the editable file buffer, and the
canonical editor help entries are pinned to real buffer-local mappings.
Cleanup removes the transient confirmation and copy notice at workbench
close. No unresolved correctness, regression, security, privacy,
data-integrity, public-contract, or scope issue remains for this local review.

## Findings

None blocking.

Non-blocking observations retained from the handoff:

- A single editor `Esc` waits for the existing `timeoutlen` because the
  global `<Esc><Esc>` quit mapping shares the prefix. This is an accepted,
  PTY-verified interaction tradeoff and does not change navigation/settings
  quit behavior.
- Auto-copy intentionally writes the configured local system clipboard. No
  clipboard contents, selection text, prompt state, or mode state is
  persisted or transferred remotely.
- The confirmation float takes focus in Normal mode, so cancelling from a
  modified Insert-mode buffer returns to the editor in Normal mode; content,
  cursor position, and modified state remain intact.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Regular file opens editable while Preview remains read-only | PASS | `workbench.lua:645-690`; existing open-file and TASK-014 focused/smoke tests pass; PTY observed the editable file buffer. |
| Completed mouse selection copies exactly and remains usable | PASS | `workbench.lua:782-798,970-976`; focused test verifies exact `+` text, Visual reselect, plain-click no-op, and explicit `+` yank; PTY verifies the SGR selection. |
| No auto-copy in read-only or keyboard-only paths | PASS | `workbench.lua:732-747,782-790`; focused test covers Preview, Diff, keyboard selection, and plain click. |
| Direct Esc Preview return from Normal/Insert/Visual | PASS | `workbench.lua:948-989`; focused mapping/handler test and native PTY checks cover all three modes and same-file Preview restoration. |
| Modified-buffer confirmation and reversible cancel | PASS | `workbench.lua:830-960`; focused test and PTY cover confirmation, Esc/n cancellation, Enter/y confirmation, intact content/modified state, and no disk write. |
| In-memory buffer recovery after confirmed return | PASS | `workbench.lua:800-827`; focused and smoke tests verify the loaded modified buffer is restored on reopen. |
| Conditional statusline/help guidance | PASS | `config/nvim/init.lua:356-374`, `keymaps.lua:41-44`; focused test verifies normal/modified/visual rendered hints, no navigation leak, and documentation-to-mapping correspondence; PTY displays both hints. |
| Existing boundaries and safe quit remain intact | PASS | Candidate implementation touches only `workbench.lua`, `init.lua`, and `keymaps.lua`; full integration, package, smoke, version, and installed-release checks pass. No Source Control/launcher/release mutation was found. |
| Focused and full local validation | PASS | Independent `./tests/run_tests.sh`: 59/59 integration, offline package suite, and 9/9 smoke; Lua/bash syntax, JSON, both version checks, PTY 17/17, and `git diff --check` pass. |

## Validation performed

- Confirmed the checkout is `task/TASK-014-auto-copy-preview-exit`, clean,
  and exactly one commit ahead of `origin/task/TASK-014-auto-copy-preview-exit`
  at `779749a`; `origin/main` is `2f72937` and is an ancestor of the
  candidate.
- Read `AGENTS.md`, `docs/repository.md`, `project-state.md`, the current
  task, backlog, prior review, product/architecture records, ADR-005, and the
  complete candidate diff.
- Inspected the actual six-file implementation handoff commit and confirmed
  the product changes do not touch Source Control, launcher, package, or
  installed-release files.
- Ran `./tests/run_tests.sh` independently: 59/59 integration tests passed,
  offline package tests passed with source/installed invariance, 9/9 smoke
  tests passed, and no fixture residue remained.
- Ran `luajit -bl` on all changed Lua/test files, `bash -n` on launcher,
  package, and test scripts, `python3 -m json.tool docs/project.json`, both
  development/installed version checks, `git diff --check`, and the local
  native PTY validation (`/tmp/pty_task014.py`): all passed.

All evidence above is local review evidence. It is not hosted, production,
recovery, or customer-acceptance evidence.

## Delivery decision

The candidate is locally `APPROVED`. LIGHTWEIGHT delivery is authorized:
push this task branch, open one traceability PR targeting `main`, and merge
promptly if it is mergeable and no explicit repository/provider rule blocks
the merge. Do not wait for optional checks or invent a second approval gate.

## Post-merge requirement

Only after the remote default branch contains the merged result, update
`project-state.md`, `docs/tasks/backlog.md`, `docs/tasks/current-task.md`,
`docs/project.json`, and this review record to the accepted merged state. Do
not issue a successor task until the merge is verified.
