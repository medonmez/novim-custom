# Current Task

Updated: 2026-08-30
Task ID: `TASK-013`
Status: `PLANNED`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-013-local-git-writes`
Expected baseline: `9006898` (`origin/main`)
Pull request: `NOT_OPEN`

## Outcome

Add the first explicitly write-capable Source Control slice: file-level local
stage/unstage actions and a user-entered non-empty commit message that creates
a local staged commit, then refreshes the Source Control view. Keep all remote,
history-rewriting, checkout, discard, and partial-line operations outside the
surface.

## Context

TASK-012 is accepted in merge commit `915624c` via PR #21. The current Source
Control view exposes current changes/status, full current-branch history, and
read-only two-endpoint comparison. The accepted ADR-004 direction now permits
the smallest useful local write surface: file-level staging, unstaging, and a
local staged commit with an explicitly entered message.

## In scope

- Add file-level stage and unstage actions for the selected current-change
  entry, available through deterministic keyboard and mouse affordances.
- Show staged/unstaged state in the current changes/status area and refresh it
  after each successful or failed action without losing the user's context.
- Provide a commit-message input with bounded focus, explicit cancel/close,
  and non-empty-message validation.
- Create a local commit from the currently staged index through Git, refresh
  status/history/comparison afterward, and show bounded errors for failed
  writes or commits.
- Preserve safe path handling for spaces, special characters, renames, and
  untracked files at file-level action boundaries.
- Add deterministic fixture tests for successful writes, failed writes,
  message validation/cancellation, refresh behavior, and post-action
  repository state.

## Out of scope

- Push, pull, fetch, remote synchronization, credential handling, hosted code
  review, or network behavior.
- Merge, rebase, branch creation/deletion, branch checkout, reset, discard,
  amend, cherry-pick, revert, or any other history-rewriting operation.
- Partial-line or hunk staging, bulk implicit staging, or staging unrelated
  files as a side effect of a selected-file action.
- Editing source files through the Source Control surface, normal Neovim
  configuration writes, installed-release changes, plugins, background
  polling, or unrelated layout/settings redesign.

## Acceptance criteria

- [ ] The selected current-change row can be staged and unstaged at file
      granularity, with the resulting index/worktree status rendered clearly.
- [ ] Stage/unstage actions handle tracked, untracked, deleted, renamed, and
      special-path entries safely without shell interpolation or path loss;
      only the selected file is targeted.
- [ ] A commit-message surface accepts a non-empty message, rejects blank or
      whitespace-only input visibly, and supports cancel/close without a Git
      mutation.
- [ ] A valid commit creates one local staged commit, refreshes status/history
      and the selected comparison, and preserves the existing read-only
      comparison direction and pane usability.
- [ ] Failed stage, unstage, or commit commands leave the effective UI state
      and repository state consistent, with bounded readable errors and no
      uncaught exception.
- [ ] Existing TASK-012 history selection, two-endpoint comparison, default
      working-tree/`HEAD` behavior, full graph, refresh, Files navigation,
      settings focus/close, geometry persistence, launcher isolation, and
      installed-release boundaries remain intact.
- [ ] No remote, checkout, history-rewrite, discard, amend, partial-line, or
      unrelated Git mutation path is introduced.
- [ ] Focused and full local validation pass, including temporary Git fixtures
      with byte/state assertions before and after each intended mutation,
      syntax checks, JSON/version checks, smoke/package suites, and
      `git diff --check`.

## Decision guardrails

- Use local Git commands only for file-level index updates and local staged
  commits. Keep argument vectors structured; do not build shell command
  strings from repository paths or user-entered commit messages.
- Stage and unstage exactly the selected file, using the existing status model
  and preserving rename-aware and special-path semantics.
- Require an explicit non-empty commit message before invoking commit. Do not
  auto-stage unstaged files or silently include files outside the staged index.
- After any attempted write, reconcile visible status/history with the actual
  repository result. Failed writes must not claim success or fabricate a new
  history entry.
- Keep TASK-012 comparison selection read-only and preserve the default
  working-tree-versus-`HEAD` pair for a fresh entry.
- Do not persist transient input buffers, message text, focus, or selection;
  keep logical Files/Diff geometry and settings persistence unchanged.
- All validation is local evidence only; do not claim hosted, production,
  recovery, or customer acceptance.

## Relevant areas

- `config/nvim/lua/novim/git.lua` — structured file-level stage/unstage and
  local commit boundary, with existing read-only readers preserved.
- `config/nvim/lua/novim/workbench.lua` — Source Control actions, status
  rendering, commit-message lifecycle, refresh, focus, and error handling.
- `config/nvim/lua/novim/keymaps.lua` — canonical Source Control help for the
  new mappings and commit-message controls.
- `config/nvim/lua/novim/settings_ui.lua` — preserve Settings focus/close
  behavior; change only if a shared interaction contract requires it.
- `tests/test_workbench.lua` and `tests/test_smoke.lua` — temporary Git
  fixtures, mutation assertions, UI action mappings, and regressions.

## Required validation

- Add focused tests for selected-file stage/unstage, special paths, untracked
  and deleted files, non-empty message validation, cancel, successful local
  commit, failed writes, refresh/history updates, and repository invariance
  outside the intended mutation.
- Run `./tests/run_tests.sh`, including package and regression smoke suites.
- Run applicable Lua/shell syntax checks, `python3 -m json.tool
  docs/project.json`, development/installed version checks, and
  `git diff --check`.
- Inspect the real diff for remote/network commands, checkout or history
  rewriting, accidental bulk/partial staging, unsafe shell interpolation,
  installed-release writes, settings/geometry regressions, and scope creep.

## Blockers and dependencies

- Dependency: TASK-012 is accepted in merge commit `915624c` via PR #21.
- ADR-004 and the accepted successor brief resolve the local file-level
  stage/unstage/commit direction and exclude remote/history-rewriting actions.
- No active product or dependency blocker remains.

## Implementation handoff

Implement TASK-013 only on `task/TASK-013-local-git-writes`, created from
verified `origin/main` baseline `9006898`. Return a local
`READY_FOR_REVIEW` handoff with the implementation commit and validation
evidence. Do not push, open a PR, merge, reconcile acceptance records, or mark
the task accepted as the implementer.
