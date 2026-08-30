# Project State

Updated: 2026-08-30
Repository: `novim-custom`
Lifecycle: `ACTIVE_DEVELOPMENT`
Delivery policy: `LIGHTWEIGHT`
Current task: `TASK-013` (`PLANNED`)
Base branch: `main`
Task branch: `task/TASK-013-local-git-writes`
Pull request: `NOT_OPEN`
Last accepted task: `TASK-012`
Last accepted commit: `915624c` (`origin/main` merge of PR #21)
Last merged pull request: `https://github.com/medonmez/novim-custom/pull/21`

## Current truth

- The repository is a local clone of `link2004/novim` at upstream tag `v0.1.7`
  and commit `8e36d447ee9c73d29b75f3dfc50db9452a2addf1`.
- The clone lives at `/Users/mert/novim-custom`; `origin` points to the
  personal fork `medonmez/novim-custom` and `upstream` points to the official
  `link2004/novim` repository.
- The installed `novim` release remains independent and is not being edited.
- Workflow manifests and durable project records have been bootstrapped under
  `docs/` without removing or duplicating the upstream public documentation.
- `TASK-001` was locally reviewed (`APPROVED` at candidate `b8512b6`) and
  delivered through GitHub PR #1. Merge commit
  `12327b78049e1348df858b589baf669ba451c090` is present on `origin/main`; all
  7 acceptance criteria passed local validation.
- Product direction is accepted for implementation: Files view uses a lazy
  root-only project tree and source preview; Diff view will use a left
  changed-file list plus middle old-file and right new-file panes. The six
  built-in themes, session-only folder expansion, diff-entry refresh, and
  immediate settings close decisions are recorded in ADR-003.
- `TASK-003` was locally reviewed `APPROVED`, delivered through GitHub PR #3,
  and verified in merge commit `6a9be23522c43110dd4c4053f67ab22c8586d4b9` on
  `origin/main`. The project browser hides dot-prefixed entries by default,
  persists the visibility setting under isolated state, filters directory
  previews consistently, and surfaces settings-write failures.
- `TASK-004` was locally reviewed `APPROVED`, delivered through GitHub PR #4,
  and verified in merge commit `cdb9140947f0fe4beb9a4748e599e8f769fb6aec` on
  `origin/main`. The workbench opens regular project files in the right editor
  pane, preserves read-only directory and Git inspection, supports bidirectional
  Files/Git Diff navigation, and retains unsaved source buffers during preview
  navigation.
- `TASK-005` was locally reviewed `APPROVED` at candidate
  `965b25cab4195f8b12fb7880971741c48e708809`, delivered through GitHub PR #6,
  and verified in merge commit `cd938e2ce0ef9e792b2979cd325e614a65d42590` on
  `origin/main`. The local smoke layer covers normal launcher startup, exact
  isolated paths, external and symlink invocation, workbench/settings/Git
  invariants, concurrent runs, and cross-platform fixture cleanup.
- Reconciliation PR #7 was merged at `bcdd81ce9e9d0a3badc21d220f98d31600167059`
  on `origin/main`; TASK-006 uses that verified branch tip as its baseline.
- `TASK-002` candidate `54ad217047eb07b75b08697129cde3c905418443`
  received local verdict `APPROVED`, was delivered through GitHub PR #2, and
  is present in merge commit `794a7c6fe09abb335fb7c14273614a796b365631` on
  `origin/main`. Native terminal mouse interaction was verified in an
  independent PTY, including bidirectional divider drag, minimum width
  behavior, and left-pane click selection without `E21`.
- `TASK-006` was locally reviewed `APPROVED` at candidate
  `08ca56ca7efcecb759412d4b6cafa60f33921d6a`, delivered through GitHub PR #8,
  and verified in merge commit `86ee75844308afbaf7e055bd86b6e5ca8b38a903` on
  `origin/main`. The derivative now has an offline deterministic
  package/install helper, local distribution and upstream sync runbooks, and
  offline package/fixture validation integrated into the test runner.
- `TASK-007` was locally reviewed `APPROVED` at candidate
  `48931884e679c55c2e5eb536706efc0fcd14d249`, delivered through GitHub PR #10,
  and verified in merge commit `d8f567a2b1b20d6ab9f9afba7e5ab9d2442ce1c9` on
  `origin/main`. The project browser now starts with a root-only lazy listing,
  expands folders one level at a time for the session, filters dotfiles at
  every level, and refuses true symlink ancestor cycles.
- `TASK-008` was locally reviewed `APPROVED` at candidate
  `49b453e40c8d7ab5f1f39b6353b581da9d2fc2da`, delivered through GitHub PR #13,
  and verified in merge commit `6621cd84362bd1975106b8b1ba2e012d0682823a` on
  `origin/main`. The derivative now has six application-owned built-in themes
  with persisted, safely-validated selection; settings key help pinned to real
  mappings in both directions; immediate one-key `Esc` settings close; and a
  bidirectional, minimum-width-clamped divider drag that never raises `E21`.
- `TASK-009` was locally reviewed `APPROVED` at candidate
  `06552998199263bbd6dfaa9f5064af569566267d`, delivered through GitHub
  PR #15, and verified in merge commit `b5cae85` on `origin/main`. The Diff
  view now renders a three-area side-by-side read-only diff — changed-file
  list, old/HEAD pane, new/working-tree pane — with refresh on entry,
  readable special-file handling, and two independently clamped boundary
  drags.
- `TASK-010` was locally reviewed `APPROVED` at implementation candidate
  `52df2e5` with review record `49dc827`, delivered through GitHub PR #17,
  and verified in merge commit `a039f29` on `origin/main`. The workbench now
  persists independent logical Files/Diff pane geometry across view switches
  and local launches, clamps it to the current terminal, and preserves the
  existing theme/dot-folder settings and write-failure boundary.
- `TASK-011` was locally reviewed `APPROVED` at candidate `67bc379` with
  review record `41fb79f`, delivered through GitHub PR #19, and verified in
  merge commit `ca1edaf` on `origin/main`. Settings now has session-only
  control focus, control-only navigation, context-aware theme activation,
  immediate Esc close, and a top-right mouse close affordance. Existing
  settings persistence, pane geometry, and local-only boundaries remain
  intact.
- `TASK-012` was locally reviewed `APPROVED` at candidate `0462823` with
  review record `f909d4d`, delivered through GitHub PR #21, and verified in
  merge commit `915624c` on `origin/main`. The Diff view now provides the
  accepted Source Control layout, full current-branch graph, and explicit
  two-endpoint read-only comparison.
- `TASK-011` covers focus-driven Settings navigation and a mouse close
  affordance. `TASK-012` covers the accepted Source Control layout and
  selectable history. `TASK-013` covers the accepted local stage/commit
  surface. The Git direction is now accepted in ADR-004: full current-branch
  graph, two user-selected comparison endpoints, and file-level local
  stage/unstage/commit only. These are still successor slices, not current
  implementation work.

## Active blockers

- TASK-013 has no active product or dependency blocker.
- No hosted, production, recovery, or customer-acceptance claim is made.

## Next orchestration action

Implement `TASK-013` on its isolated task branch, then return a local handoff
for review. Keep the write surface file-level and local; preserve the full
Source Control graph, two-endpoint comparison, and dependency boundaries.
Local distribution and upstream sync remain documented in
`docs/LOCAL_DISTRIBUTION.md` and `docs/UPSTREAM_SYNC.md`.
