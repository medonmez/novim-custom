# Local oh-my-code Distribution
Updated: 2026-08-31

This is the local packaging and installation path for this checkout. It is
not a hosted release, a package-manager formula, or an update path for the
installed upstream `novim` command. Public release publication and hosted
installer verification belong to the release-delivery task (`TASK-019`).

## Identity and package contents

The public launcher is `bin/ohc`; it reports the identity
`oh-my-code (ohc) <VERSION>-dev` from the checkout's `VERSION` file. The
public package helper is `bin/oh-my-code-package`. It builds the
deterministic, offline archive `oh-my-code-<VERSION>.tar.gz` rooted at
`oh-my-code-<VERSION>/`, containing:

- `bin/ohc`, the public launcher;
- `bin/novim-dev`, the one-release compatibility alias launcher;
- the complete `config/nvim/` tree, including the bundled runtime plugin;
- `VERSION`;
- `LICENSE`; and
- `THIRD_PARTY_LICENSES.md`.

It intentionally does not contain `bin/novim`, Git metadata, `.dev-*` runtime
directories, credentials, environment files, private runtime data, or any
link or special file. The installed upstream `novim` release remains outside
this package.

## Create and inspect a local package

Packaging is deterministic and offline: repeated runs of the same checkout
produce byte-identical archives, and the helper refuses to overwrite an
existing output.

```bash
PACKAGE_TMP="$(mktemp -d "${TMPDIR:-/tmp}/oh-my-code-package.XXXXXX")"
ARCHIVE="$PACKAGE_TMP/oh-my-code-<VERSION>.tar.gz"

./bin/oh-my-code-package package "$ARCHIVE"
tar -tzf "$ARCHIVE"
shasum -a 256 "$ARCHIVE"   # sha256sum on Linux
```

## Install locally

The offline helper extracts a validated archive into a new or empty,
explicitly named directory. It never creates command links and never writes
outside that directory.

```bash
INSTALL_ROOT="$PACKAGE_TMP/install"
./bin/oh-my-code-package install "$ARCHIVE" "$INSTALL_ROOT"
"$INSTALL_ROOT/bin/ohc" --version
"$INSTALL_ROOT/bin/novim-dev" --version
```

The public installer is `install.sh` (served as `docs/install` for
`curl | bash`). It downloads only the declared public Release asset —
`oh-my-code-<VERSION>.tar.gz` plus its `oh-my-code-<VERSION>.tar.gz.sha256`
checksum companion — verifies the checksum, validates the archive structure
fail-closed, installs only below `~/.local/share/oh-my-code`, and creates
`~/.local/bin/ohc` plus the one-release `~/.local/bin/novim-dev`
compatibility link:

```bash
./install.sh v1.0.0                # explicit release tag
curl -fsSL <installer-url> | bash -s -- v1.0.0
```

Installer boundaries:

- Neovim >= 0.8.0 must already be installed; the installer never installs
  Neovim, never uses a package manager for it, never uses `sudo`, and never
  runs `novim --update`.
- `~/.local/bin/ohc` and `~/.local/bin/novim-dev` are created only when
  absent or already pointing into the managed `~/.local/share/oh-my-code`
  root. Unrelated existing files or links are refused, never replaced.
- The install root must be new or empty and must not be a symlink.
- Failed downloads, checksum mismatches, malformed archives, traversal
  entries, allowlist violations, and link collisions leave the target and
  temporary state safe and unchanged.
- `~/.local/bin/novim`, `~/.local/share/novim`, and the normal Neovim
  configuration are never touched.

There is no in-place update: to reinstall, remove the install root
explicitly first. Update/uninstall commands are out of scope.

## Verification and removal boundaries

At the checkout level, `./bin/ohc --version` and `./bin/novim-dev --version`
report the public and compatibility identities without network activity.
Verify the archive manifest, both launcher identities, and a headless launch
from the temporary or dedicated root before relying on it:

```bash
NO_ANIMATION_ROOT="$INSTALL_ROOT" "$INSTALL_ROOT/bin/ohc" --headless --no-animation \
  -c "lua assert(vim.fs.normalize(vim.fn.stdpath('config')) == vim.fs.normalize(os.getenv('NO_ANIMATION_ROOT') .. '/config/nvim'))" \
  -c 'qall!'
```

A launch may create `.dev-data/`, `.dev-state/`, and `.dev-cache/` below the
install root; those are runtime state and are never package inputs.

Startup splash: on an interactive TTY launch, the launchers (`bin/ohc` and
`bin/novim-dev`) render a bounded approximately-one-second ANSI splash before
starting Neovim. Version and help checks never render or wait for the splash.
For scripted or non-interactive full-startup verification, pass
`--no-animation` (consumed by the launcher and never forwarded to Neovim) or
set `OHC_NO_ANIMATION=1`, or run without a TTY (for example `--headless` or
piped output); every bypass starts Neovim immediately. The splash performs no
network call, credential flow, plugin load, or background process.

Removal is limited to the exact install root and, after checking their link
targets, the `~/.local/bin/ohc` and `~/.local/bin/novim-dev` links the
installer created. Never remove or overwrite `$HOME/.local/bin/novim`,
`$HOME/.local/share/novim`, the normal Neovim configuration, or the checkout
as part of this workflow. Temporary package and install roots are local
validation artifacts and may be removed after the checks finish.

No package or install command fetches upstream data, runs `novim --update`,
or performs a Git mutation. Upstream synchronization is a separate, explicit
workflow described in [UPSTREAM_SYNC.md](UPSTREAM_SYNC.md).

All results from these commands are local development evidence only; they do
not establish a hosted, production, recovery, or customer-acceptance release.
