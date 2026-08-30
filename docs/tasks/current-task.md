# Current Task

Updated: 2026-08-30
Task ID: `TASK-012`
Status: `PLANNED`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-012-source-control-graph`
Expected baseline: `ca1edaf` (`origin/main` before this reconciliation)
Pull request: `NOT_OPEN`

## Outcome

Add a terminal Source Control view with current changes/status above a
selectable full current-branch history graph, while allowing the user to
choose two revision/location endpoints for a read-only side-by-side
comparison. Keep the current working tree versus `HEAD` comparison as the
default.

## Context

The existing Diff view inspects the current working tree against `HEAD`, but
it cannot show the commit ancestry that produced those changes or compare
two user-selected historical locations. The accepted ADR-004 direction adds
that inspection surface in a separate slice. TASK-011 is accepted and the
existing Files/Diff workbench, settings persistence, and read-only Git
boundary must remain intact.

## In scope

- Add a Source Control/Git view whose left area is split horizontally, with
  current changes and status above and the full reachable current-branch
  history graph below.
- Render graph structure including merge nodes and useful branch/ref
  decorations available from the local repository.
- Make history entries selectable for inspection without checking out or
  changing any branch, index, worktree file, or repository metadata.
- Let the user select two distinct revision/location endpoints from the
  working tree, `HEAD`, and graph-visible local revisions/refs supported by
  the repository. Use those endpoints for the existing old/new comparison
  panes, while retaining working tree versus `HEAD` as the default.
- Support deterministic keyboard and mouse selection, explicit refresh, and
  readable empty/error states for repositories with no changes or no history.
- Add focused integration and regression tests using local Git fixtures,
  including a merge graph and read-only invariance checks.

## Out of scope

- File staging, unstaging, commit-message input, or local commits; those are
  TASK-013 scope.
- Push, pull, fetch, merge, rebase, branch checkout, discard, amend, remote
  synchronization, credential handling, partial-line staging, or any other
  Git mutation.
- Background polling, hosted code review, network behavior, plugins, normal
  Neovim configuration writes, installed-release changes, or unrelated UI
  redesign.
- Replacing the existing three-area Diff layout, Files layout, settings
  persistence, or pane geometry contract.

## Acceptance criteria

- [ ] Source Control exposes current changes/status above a history area in
      the left Git column, while the existing old/new comparison panes remain
      available and usable.
- [ ] The history area shows the full commit ancestry reachable from the
      current branch, including merge nodes and available local ref/branch
      decorations rather than only a first-parent linear list.
- [ ] A history entry can be selected and visibly identified without checking
      out a branch or changing the current branch, index, worktree files, or
      repository metadata.
- [ ] The user can choose two distinct comparison endpoints from the
      supported working-tree/HEAD/history/ref locations; the selected
      endpoints populate the old and new comparison panes in the documented
      direction.
- [ ] A fresh Source Control/Diff entry defaults to the working tree versus
      `HEAD`, including existing untracked/deleted/special-file handling;
      choosing history does not permanently replace that default.
- [ ] Refresh updates current status, history, and the selected comparison
      without silently changing endpoint selection or checking out anything.
- [ ] Empty repositories, repositories without changes, unavailable refs,
      and unreadable/special content produce bounded readable states without
      invalid windows or uncaught errors.
- [ ] Existing Files/Diff navigation, independent pane geometry persistence,
      settings focus/close behavior, dot-folder filtering, read-only Git
      behavior, launcher isolation, and installed-release boundaries remain
      intact.
- [ ] Focused and full local validation pass, including deterministic merge
      fixtures, read-only byte/state invariance, syntax checks, JSON/version
      checks, smoke/package suites, and `git diff --check`.

## Decision guardrails

- Use local read-only Git commands for status, log/graph, ref metadata, and
  revision content. Selecting a history row must never invoke checkout or
  mutate the repository.
- Preserve the default working-tree-versus-`HEAD` comparison and existing
  three-pane old/middle/new semantics. Do not add a unified-diff fallback.
- Show the full reachable graph, including merge nodes; do not silently
  reduce it to first-parent history for convenience.
- Keep endpoint selection explicit and deterministic. Reject identical or
  unsupported endpoints with a visible bounded error rather than guessing.
- Keep TASK-013's write surface out of this task. No staging, commit, or index
  writes may be introduced here.
- Preserve pane minimums and logical Files/Diff geometry persistence. Do not
  persist transient window IDs or history selection unless explicitly
  required by this task's accepted behavior.
- All evidence is local evidence only; do not claim hosted, production,
  recovery, or customer acceptance.

## Relevant areas

- `config/nvim/lua/novim/workbench.lua` — view lifecycle, pane layout,
  navigation, and Source Control integration.
- `config/nvim/lua/novim/git.lua` — local status, history, refs, and
  revision-content read boundaries.
- `config/nvim/lua/novim/keymaps.lua` — canonical Source Control help.
- `config/nvim/lua/novim/settings_ui.lua` — preserved Settings behavior.
- `tests/test_workbench.lua` and `tests/test_smoke.lua` — deterministic merge
  fixtures, endpoint selection, refresh, and regression coverage.

## Required validation

- Add focused tests for the horizontal Source Control layout, full graph
  including merge nodes, history selection without checkout, two-endpoint
  comparison, default working-tree/`HEAD` behavior, refresh, empty/error
  states, and repository byte/state invariance.
- Run `./tests/run_tests.sh`, including package and regression smoke suites.
- Run applicable Lua/shell syntax checks, `python3 -m json.tool
  docs/project.json`, both development/installed version checks, and
  `git diff --check`.
- Inspect the real diff for Git mutation, network/plugin additions,
  installed-release writes, geometry/settings regressions, and scope creep.

## Blockers and dependencies

- Dependency: TASK-011 is accepted in merge commit `ca1edaf` via PR #19.
- ADR-004 and the accepted successor brief already resolve the Source Control
  graph, endpoint, and read-only product direction.
- TASK-013 remains a successor slice and must not be implemented here.

## Implementation handoff

Status: `PLANNED` (awaiting implementation on the recorded isolated branch)

Implement TASK-012 only on `task/TASK-012-source-control-graph` after reading
this task, the repository instructions, and the latest review. Return a local
`READY_FOR_REVIEW` handoff; do not push, open a PR, merge, or mark the task
accepted as the implementer.
