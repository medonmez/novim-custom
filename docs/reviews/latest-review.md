# Latest Review

Updated: 2026-08-30
Task ID: `TASK-010`
Local verdict: `APPROVED`
Delivery policy: `LIGHTWEIGHT`
Baseline: `94a8d0b` (`origin/main`)
Candidate: `52df2e5`
Task branch: `task/TASK-010-pane-layout-persistence`
Pull request: `https://github.com/medonmez/novim-custom/pull/17`
Remote checks: `OPTIONAL / NOT_RUN`
Merge status: `MERGED`
Target branch contains change: `YES` (`origin/main`)
Merge commit: `a039f29f00d603712f6c537d3b816f0582d9ca2e`

## Review result

The implementation commit was inspected against its immediate plan parent
`d448f36` and the branch was checked against the recorded `origin/main`
baseline. The candidate is limited to the existing isolated settings boundary,
the workbench layout lifecycle, and deterministic integration/smoke coverage.

`settings.lua` stores only logical Files `left` and Diff `left`/`middle`
widths, validates finite numeric values, ignores unknown layout fields, and
keeps theme and dot-folder settings in the save path. `M.set_layout` replaces
only the named view and leaves the other view untouched; the cache is updated
only after a successful write. `workbench.lua` captures effective widths after
drag release and before view/close teardown, restores the active view after
focus/layout setup, and clamps to the current terminal and the established
15/20/20 minimums. No window or buffer identifiers are persisted.

The focused tests cover Files/Diff independence in both directions, both Diff
boundaries, cold-cache/on-disk reopen, malformed and impossible values,
theme/dot-folder preservation, write-failure resilience, and narrow-terminal
clamping. Existing workbench, launcher-isolation, source-navigation, lazy
browsing, read-only Git, package, and installed-release boundaries remain
covered by the full suite.

No correctness, regression, security, privacy, data-integrity, public-contract,
or scope issue remains for this local review.

## Findings

None blocking. The following handoff observations remain non-blocking and are
consistent with the accepted task boundary:

- Geometry is global to the isolated checkout state rather than keyed by
  project; a narrower later terminal clamps it safely.
- A Diff left pane below Neovim's `winwidth` can remain at the user's saved
  effective width because restore intentionally runs after focus settles.
- The earlier TASK-009 observation about a manually closed middle pane leaving
  stale state remains deferred; capture and restore paths guard invalid panes.

## Acceptance evidence

| Criterion | Result | Evidence |
|---|---|---|
| Files divider survives a Files → Diff → Files round-trip | PASS | `workbench.lua:716-739` captures before switching and restores after layout setup; `tests/test_workbench.lua:1980-2090` asserts the saved Files width after the round-trip |
| Both Diff boundaries survive Diff → Files → Diff | PASS | `workbench.lua:142-160,954-987,1021-1068`; `tests/test_workbench.lua:2050-2087` asserts both logical widths |
| Workbench reopen restores persisted geometry | PASS | `workbench.lua:1242-1360,1664-1670`; `tests/test_workbench.lua:2101-2167` verifies on-disk JSON and a cold settings cache |
| Changed terminal width and impossible values remain safe | PASS | `workbench.lua:77-138` clamps current-terminal geometry and falls back when minima cannot fit; `tests/test_workbench.lua:2169-2355` covers malformed values, 120 → 70, and extreme width 50 |
| Theme/dot-folder preservation and write-failure resilience | PASS | `settings.lua:122-168,199-229`; `tests/test_workbench.lua:2184-2254` verifies preserved settings and live panes after a failed write |
| Existing workbench, read-only, isolation, and installed-release contracts | PASS | Full 38-test integration suite, offline package suite, and 8-test smoke suite passed; scope scan found no mutation/network/plugin/installed-release path |
| Focused and required validation | PASS | Three consecutive `./tests/run_tests.sh` runs passed; shell/Lua syntax, `python3 -m json.tool docs/project.json`, version checks, and `git diff --check` passed |

## Validation performed

- Inspected `AGENTS.md`, `docs/repository.md`, `project-state.md`, the
  current task, backlog, latest prior review, architecture/product records,
  and the complete candidate diff.
- Confirmed the checked-out branch is
  `task/TASK-010-pane-layout-persistence`, clean, with `52df2e5` on top of
  the recorded `origin/main` baseline and the prior orchestration commits.
- Ran `./tests/run_tests.sh` independently three times: each run reported
  38/38 integration tests, offline package tests passed, and 8/8 smoke tests
  passed with zero fixture residue.
- Ran `bash -n` on the launcher, package helper, and all test runners;
  headless Lua load checks on the changed Lua/test files;
  `python3 -m json.tool docs/project.json`; both development and installed
  version checks; and `git diff --check`.
- Inspected the changed-file scope for Git mutation commands, network/plugin
  additions, credentials, normal configuration writes, and installed-release
  writes; none were introduced. The installed `novim 0.1.7` remains separate.

Evidence is local review evidence only; no hosted, production, recovery, or
customer-acceptance claim is made.

## Delivery decision

`ACCEPTED` after lightweight PR #17 merge. The reviewed implementation and
review record are contained in `origin/main` at merge commit `a039f29`; remote
checks were not required or reported. Review and validation evidence are
local, with remote branch containment verified after merge. No hosted,
production, recovery, or customer-acceptance claim is made.

## Next action

TASK-010 is complete. Durable records are reconciled and TASK-011 is now the
single actionable planned successor on `task/TASK-011-settings-focus-close`
from `origin/main` `a039f29`.
