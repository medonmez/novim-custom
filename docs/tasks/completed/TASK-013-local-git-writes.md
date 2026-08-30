# TASK-013 — File-level local Git writes

- Status: `ACCEPTED`
- Delivery policy: `LIGHTWEIGHT`
- Merge commit: `f19e529c2cc580876a058dba776c5470892f4c22` (`origin/main`)
- Pull request: `#23` (`MERGED`)
- Candidate: `4fef7ef6dc65259b12327718c7c5beaa9693a393`
- Review record: `a99e5ab4575c66cd37c9f40aa172a104f31eebe7`
- Task branch: `task/TASK-013-local-git-writes`

## Outcome

The Source Control view now supports the first explicitly authorized local
write surface: stage or unstage exactly one selected file, show staged state,
and create one local commit from the staged index through a transient
non-empty commit-message input. Successful and failed writes refresh or
reconcile the visible Source Control state, preserve selection by path where
possible, and show bounded notices.

The implementation preserves structured Git argv and the accepted boundary:
`add -- <path>`, rename-aware `reset --`, unborn-index `rm --cached --force --`,
and `commit -m <message>`. Unstaged files are never auto-staged. Remote,
checkout, history-rewriting, discard, amend, partial-line, credential, and
other unrelated Git operations remain outside the surface.

The review follow-up also restores the history-pane `N` comparison endpoint
mapping, renders write notices after the changes list becomes empty, and keeps
the selected changed path stable across commit refresh.

## Acceptance evidence

- Focused integration tests cover file-level stage/unstage, staged rendering,
  special paths, untracked/deleted/renamed entries, message validation and
  cancellation, successful local commits, failed writes, history refresh,
  clean-state notices, history-pane `N`, and selected-path preservation.
- Temporary repository assertions cover porcelain state, index entries, HEAD,
  exact worktree bytes, status invariance, history, rendered notices, and pane
  content before and after each intended mutation.
- `./tests/run_tests.sh` passed independently: 52/52 integration tests,
  offline package suite, and 8/8 smoke tests; fixture residue was zero and
  installed/source invariance passed.
- Lua/shell syntax, JSON, version, ancestry, mutation/scope, and
  `git diff --check` validations passed. The installed `novim 0.1.7` release
  remains untouched.

TASK-013 was locally reviewed `APPROVED` and delivered through PR #23. The
reviewed candidate and review record are verified in `origin/main` at merge
commit `f19e529c`. All evidence is local review/test evidence except the
remote branch containment and merge fact; no hosted, production, recovery,
or customer-acceptance claim is made.
