# TASK-014 — Automatic mouse copy and direct Preview exit

- Status: `ACCEPTED`
- Delivery policy: `LIGHTWEIGHT`
- Merge commit: `79724608028685b95d780af113f5e64caae5622a` (`origin/main`)
- Pull request: `#25` (`MERGED`)
- Candidate: `f4413b710a244cfb5f1e96cd016165c780a9520a`
- Review record: `ede54c791cecdd2a5547db4bff20414dff6ca2a4`
- Task branch: `task/TASK-014-auto-copy-preview-exit`

## Outcome

The Files view now copies a completed mouse text selection automatically to
the local system clipboard when the selection is made in an editable regular
file buffer. The selection remains active for the existing explicit copy/cut
workflow, while plain clicks, keyboard-only selections, Preview, Diff, and
other read-only or scratch buffers do not trigger the new side effect.

`Esc` returns directly from Normal, Insert, or Visual editor mode to the same
file's read-only Preview. A modified buffer opens an explicit bounded
confirmation: confirming hides the buffer without saving or discarding it,
and cancelling keeps the edited content and modified state intact. The loaded
in-memory buffer remains available for later recovery/reopening. The editor
statusline and help document the new interactions without changing existing
copy, cut, paste, save, undo, navigation, Source Control, launcher, package,
or installed-release boundaries.

## Acceptance evidence

- Focused integration tests cover exact local clipboard text, Visual
  reselection, provider failure, plain-click and keyboard-only no-op paths,
  Preview/Diff exclusion, all three editor modes, confirmation/cancellation,
  no auto-save/discard, same-file restoration, in-memory recovery, statusline
  rendering, and mapping documentation.
- The smoke regression covers editable-file opening, auto-copy, statusline
  guidance, modified-buffer confirmation/cancel, no disk write, and reopening
  recovery.
- Independent `./tests/run_tests.sh` passed: 59/59 integration tests, the
  offline package suite, and 9/9 smoke tests; fixture residue was zero and
  source/installed invariance passed.
- Lua/Bash syntax, JSON, development/installed version, PTY 17/17, and
  `git diff --check` validations passed. The installed `novim 0.1.7` release
  remains untouched.

TASK-014 was locally reviewed `APPROVED` and delivered through PR #25. The
reviewed candidate and review record are verified in `origin/main` at merge
commit `7972460`. All feature evidence is local review/test evidence except
the remote branch containment and merge fact; no hosted, production,
recovery, or customer-acceptance claim is made.
