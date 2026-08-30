# Current Task

Updated: 2026-08-30
Task ID: `TASK-012`
Status: `IN_PROGRESS`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-012-source-control-graph`
Expected baseline: `8b76dad` (`origin/main`)
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

Status: `READY_FOR_REVIEW` (local handoff on `task/TASK-012-source-control-graph`)

Commit: `HEAD (handoff commit)` on `task/TASK-012-source-control-graph`
(single local commit on top of planning commit `4c5b922`, baseline
`8b76dad` = `origin/main`). Not pushed; no pull request opened; main
untouched.

## Change summary

The Git Diff view is now the accepted Source Control view. Its left column
is split horizontally: the current changes/status list stays on top and a
new history pane below renders the full commit ancestry reachable from the
current branch using Git's own `--graph` rendering, so merge nodes, graph
edges, and local ref/branch decorations (`HEAD -> main`, `(feature)`,
tags) appear verbatim rather than a first-parent list. History rows are
selectable for inspection via `j`/`k`/`Up`/`Down`, `Enter`/`Space`, cursor
movement, and mouse clicks, with exactly one visible `▶` marker plus a
`Selected:` identification line; selection never checks out or mutates
anything. `O`/`N` explicitly assign the old/new comparison endpoint from
the selected history row (`changes`-pane cursor resolves to the working
tree), populating the existing old/new panes in the documented old->new
direction, which is also reflected in the `Compare: [Old] ... -> [New]
...` status line and the old/new pane statuslines. `D` resets to the
default working-tree-versus-`HEAD` pair; identical endpoints are rejected
with a visible bounded error; refresh never silently moves endpoints; a
fresh workbench entry always restores the default pair. Empty repos, no
history, non-Git directories, unavailable refs, and binary/special
content render bounded readable states. `git.lua` gained read-only
`get_history`, `get_current_branch`, `resolve_revision`,
`read_revision_content`, and a generalized `get_file_versions_between`
(default pair preserves the exact prior `get_file_versions` semantics,
including rename-aware old paths and all placeholder messages). No
staging, commit, index write, checkout, or any other Git mutation was
added; TASK-013's write surface is untouched.

## Files changed

- `config/nvim/lua/novim/git.lua` — read-only history/branch/revision
  readers and the two-endpoint version reader (default pair unchanged).
- `config/nvim/lua/novim/workbench.lua` — Source Control layout
  (changes above, history below), history rendering/selection, endpoint
  assignment/reset, refresh invariance, fresh-entry default, empty/error
  states, cleanup paths, state exposure.
- `config/nvim/lua/novim/keymaps.lua` — documented `H`, `O / N`, `D`
  (backed by real buffer-local mappings on both directions per the
  existing help/mapping consistency test).
- `tests/test_workbench.lua` — merge-graph fixture plus three focused
  TASK-012 tests (layout/graph/selection/read-only invariance,
  two-endpoint direction/default/refresh, empty/error states).
- `tests/test_smoke.lua` — regression assertion updated from the old
  three-area Diff layout to the accepted four-area layout (changes,
  history, old, new) with a Source Control pane existence check.
- `docs/tasks/current-task.md` — this handoff.

## Validation performed (local evidence only)

- `./tests/run_tests.sh` — integration suite 45/45 passed (42 prior +
  3 new TASK-012 tests), offline package suite passed ("Offline Package
  Tests Passed", installed/source invariance PASS), smoke suite 8/8
  passed, zero fixture residue, source tree clean.
- Lua syntax checks via `loadfile` on all changed Lua files
  (`workbench.lua`, `git.lua`, `keymaps.lua`, `settings_ui.lua`,
  `test_workbench.lua`, `test_smoke.lua`) — all OK.
- `bash -n` on `tests/run_tests.sh`, `tests/run_smoke_tests.sh`,
  `tests/run_package_tests.sh`, `bin/novim-dev`, `bin/novim-dev-package`
  — all OK.
- `python3 -m json.tool docs/project.json` — OK.
- `./bin/novim-dev --version` → `novim-dev 0.1.7-dev (custom checkout)`;
  `novim --version` → `novim 0.1.7` (installed release untouched).
- `git diff --check` — clean.
- Diff scope scan: no Git mutation commands, no network/plugin additions,
  no installed-release or normal-Neovim-config writes, no geometry or
  settings regressions in the changed product files.
- Real-surface check: `bin/novim-dev` launched in a PTY against a merge
  fixture; the Source Control layout, merge graph, decorations, history
  selection markers, and the identical-endpoint rejection
  (`ERR=comparison endpoints must be distinct`) were observed live.

## Acceptance-criterion evidence

- Changes above history in the left Git column with usable old/new panes:
  `test_source_control_layout_graph_selection_and_readonly_invariance`
  (screenpos rows, shared column, equal widths, valid middle pane) and
  smoke `test_smoke_git_diff_rendering_and_read_only_invariance`
  (four visible areas).
- Full ancestry with merge nodes and decorations: same test asserts
  `history_count == 5`, a two-parent `M1 merge feature` node, `|\`/`|/`
  edge art, and `HEAD -> main` / `(feature)` decorations.
- Selection without mutation: keyboard callbacks, cursor movement, mouse
  row mapping, single visible marker, plus a byte-for-byte before/after
  snapshot of `rev-parse HEAD`, `ls-files -s`, `status --porcelain -z`,
  and `log --format=%H %P` asserting zero repository change.
- Two distinct endpoints populate old/new panes in the documented
  direction: `test_two_endpoint_comparison_direction_default_and_refresh`
  (C1 content in old pane, C3 content in new pane, compare line shows
  `[Old] <hash> -> [New] <hash>`, reversed content asserted absent).
- Fresh entry defaults to working tree versus `HEAD` with untracked
  handling intact (`No file in HEAD` placeholder asserted); view switches
  preserve chosen endpoints; close+reopen restores the default.
- Refresh updates status/history/comparison without moving endpoints
  (worktree file edited between refreshes; endpoint refs asserted
  unchanged; reset `D` renders refreshed worktree content).
- Bounded empty/error states: `test_source_control_empty_error_states`
  covers no-commit repos, non-Git directories, no-selection rejection
  (`! select a history row first`), identical-endpoint rejection
  (`! comparison endpoints must be distinct`), unavailable revisions via
  `read_revision_content`/`resolve_revision` (nil + error, no throw), and
  binary placeholders at commit endpoints.
- Existing contracts: all 42 prior integration tests, the full package
  suite, and 8/8 smoke tests pass unchanged except the documented
  three-area→four-area smoke layout update.

## Residual risks and notes

- The changes/history horizontal split uses a fixed session-only height
  proportion and is not persisted; logical geometry persistence remains
  Files/Diff-only by design (transient window IDs and history selection
  are never persisted), matching the task guardrails.
- The compare status line clips long endpoint/error text in very narrow
  terminals; the underlying state stays correct and the panes remain
  usable, matching the existing pane-minimum behavior.
- The PTY real-surface check picked up interactive key-routing noise
  (stray normal-mode text and a clean exit); every claimed behavior was
  still observed live, and the deterministic suites exercise the full
  flows headlessly.
- All evidence above is local evidence only; no hosted, production,
  recovery, or customer-acceptance claim is made.

## Blockers and dependencies

- Dependency: TASK-011 is accepted in merge commit `ca1edaf` via PR #19.
- ADR-004 and the accepted successor brief already resolve the Source Control
  graph, endpoint, and read-only product direction.
- TASK-013 remains a successor slice and must not be implemented here.
