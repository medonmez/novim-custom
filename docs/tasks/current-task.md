# Current Task

Updated: 2026-08-30
Task ID: `TASK-014`
Status: `ACCEPTED`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-014-auto-copy-preview-exit` (merged)
Candidate: `f4413b710a244cfb5f1e96cd016165c780a9520a`
Pull request: `#25` (`MERGED`)
Merge commit: `79724608028685b95d780af113f5e64caae5622a` (`origin/main`)

## Closure

TASK-014 was locally reviewed `APPROVED` after inspecting the real diff and
running the focused/full local validation. The reviewed Files-view editor
surface now copies completed mouse selections in editable regular-file
buffers to the local system clipboard, returns directly from Normal, Insert,
and Visual modes to the same file's read-only Preview with `Esc`, and asks for
explicit confirmation before hiding modified buffers.

The merged behavior preserves selection usability, explicit copy/cut/paste/
save/undo shortcuts, read-only Preview/Diff boundaries, in-memory recovery,
statusline guidance, Source Control behavior, launcher isolation, and the
installed release. Confirmation never saves or discards user content;
Preview/Diff read-only panes, keyboard-only auto-copy, and remote clipboard
synchronization remain excluded. The reviewed candidate and review record are
contained in `origin/main` at merge commit `7972460`; full evidence is in
`docs/reviews/latest-review.md` and the local validation remains local-only.

## Next task

Not issued. The planned backlog through TASK-014 is exhausted. New work
requires product direction from the user before a successor task is planned;
until then this file intentionally holds no actionable implementation task.
