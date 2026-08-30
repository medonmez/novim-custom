# TASK-009 — Three-area side-by-side read-only diff with refresh on entry

- Status: `ACCEPTED`
- Delivery policy: `LIGHTWEIGHT`
- Merge commit: `b5cae85` (`origin/main`)
- Pull request: `#15` (`MERGED`)
- Candidate: `06552998199263bbd6dfaa9f5064af569566267d`
- Task branch: `task/TASK-009-three-area-diff`

## Outcome

The Git Diff view now renders three visible areas — left changed-file list,
middle old/HEAD pane, right new/working-tree pane — with no unified-diff
fallback. Entering Diff refreshes Git status and selected content against the
current working tree and `HEAD`; selecting a changed file updates both
content panes while the list stays navigable. Binary, deleted, renamed,
untracked, empty, and unreadable files render readable placeholders or the
correct pane content through the new read-only `git.get_file_versions`. Both
visible boundaries drag in both directions with independently clamped minimum
widths (left 15, middle 20, right 20 columns) and no `E21`/invalid-window
failure. Files view keeps its accepted two-pane layout and drag.

## Acceptance evidence

- Three distinct valid Diff windows/buffers asserted in integration and smoke
  tests; the new pane never renders unified `diff --git` text.
- Re-entering Diff after a new working-tree file appears refreshes the file
  list and renders the new content.
- Modified, deleted, renamed, untracked, and binary fixtures render expected
  content or placeholders in the correct panes.
- Both boundaries resize both ways, clamp left/middle/right minimums, keep
  all windows valid, and preserve selection.
- `./tests/run_tests.sh` independently: 34/34 integration tests, offline
  package suite, 7/7 regression smoke tests; `bash -n`, headless Lua load,
  JSON validation, both version checks, and `git diff --check` passed.
- TASK-007 lazy browsing, TASK-008 themes/settings/Esc-close/drag, source
  preview/editing, and read-only Git regression suites remained green.

Evidence was local only; no hosted, production, recovery, or
customer-acceptance claim was made.
