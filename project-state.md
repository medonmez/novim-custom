# Project State

Updated: 2026-09-03
Repository: `novim-custom` (public target: `oh-my-code`)
Lifecycle: `ACTIVE_DEVELOPMENT`
Delivery policy: `LIGHTWEIGHT`
Current task: `TASK-020` (`READY_FOR_REVIEW`; Files create/rename)
Base branch: `main`
Task branch: `task/TASK-020-files-create-rename`
Expected baseline: `6b8ca01312fcb1052b2fa8021606354636037b98`
Pull request: none
Last accepted task: `TASK-019`
Last accepted commit: `8f50c01c0f1480e04b4b3b8031d23c461a7d0fc1` (`origin/main` merge of PR #36)
Last merged pull request: `https://github.com/medonmez/oh-my-code/pull/36`

## Current truth

- The repository is a local clone of `link2004/novim` at upstream tag `v0.1.7`
  and commit `8e36d447ee9c73d29b75f3dfc50db9452a2addf1`.
- The clone lives at `/Users/mert/novim-custom`; `origin` points to the public
  `medonmez/oh-my-code` repository and `upstream` points to the official
  `link2004/novim` repository.
- The installed `novim` release remains independent and is not being edited.
- The accepted public product direction is `oh-my-code`, launched with `ohc`;
  `novim-dev` remains a one-release compatibility alias.
- The GitHub repository is public as `medonmez/oh-my-code`; the former
  `medonmez/novim-custom` name resolves to it. Public release `v1.0.0` is
  published with the archive, checksum, and version-pinned installer path.
- Public installation is planned for `~/.local/share/oh-my-code` with
  `~/.local/bin/ohc`; these paths do not replace the installed `novim` paths.
- The one-second interactive-TTY splash is implemented and accepted in
  TASK-016. Public packaging/installer is accepted in TASK-017, the README/demo
  assets are accepted in TASK-018, and the hosted release is accepted in
  TASK-019.
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
- `TASK-013` was locally reviewed `APPROVED` at candidate `4fef7ef` with
  review record `a99e5ab`, delivered through GitHub PR #23, and verified in
  merge commit `f19e529c` on `origin/main`. The Source Control view now
  supports file-level local stage/unstage and local staged commits with a
  transient user-entered message, bounded notices, and the three review
  corrections for history-pane `N`, clean-state notices, and selected-path
  preservation.
- `TASK-014` was locally reviewed `APPROVED` at candidate `f4413b7` with
  review record `ede54c7`, delivered through GitHub PR #25, and verified in
  merge commit `7972460` on `origin/main`. Editable-file mouse selections
  auto-copy to the local system clipboard, all editor modes return directly to
  the same file's Preview with `Esc`, modified buffers require explicit
  confirmation with in-memory recovery, and the statusline documents the new
  interactions. Preview/Diff read-only panes, keyboard-only auto-copy,
  auto-save, and remote clipboard synchronization remain excluded.
- `TASK-015` was locally reviewed `APPROVED` at candidate `75dc882` with
  review record `7080358`, delivered through GitHub PR #27, and verified in
  merge commit `8457dbf` on `origin/main`. The public `ohc` launcher now
  identifies oh-my-code, `novim-dev` is an explicitly labeled one-release
  compatibility alias, and both commands retain the isolated runtime boundary.
  Installed `novim`, `bin/novim`, and the normal Neovim configuration remain
  independent.
- `TASK-016` was locally reviewed `APPROVED` at candidate `6072f25` with
  review record `32568a4`, delivered through GitHub PR #29, and verified in
  merge commit `9904324` on `origin/main`. Both checkout launchers now render
  the bounded interactive-TTY splash and bypass it for launcher controls,
  diagnostics, and non-interactive/test paths. The PTY matrix and full local
  suites passed; installed `novim`, `bin/novim`, and the normal Neovim
  configuration remain independent.
- `TASK-018` was locally reviewed `APPROVED` at candidate `3c763ba` with
  review record `ce9b820`, delivered through GitHub PR #34, and verified in
  merge commit `ed5a359` on `origin/main`. The README is now the public
  oh-my-code guide, `docs/demo.gif` is a real public-safe `ohc` capture, and
  the architecture/link/invariance checks passed. Hosted rename and release
  actions remain outside this accepted local delivery.
- `TASK-019` was locally reviewed `APPROVED`, delivered through PR #36, and
  verified in merge commit `8f50c01` on `origin/main`. The repository was
  renamed to `medonmez/oh-my-code`; release workflow run `33686893104` passed
  and published `v1.0.0` with provider-verified archive/checksum assets. A
  fresh public installer run and real-release collision negative check passed;
  installed `novim`, normal Neovim config, upstream remote, and unrelated
  paths remained unchanged.
- `TASK-020` is planned on `task/TASK-020-files-create-rename` from verified
  `origin/main` `6b8ca013`. It adds bounded Files-pane creation and complete
  name renaming for regular files and directories through a discoverable
  context menu plus keyboard shortcuts. `TASK-021` is proposed follow-up
  scope for copy, paste, and move.
- `TASK-011` covers focus-driven Settings navigation and a mouse close
  affordance. `TASK-012` covers the accepted Source Control layout and
  selectable history. `TASK-013` covers the accepted local stage/commit
  surface. The Git direction is now accepted in ADR-004: full current-branch
  graph, two user-selected comparison endpoints, and file-level local
  stage/unstage/commit only. These slices are now implemented and accepted in
  the mainline history.

## Active blockers

- No active product blocker remains. `TASK-020` is the only actionable task;
  `TASK-021` remains proposed until the first Files mutation slice is
  accepted.
- No production, recovery, or customer-acceptance claim is made; the hosted
  evidence is limited to the GitHub repository/release and installer
  observations recorded for TASK-019.

## Next orchestration action

Pass `TASK-020` to `$stateless-implementer` on its isolated branch. The
implementer must stop at a local `READY_FOR_REVIEW` handoff; no
copy/paste/move, delete, Git remote operation, or public-release action is
authorized by this task.
