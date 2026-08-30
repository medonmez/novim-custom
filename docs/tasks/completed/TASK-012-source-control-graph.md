# TASK-012 — Source Control graph and read-only comparison

- Status: `ACCEPTED`
- Delivery policy: `LIGHTWEIGHT`
- Merge commit: `915624c815cc10ab696530069f3ce8b1d00c228b` (`origin/main`)
- Pull request: `#21` (`MERGED`)
- Candidate: `0462823c9bea035c66bf6fbc0dc49436356deb8c`
- Review record: `f909d4d`
- Task branch: `task/TASK-012-source-control-graph`

## Outcome

The existing Git Diff view now provides the terminal Source Control surface.
Its left column is split horizontally with current changes/status above a
selectable history graph below, while the old/new comparison panes remain
available beside it. The graph uses Git's full reachable `--graph` output,
including merge nodes, graph edges, and local ref decorations.

History selection is read-only and never checks out or mutates a branch. The
user can assign two distinct history or working-tree endpoints to the old/new
panes, with a visible old-to-new direction, a bounded identical-endpoint
error, explicit reset, refresh preservation, and a fresh-entry default of
`HEAD` versus the working tree. Existing untracked, deleted, renamed, binary,
Files/Diff geometry, settings, launcher-isolation, and installed-release
boundaries remain intact.

## Acceptance evidence

- Focused integration tests verify the four-area layout, changes-above-history
  split, full five-commit merge fixture graph, decorations, history selection,
  endpoint direction, refresh behavior, fresh-entry defaults, empty/error
  states, binary placeholders, and repository byte/state invariance.
- The smoke suite verifies the accepted four-area Diff/Source Control layout
  and preserves the prior launcher, workbench, settings, geometry, editing,
  package, and installed-release regressions.
- `./tests/run_tests.sh` passed independently with 45/45 integration tests,
  the offline package suite, and 8/8 smoke tests with zero fixture residue.
- Lua/shell syntax, JSON, version, ancestry, mutation/scope, and
  `git diff --check` validations passed. Product code contains no staging,
  commit, checkout, index write, remote operation, network, or plugin path.

The candidate was locally reviewed `APPROVED` in `docs/reviews/latest-review.md`
and delivered through PR #21. The merged result is verified as an ancestor of
`origin/main` at `915624c`. All evidence is local review/test evidence only;
no hosted, production, recovery, or customer-acceptance claim is made.
