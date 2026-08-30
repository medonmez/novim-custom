# Current Task

Updated: 2026-08-30
Task ID: `TASK-013`
Status: `CHANGES_REQUESTED`
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

Status: `CHANGES_REQUESTED` after local review on
`task/TASK-013-local-git-writes`.

Implementation candidate: `c90f863b77aebbb5f07e69e8d86e3ffff0d5e998` on
`task/TASK-013-local-git-writes` (single product handoff commit on top of
planning commit `f6b1135`, baseline `9006898` = `origin/main`). A separate
local review-record commit is now on this branch; nothing is pushed, no pull
request is open, and main is untouched.

## Change summary

The Source Control view gained its first authorized local write surface,
limited to file-level index updates and one local staged commit, per
ADR-004. `git.lua` gained an explicitly labeled write boundary:
`stage_file` (`git add -- <path>`), `unstage_file` (`git reset -- <path>`
plus the original path for rename entries, or `git rm --cached --force`
before the first commit), and `commit_staged` (`git commit -m <message>`)
— every call a structured argument vector through `vim.system`, never a
shell string; stderr/stdout failures collapse into one bounded readable
line. All read-only readers and the TASK-012 comparison behavior are
untouched (`exec` now delegates to a stderr-capturing internal helper
with an unchanged signature).

The changes pane now renders staged state per row (`[M ]` unstaged,
`[M+]` staged, `[U ]` untracked) and a `staged: N` count in the summary;
keyboard `a`/`u` stage/unstage exactly the selected entry, `c` opens a
transient commit-message float (immediate focus, Enter confirms, single
Esc cancels, blank/whitespace-only messages rejected visibly in the
float title while the input stays open), and double-click on a change
row toggles its staged state. Every attempted write refreshes the
Source Control view, preserves the user's selection by path where the
entry still exists, and renders one bounded notice line (`✓ Staged: …`,
`! Stage failed: …`, `✓ Committed: <hash> …`) that reconciles with the
actual repository result and never claims a failed write succeeded.
`a`/`u`/`c` are documented in `keymaps.lua` and the help popup in both
directions; `?` help and the note text now describe the write boundary.
The commit input buffer is transient scratch state, wiped on
confirm/cancel/workbench close, and the write notice is session-only.

## Files changed

- `config/nvim/lua/novim/git.lua` — stderr-capturing exec core plus the
  write boundary (`stage_file`, `unstage_file`, `commit_staged`) and
  bounded error summarization; read-only readers unchanged.
- `config/nvim/lua/novim/workbench.lua` — write-notice/commit-input
  state, staged-tag rendering and staged count, stage/unstage/toggle
  actions with refresh and selection preservation, commit-message float
  lifecycle with visible blank-message rejection, commit execution with
  bounded success/error notices, `get_state` exposure
  (`write_notice`, `commit_input`, `line_to_file_index`), input teardown
  on close, fresh-entry notice reset.
- `config/nvim/lua/novim/keymaps.lua` — documented `a`, `u`, `c` and the
  extended Double-Click description (all backed by real buffer-local
  mappings; the existing help/mapping consistency test pins both
  directions).
- `tests/test_workbench.lua` — fixture helpers (byte-exact git output,
  worktree byte snapshot, porcelain map) plus four focused TASK-013
  tests covering stage/unstage lifecycle and invariance, special paths,
  commit validation/cancel/success, and failed writes.
- `docs/tasks/current-task.md` — this handoff.

## Validation performed (local evidence only)

