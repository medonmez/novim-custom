# ADR-005: Automatic Mouse Copy and Direct Preview Exit

- Status: `ACCEPTED FOR IMPLEMENTATION`
- Date: 2026-08-30
- Scope: TASK-014 editor interaction slice

## Decision

1. In the Files view, the right pane remains a read-only Preview until a
   regular file is opened for editing with the existing open-file action.
2. When a text range is selected with the mouse in that editable file buffer,
   the completed selection is copied automatically to the local system
   clipboard. The selection remains available for the existing explicit
   copy/cut workflow. Preview and read-only Diff panes do not auto-copy, and
   keyboard-only selections do not add a new auto-copy side effect.
3. `Esc` in the editable file buffer returns directly to that file's Preview
   from Insert, Normal, or Visual mode; it does not stop at an intermediate
   Normal-mode state.
4. If the editable buffer has unsaved changes, `Esc` first opens a bounded
   confirmation: returning to Preview without saving is explicit. Confirming
   returns to Preview without saving or discarding the buffer; cancelling with
   `No` or `Esc` leaves the user in the editable buffer.
5. The editor's existing bottom statusline hint area continues to show the
   Copy/Cut/Paste/Save controls and also explains mouse auto-copy and
   `Esc: Preview`. Clipboard or transition failures are visible and bounded;
   they do not silently claim success or discard user content.

## Rationale

The workbench already separates a generated read-only source Preview from a
regular editable file buffer. Making mouse selection immediately useful keeps
the terminal workflow close to a graphical editor, while a direct Escape
return avoids requiring users to learn an extra navigation command. Unsaved
content requires an explicit confirmation so the shortcut cannot silently
hide or destroy edits.

## Consequences

- The editor interaction layer must distinguish the workbench Preview buffer
  from a regular file buffer and retain the same file identity when returning
  to Preview.
- Mouse selection completion, not every drag event, is the auto-copy boundary.
- The OS clipboard is the only copy destination; no remote service, plugin,
  credential, or background synchronization is introduced.
- The existing manual Ctrl/Cmd copy, cut, paste, save, undo, navigation,
  unsaved-buffer preservation, launcher isolation, and installed-release
  boundaries remain in force.
