# TASK-010 — Independent Files and Git Diff pane layout persistence

- Status: `ACCEPTED`
- Delivery policy: `LIGHTWEIGHT`
- Merge commit: `a039f29f00d603712f6c537d3b816f0582d9ca2e` (`origin/main`)
- Pull request: `#17` (`MERGED`)
- Candidate: `52df2e5`
- Review record: `49dc827`
- Task branch: `task/TASK-010-pane-layout-persistence`

## Outcome

The workbench now remembers independent logical pane geometry for Files and
Git Diff. Files persists its left/right split; Diff persists its left/middle
boundaries and recomputes the right pane. Effective widths are captured after
drag release and before view or workbench teardown, then restored after layout
focus setup from the existing isolated settings file. Saved values are
validated and clamped to the current terminal and the established 15/20/20
minimums. Window and buffer identifiers are never persisted.

Malformed or impossible geometry safely falls back to built-in layout behavior.
Theme and dot-folder settings remain intact, and a settings-write failure does
not replace the live in-memory layout or make the workbench unusable.

## Acceptance evidence

- Files resize → Diff → Files and both independently resized Diff boundaries →
  Files → Diff round-trips restore the effective widths in integration tests.
- Workbench close/reopen verifies both layouts in on-disk JSON after a cold
  settings-cache reset.
- Non-numeric, NaN/inf, negative, out-of-range, and unknown layout values are
  sanitized; a blocked settings path leaves live panes valid after a drag.
- Saved geometry from a wide terminal clamps safely at a narrower terminal;
  the extreme-width fallback keeps the workbench windows valid.
- `./tests/run_tests.sh` independently passed three times: each run reported
  38/38 integration tests, offline package tests passed, and 8/8 smoke tests
  passed with zero fixture residue.
- Headless Lua and shell syntax, JSON validation, both version checks, and
  `git diff --check` passed. The installed `novim 0.1.7` remained untouched.

Evidence was local only; no hosted, production, recovery, or
customer-acceptance claim was made.