- `./tests/run_tests.sh` — integration suite 49/49 passed (45 prior +
  4 new TASK-013 tests), offline package suite passed ("Offline Package
  Tests Passed", installed/source invariance PASS), smoke suite 8/8
  passed, zero fixture residue, source tree clean.
- `luajit -bl` on changed Lua files (`git.lua`, `workbench.lua`,
  `keymaps.lua`, `test_workbench.lua`) — all parse OK.
- `bash -n` on `tests/run_tests.sh`, `tests/run_smoke_tests.sh`,
  `tests/run_package_tests.sh`, `bin/novim-dev`, `bin/novim-dev-package`
  — all OK.
- `python3 -m json.tool docs/project.json` — OK.
- `./bin/novim-dev --version` → `novim-dev 0.1.7-dev (custom checkout)`;
  `~/.local/bin/novim --version` → `novim 0.1.7` (installed release
  untouched).
- `git diff --check` — clean.
- Diff scope scan: no remote/network commands, no checkout or
  history-rewriting paths, no bulk/partial staging, no shell-string
  interpolation in product code (`vim.fn.system` appears only in
  test-fixture setup with escaped temp paths, matching the file's
  existing fixture convention), no installed-release or
  normal-Neovim-config writes, no settings/geometry changes
  (`settings.lua`, `settings_ui.lua`, `themes.lua`, launcher scripts
  untouched).
- Real-surface check (PTY): `bin/novim-dev` launched in a temporary
  repository; observed live: `[M ]`/`[U ]` row tags, `a` rendering
  `✓ Staged: tracked.txt` with `[M+]` and preserved selection, `c`
  opening the focused message float, Enter creating commit
  `e89d455 "pty live commit from TASK-013"` (verified afterwards in the
  repository: exactly one new commit, staged content committed, the
  untracked file not auto-staged, history refreshed in the graph).

## Acceptance-criterion evidence

- Selected row staged/unstaged at file granularity with clear state
  rendering: `test_stage_unstage_file_level_mutations_and_invariance`
  (raw ` M` → `M ` transition, `[M+]` tag, `staged: N` summary, ok
  notice, selection preserved) and the PTY observation above.
- Safe special-path handling, only the selected file targeted:
  `test_stage_unstage_special_paths_untracked_deleted_renamed` —
  untracked names with spaces, quotes, tabs, unicode, a leading dash
  (proving the `--` guard), and an arrow-bearing name each round-trip
  `?? → A → ??`; the deleted file stages `D ` / unstages back to ` D`
  with the index entry removed/restored; the staged rename unstages
  into ` D` old + `??` new and restaging both halves re-forms the exact
  staged rename bytes. Byte assertions: porcelain `-z` output, index
  (`ls-files -s`), `rev-parse HEAD`, and a full worktree byte snapshot
  before/after each mutation.
- Non-empty message validation and cancel/close without mutation:
  `test_commit_message_validation_cancel_and_local_commit` — blank and
  whitespace-only confirms keep the input open, set the visible
  "cannot be empty" title, and leave HEAD unchanged; Esc closes the
  input, wipes the transient buffer, and leaves HEAD and the staged
  index byte-identical.
- One local staged commit with refresh: same test — commit count +1,
  parent = previous HEAD, subject = the entered message, staged index
  emptied at the porcelain level, committed blob equals the staged
  worktree bytes, unstaged/untracked entries untouched, worktree bytes
  unchanged, success notice carries the real hash, history lists and
  renders the new commit first, comparison stays HEAD vs Worktree, and
  all four panes remain valid with the comparison usable.
- Failed writes stay consistent and bounded:
  `test_failed_writes_bounded_and_state_consistent` — failed stage
  (unknown pathspec), failed unstage (unknown path before first commit
  through `git rm --cached`), refused blank/whitespace messages at the
  module boundary, commit with an empty staged index through the input
  path ("Commit failed: nothing to commit…"), and a pre-commit-hook
  refusal — each leaves HEAD/status unchanged, renders a bounded
  `! … failed` notice, keeps the staged entry staged, and the UI
  usable; success only after the cause is removed.
- Existing TASK-012 behavior intact: all 45 prior integration tests
  pass unchanged, including history selection read-only invariance,
  two-endpoint direction/default/refresh, and the four-area layout;
  smoke byte-for-byte status/diff invariance after plain navigation.
- No remote, checkout, history-rewrite, discard, amend, partial-line,
  or unrelated mutation path introduced: full product diff inspected
  (see scope scan above); the only `git` invocations added are
  `add --`, `reset --`, `rm --cached --force --`, and `commit -m`.

## Residual risks and known gaps

- The commit message input is a single-line float; multi-line messages
  (only reachable via paste) are flattened to one space-separated line
  before validation.
- The double-click stage toggle and the `a`/`u` actions act on the
  selected/clicked change row only; there is no visual close button on
  the message float (Esc is the documented explicit close, consistent
  with the accepted Settings contract).
- A valid confirm while the user has manually left the Diff view (only
  possible by clicking outside the float) closes the input without a
  commit and without an error notice; no mutation occurs.
- Git hook output longer than one line is collapsed to the first
  non-empty line or, when git prints nothing, a bounded
  `git failed with exit code N` fallback.
- All validation above is local evidence only; no hosted, production,
  recovery, or customer-acceptance claim is made.

## Review follow-up

Local review of `c90f863b77aebbb5f07e69e8d86e3ffff0d5e998` is
`CHANGES_REQUESTED`. The same task remains active; no PR or remote delivery
was attempted.

Required corrections:

- Restore the existing `N` new-endpoint mapping in the history pane and add a
  focused mapping/behavior regression.
- Render the bounded write notice when a commit leaves the changes list empty,
  including the failed empty-index commit path, with buffer-level assertions.
- Preserve the selected change path across successful commit refresh when the
  selected entry still exists, with a regression where an earlier staged entry
  disappears.

The full local suite passed, but it did not cover these three gaps. Return the
same branch to review after the corrections and the required validation rerun.
