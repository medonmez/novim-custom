# TASK-011 — Focus-driven Settings and mouse close affordance

- Status: `ACCEPTED`
- Delivery policy: `LIGHTWEIGHT`
- Merge commit: `ca1edaffd30870a57a51b840edc341c9ff0873c1` (`origin/main`)
- Pull request: `#19` (`MERGED`)
- Candidate: `67bc379173bca3f6edd391f31edc78585210a3c4`
- Review record: `41fb79f`
- Task branch: `task/TASK-011-settings-focus-close`

## Outcome

Settings now behaves like a focused option menu. An in-memory selected-control
model marks exactly one of the dot-folder and theme controls. Up/Down and j/k
move only between those controls, Left/Right and h/l/[/] change the theme only
when Theme is selected, and Space/Enter activates the selected control. The
existing one-key Esc close remains immediate. A right-aligned `Close [x]`
affordance closes through the same safe cleanup and focus-restoration path.

The theme and dot-folder values retain their existing persistence and
write-failure behavior. Focus is session-only and is not persisted. Settings
help now documents the actual focus-model mappings in both directions.

## Acceptance evidence

- Focused integration tests verify one selected marker, control-only wrapping,
  unchanged buffer cursor position, theme-only arrows, Space activation, and
  failed-write error/effective-value/focus coherence.
- Settings close tests verify one-key Esc, q, and the mouse close hit-test
  restore workbench focus; the close-affordance test verifies unchanged
  settings and ignored off-control clicks.
- `./tests/run_tests.sh` passed with 42/42 integration tests, the offline
  package suite, and 8/8 smoke tests with zero fixture residue.
- Lua/shell syntax, `python3 -m json.tool docs/project.json`, development,
  checkout-upstream and installed-release version checks, and
  `git diff --check` passed.
- `workbench.lua`, `settings.lua`, and `themes.lua` were unchanged; no Git
  mutation, network, plugin, normal-config, or installed-release behavior was
  added.

The close hit-test and wired `<LeftMouse>` mapping were tested with explicit
coordinates; a real PTY click directly on the new label was not exercised.
This is local evidence only and does not claim hosted, production, recovery,
or customer acceptance.
