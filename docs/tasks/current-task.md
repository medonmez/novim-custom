# Current Task

Updated: 2026-08-30
Task ID: `TASK-014`
Status: `PLANNED`
Delivery policy: `LIGHTWEIGHT`
Base branch: `main`
Task branch: `task/TASK-014-auto-copy-preview-exit`
Expected baseline: `2f72937134a3965a8c5294641c1589dd38a6a04c` (`origin/main`)
Pull request: `NOT_OPEN`

## Outcome

Make the Files-view preview/edit handoff feel direct for terminal-first users:
when a regular file is opened in the right editable pane, a completed mouse
selection is copied automatically to the local system clipboard, and `Esc`
returns directly to that same file's read-only Preview from every editor mode.
If the editable buffer has unsaved changes, the return requires explicit user
confirmation.

## Context

The current workbench has an application-level read-only Preview and a real
editable file buffer. Inside the editable buffer Neovim exposes Normal, Insert,
and Visual modes; these must not be confused with the application Preview
state. The current editor statusline already shows context-sensitive Copy,
Cut, Paste, Save, and Undo hints. Existing explicit Ctrl/Cmd shortcuts and
unsaved-buffer preservation are accepted behavior.

## In scope

- Keep `Space`/preview and regular-file open behavior intact in the Files view.
- Auto-copy a text range when a mouse selection in an editable regular-file
  buffer is completed, using the local system clipboard. Keep the selection
  available and preserve explicit Ctrl/Cmd copy behavior.
- Do not auto-copy selections made in read-only Preview or Diff panes, and do
  not add a new automatic side effect to keyboard-only selection.
- Make `Esc` from Insert, Normal, or Visual mode return directly to the same
  file's Preview without first stopping in Normal mode.
- When the editable buffer is modified, show a bounded confirmation before
  returning without saving. Confirming returns to Preview without saving or
  discarding the in-memory buffer; `No` or `Esc` cancels and keeps editing
  active.
- Extend the existing bottom editor statusline hint area with mouse
  auto-copy and `Esc: Preview` guidance alongside current editing hints.
- Add focused automated and real-terminal interaction coverage for selection,
  clipboard state, all editor modes, confirmation/cancel, buffer preservation,
  and statusline guidance.

## Out of scope

- Auto-copy in Preview, read-only Diff, history, settings, or other scratch
  buffers.
- Auto-copy for keyboard-only selections, automatic save, automatic discard,
  or any change to explicit copy/cut/paste/save/undo shortcuts.
- A new persistent clipboard service, remote clipboard synchronization,
  credentials, plugins, background polling, or hosted behavior.
- Closing or deleting a modified buffer, overwriting unsaved content, changing
  Source Control stage/commit behavior, or redesigning the workbench layout.

## Acceptance criteria

- [ ] In Files view, opening a regular file still produces an editable real
      file buffer while `Space`/preview remains read-only.
- [ ] Completing a mouse text selection in the editable file buffer copies
      exactly the selected text to the local system clipboard without needing
      Ctrl/Cmd-C; the selection and existing explicit copy behavior remain
      usable.
- [ ] Read-only Preview/Diff panes and keyboard-only selections do not trigger
      the new auto-copy behavior.
- [ ] `Esc` from Insert, Normal, and Visual editor modes returns directly to
      the same file's Preview; no intermediate Normal-mode stop is required.
- [ ] If the editable buffer is modified, `Esc` opens a clear confirmation.
      Confirming returns to Preview without saving or discarding the buffer;
      `No` and `Esc` leave the user editing with content and modified state
      intact.
- [ ] Returning to Preview preserves the in-memory edited buffer for later
      recovery/reopening and never silently loses user content.
- [ ] The bottom editor statusline documents mouse auto-copy and the
      `Esc: Preview` action alongside the existing Copy/Cut/Paste/Save/Undo
      hints.
- [ ] Existing Files/Diff navigation, settings/geometry persistence,
      Source Control local-write boundaries, launcher isolation, installed
      release, and safe-quit behavior remain intact.
- [ ] Focused tests, full local validation, syntax/JSON/version checks, and
      `git diff --check` pass.

## Decision guardrails

- Treat Preview as an application-level read-only scratch buffer and Normal,
  Insert, and Visual as modes inside the editable regular-file buffer.
- Trigger auto-copy once at completed mouse selection, not continuously on
  every drag event. Use the configured local system clipboard (`+`) and show
  a bounded failure notice if the local clipboard provider is unavailable.
- Bind the direct Preview transition only for editable file buffers; do not
  turn `Esc` in workbench navigation, settings, commit input, or confirmation
  UI into an accidental quit or mutation.
- The modified-buffer prompt must be explicit and reversible: confirmation
  neither saves nor discards, while cancellation leaves the original buffer,
  cursor context, content, and modified flag intact.
- Preserve the existing manual Ctrl/Cmd copy, cut, paste, save, undo, mouse,
  layout, local Git, no-default-network, and installed-release boundaries.
- Keep transient selection notices and confirmation state session-only; do
  not persist selected text, clipboard contents, prompt state, or mode state.

## Relevant areas

- `config/nvim/lua/novim/workbench.lua` — Preview/edit buffer identity,
  same-file return, modified-buffer confirmation, and workbench lifecycle.
- `config/nvim/init.lua` — existing mouse, Visual selection, clipboard,
  explicit copy/cut/paste shortcuts, and dynamic bottom editor hints.
- `config/nvim/lua/novim/keymaps.lua` — canonical user-facing shortcut
  documentation if the new Preview exit/help text is added there.
- `tests/test_workbench.lua` and `tests/test_smoke.lua` — temporary files,
  buffer/mode/clipboard assertions, unsaved-content preservation, and
  launcher regression coverage.
- `docs/adr/ADR-005-auto-copy-and-preview-exit.md` — accepted interaction
  decision and boundaries.

## Required validation

- Add focused tests for mouse selection auto-copy, exact clipboard contents,
  no-copy in read-only/keyboard-only paths, direct `Esc` from Insert/Normal/
  Visual, modified-buffer confirm/cancel, and same-file Preview restoration.
- Run `./tests/run_tests.sh`, including package and regression smoke suites.
- Run applicable Lua/shell syntax checks, `python3 -m json.tool
  docs/project.json`, development/installed version checks, and
  `git diff --check`.
- Inspect the real diff for accidental auto-save/discard, modified-buffer
  loss, clipboard persistence or remote transfer, mode/keymap regressions,
  installed-release writes, and unrelated Source Control changes.
- Validate native terminal mouse selection and statusline behavior in a local
  PTY; report this as local evidence only.

## Blockers and dependencies

- Dependency: TASK-013 is accepted in merge commit `f19e529c` via PR #23;
  reconciliation is present in `origin/main` at `2f72937` via PR #24.
- ADR-005 accepts the local clipboard, direct all-mode Preview exit, and
  explicit modified-buffer confirmation semantics for implementation.
- No product or dependency blocker remains.
