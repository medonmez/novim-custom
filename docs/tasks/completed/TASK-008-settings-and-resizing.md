# TASK-008 — Built-in themes, settings key help, immediate close, pane resizing

- Status: `ACCEPTED`
- Delivery policy: `LIGHTWEIGHT`
- Merge commit: `6621cd84362bd1975106b8b1ba2e012d0682823a`
- Pull request: `#13` (`MERGED`)
- Candidate: `49b453e40c8d7ab5f1f39b6353b581da9d2fc2da`

## Outcome

Added six application-owned built-in themes (Tokyo Night default,
Nord, Gruvbox Dark, Catppuccin Mocha, One Dark, Solarized Light) with a
persistent, safely-validated selection; settings key help rendered from
canonical keymap documentation that tests pin to real mappings in both
directions; immediate one-key `Esc` settings close with synchronous focus
restoration; and an application-owned, bidirectional, minimum-width-clamped
divider drag that never raises `E21`.

## Acceptance evidence

- Theme catalog/order/default, persistence, malformed/non-string/unknown
  fallback without clobbering, and live re-theming tests passed.
- Key help below controls matched actual buffer-local mappings
  bidirectionally; single-`Esc` close and `q` close restored workbench focus.
- Pane drag worked in both directions, clamped to minimum widths (left 15,
  right 20 columns), kept windows valid, and preserved selection.
- TASK-002/003/004/007 regression suites, including byte-for-byte Git
  invariance and lazy-browser contracts, remained green.
- `./tests/run_tests.sh`: 33/33 integration tests, offline package suite, and
  7/7 smoke tests passed; syntax, version, JSON, and `git diff --check`
  validation passed.

Evidence was local only; no hosted, production, recovery, or
customer-acceptance claim was made.
