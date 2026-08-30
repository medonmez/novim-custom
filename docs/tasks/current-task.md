# Current Task

Updated: 2026-08-30
Task ID: `TASK-014`
Status: `READY_FOR_REVIEW`
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

## Implementation handoff (TASK-014)

Status: `READY_FOR_REVIEW`
Implementer: `$stateless-implementer` (fresh context)
Implementation commit: HEAD (handoff commit)

### Change summary

- `workbench.lua` gained an editor-interaction section scoped to the
  editable regular-file buffer shown in the right pane:
  `editable_editor_buffer()` / `M.editing_file_buffer()` identify it (never
  the Preview/Diff/history scratch buffers); `M.copy_selection_to_clipboard()`
  copies the completed Visual mouse selection to the local system clipboard
  (`+`) exactly once at `<LeftRelease>`, keeps the selection reselected, and
  records a bounded session-only notice; `M.return_to_preview()` returns
  directly to the same file's Preview and opens the bounded
  unsaved-changes confirmation float (`M.preview_return_confirm_open()`)
  when the buffer is modified; confirming (Enter/y) hides the buffer into
  memory without saving or discarding, cancelling (Esc/n/q) keeps editing;
  `install_editor_maps()` binds `<LeftRelease>` (n/v) and `<Esc>` (n/i/v)
  buffer-locally with a default-behavior fallback when the workbench
  context is gone. The clipboard-provider check
  (`M._clipboard_provider_available`) produces a bounded failure notice
  instead of a silent failure. `M.close()`/`M.open()`/`M.get_state()` handle
  the new transient state (`copy_notice`, `preview_return`).
- `init.lua` extends `_G.get_editor_hints()` with `Mouse Copy` and
  `Esc Preview` guidance only while the workbench editable file buffer is
  focused; all other buffers keep the established hints unchanged.
- `keymaps.lua` gained the canonical `M.editor` documentation entries, and
  the workbench help popup documents the two new editor interactions.
- Tests: 7 focused `test_task014_*` integration tests and 1 smoke
  regression test cover exact clipboard auto-copy, provider-failure
  notice, no-copy in Preview/Diff/keyboard-only/plain-click paths, direct
  Esc from all three editor modes, confirm/cancel with buffer and disk
  preservation, same-file Preview restoration, reopening recovery,
  statusline guidance (including the rendered template), and
  documentation-to-mapping correspondence.

### Files changed

- `config/nvim/lua/novim/workbench.lua` (editor interaction section, state,
  close/open/get_state wiring, help popup lines)
- `config/nvim/init.lua` (editor statusline hints extension)
- `config/nvim/lua/novim/keymaps.lua` (`M.editor` docs)
- `tests/test_workbench.lua`, `tests/test_smoke.lua` (focused + smoke
  coverage; smoke test registered in `test_order`)
- `docs/tasks/current-task.md` (this handoff)

### Validation commands and results (local evidence only)

| Command | Result |
|---|---|
| `./tests/run_tests.sh` (3 consecutive final runs) | exit 0; integration 59/59, offline package tests passed, smoke 9/9, zero fixture residue, product source tree clean |
| `./bin/novim-dev --headless -c "luafile tests/test_workbench.lua"` (5 consecutive runs) | 59 total, 59 passed, 0 failed each run |
| Lua parse checks (`loadfile`) on `init.lua`, `workbench.lua`, `keymaps.lua`, `test_workbench.lua`, `test_smoke.lua` | all OK |
| `bash -n tests/run_tests.sh tests/run_smoke_tests.sh tests/run_package_tests.sh bin/novim-dev` | all OK |
| `python3 -m json.tool docs/project.json` | exit 0 (valid JSON) |
| `./bin/novim-dev --version` | `novim-dev 0.1.7-dev (custom checkout)` |
| `/Users/mert/.local/bin/novim --version` | `novim 0.1.7` (installed release untouched) |
| `git diff --check` | clean (no whitespace errors) |
| `python3 /tmp/pty_task014.py` (real PTY, SGR mouse, TERM=xterm-256color) | 17/17 checks passed |

### Acceptance-criterion evidence

- Regular file still opens as a real editable buffer; Preview stays
  read-only: `test_open_regular_file_in_editor`,
  `test_directory_selection_preserves_inspection_no_file_open`,
  `test_smoke_source_navigation_editing_and_buffer_preservation`, plus the
  PTY editor-open check.
- Mouse selection auto-copies exactly; selection and explicit copy stay
  usable: `test_task014_mouse_selection_autocopies_exact_clipboard_text`
  (clipboard equals the exact selected text; Visual mode stays active;
  explicit `"+ygv` still yanks; plain click records no notice), and the PTY
  SGR drag check (`clipboard` contained exactly the selected A-run).
- No auto-copy in read-only Preview/Diff panes or for keyboard-only
  selections: `test_task014_no_autocopy_in_readonly_panes_or_keyboard_selections`.
- Direct Esc from Insert/Normal/Visual returns to the same file's Preview:
  `test_task014_direct_esc_from_all_editor_modes_returns_to_preview`
  (i-mode binding structure asserted; handler invoked for all three modes),
  plus PTY checks for all three modes with no intermediate Normal stop.
- Modified-buffer confirmation: `test_task014_modified_buffer_esc_confirms_and_preserves_content`
  (Esc/N cancel with content and modified flag intact; Enter/y return;
  on-disk file unchanged; reopening restores the exact in-memory buffer),
  plus PTY confirmation, cancel, confirm, and recovery checks.
- In-memory buffer preserved for recovery: same tests as above
  (`nvim_buf_is_loaded` + `modified` after the confirmed return).
- Statusline guidance: `test_task014_statusline_documents_autocopy_and_esc_preview`
  (all three mode branches keep existing hints and add the new guidance;
  rendered via `nvim_eval_statusline`; no leak into navigation panes), plus
  the PTY statusline check.
- Existing boundaries intact: full 59-test integration suite, 9-test smoke
  suite (launcher isolation, installed-release independence, geometry,
  settings, Source Control), version checks, and the additive-only product
  diff inspection (no auto-save/discard, no clipboard persistence or remote
  transfer, no installed-release writes, no Source Control changes).

### Residual risks and notes

- Single-Esc return waits out `timeoutlen` (1000 ms) because the global
  `<Esc><Esc>` quit mapping shares the prefix; this matches the accepted
  Settings immediate-Esc-close behavior and was verified as working in the
  PTY run. `<Esc><Esc>` quit from the editor buffer is unchanged.
- The confirmation float always takes focus in Normal mode
  (`stopinsert`) and is non-modifiable, so its keys are decisive even when
  opened from Insert mode (found and fixed during PTY validation).
- The auto-copy writes to the local system clipboard by design; tests save
  and restore the previous clipboard content around clipboard-touching
  assertions, and the provider check is a stub seam for the failure path.
- All evidence above is local; no hosted, production, recovery, or
  customer-acceptance claim is made.
