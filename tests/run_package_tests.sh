#!/bin/bash
# tests/run_package_tests.sh - Offline package/installer and sync-boundary checks
#
# Covers the public oh-my-code package (deterministic oh-my-code-<VERSION>.tar.gz),
# the fail-closed installer boundaries (collisions, symlinks, nonempty targets,
# malformed/traversal archives, failed downloads), the installed-package launch
# identity, and preservation of installed novim and the normal Neovim config.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
PACKAGER="$PROJECT_ROOT/bin/oh-my-code-package"
INSTALLER="$PROJECT_ROOT/install.sh"
WORKFLOW="$PROJECT_ROOT/.github/workflows/release.yml"
RUN_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/ohmycode_package_test_XXXXXX")"
MANIFEST="$RUN_ROOT/manifest.txt"
INSTALLED_COMMAND="${HOME}/.local/bin/novim"
INSTALLED_SHARE="${HOME}/.local/share/novim"
NORMAL_NVIM_CONFIG="${HOME}/.config/nvim"
PUBLIC_OHC_LINK="${HOME}/.local/bin/ohc"
PUBLIC_NOVIM_DEV_LINK="${HOME}/.local/bin/novim-dev"
SOURCE_HEAD_BEFORE="$(git -C "$PROJECT_ROOT" rev-parse --verify HEAD)"
SOURCE_STATUS_BEFORE="$(git -C "$PROJECT_ROOT" status --porcelain=v1)"

cleanup() {
  # Restore source fixtures left behind by a failed probe before the
  # fixture backup itself is removed with RUN_ROOT.
  if [[ -f "$RUN_ROOT/source-ohc-real" && -L "$PROJECT_ROOT/bin/ohc" ]]; then
    rm -f "$PROJECT_ROOT/bin/ohc"
    mv "$RUN_ROOT/source-ohc-real" "$PROJECT_ROOT/bin/ohc"
  fi
  if [[ -L "$PROJECT_ROOT/config/nvim/.package-test-leak" ]]; then
    rm -f "$PROJECT_ROOT/config/nvim/.package-test-leak"
  fi
  if [[ -d "$RUN_ROOT" ]]; then
    rm -rf "$RUN_ROOT"
  fi
}
trap cleanup EXIT

fail() {
  echo "Error: $*" >&2
  exit 1
}

manifest_has() {
  if ! grep -Fqx "$1" "$MANIFEST"; then
    fail "package manifest is missing: $1"
  fi
}

sha256_file() {
  if command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  elif command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  else
    fail "shasum or sha256sum is required"
  fi
}

stat_line() {
  stat -f '%Sp %z %N' "$1" 2>/dev/null || stat -c '%A %s %n' "$1"
}

# path_state PATH -> compact, comparable description of the path's current state
path_state() {
  local p="$1"
  if [[ -L "$p" ]]; then
    printf 'symlink:%s\n' "$(readlink "$p")"
  elif [[ -f "$p" ]]; then
    printf 'file:%s\n' "$(sha256_file "$p")"
  elif [[ -d "$p" ]]; then
    printf 'dir:%s\n' "$( (cd "$p" && find . -maxdepth 3 | LC_ALL=C sort | sha256_file /dev/stdin) )"
  elif [[ -e "$p" ]]; then
    printf 'special:%s\n' "$(stat_line "$p")"
  else
    printf 'absent\n'
  fi
}

# tree_state ROOT -> hash of the full sorted listing of a directory tree
tree_state() {
  (cd "$1" && find . -print | LC_ALL=C sort | sha256_file /dev/stdin)
}

# expect_installer_failure LABEL -- runs the installer in a sandbox HOME with
# the given env overrides and requires a nonzero exit plus an unchanged HOME.
expect_installer_failure() {
  local label="$1"
  shift
  local sandbox="$1"
  shift
  local before
  # The installer runs `nvim --version`; Neovim itself creates XDG state
  # directories below HOME on any invocation. Pre-warm them so the
  # before/after comparison measures installer behavior only.
  ( export HOME="$sandbox"; nvim --version >/dev/null 2>&1 || true )
  before="$(tree_state "$sandbox")"
  if ( export HOME="$sandbox"; "$@" ) >/dev/null 2>"$RUN_ROOT/fail.log"; then
    fail "$label: installer unexpectedly succeeded"
  fi
  if [[ "$(tree_state "$sandbox")" != "$before" ]]; then
    fail "$label: failed installer mutated the sandbox HOME"
  fi
}

if [[ ! -x "$PACKAGER" ]]; then
  fail "package helper is not executable: $PACKAGER"
fi
if [[ ! -f "$INSTALLER" ]]; then
  fail "installer is missing: $INSTALLER"
fi
if ! command -v tar >/dev/null 2>&1; then
  fail "tar is required"
fi
if ! command -v git >/dev/null 2>&1; then
  fail "git is required"
fi
if ! command -v nvim >/dev/null 2>&1; then
  fail "nvim is required for installed package smoke validation"
fi
if ! command -v python3 >/dev/null 2>&1; then
  fail "python3 is required for hostile-archive fixtures"
fi

INSTALLED_STATE_BEFORE="$(path_state "$INSTALLED_COMMAND")"
INSTALLED_SHARE_BEFORE="$(path_state "$INSTALLED_SHARE")"
NORMAL_CONFIG_BEFORE="$(path_state "$NORMAL_NVIM_CONFIG")"
PUBLIC_OHC_BEFORE="$(path_state "$PUBLIC_OHC_LINK")"
PUBLIC_NOVIM_DEV_BEFORE="$(path_state "$PUBLIC_NOVIM_DEV_LINK")"
BIN_NOVIM_HASH_BEFORE="$(sha256_file "$PROJECT_ROOT/bin/novim")"
INSTALLED_VERSION_BEFORE=""
if [[ -x "$INSTALLED_COMMAND" ]]; then
  INSTALLED_VERSION_BEFORE="$("$INSTALLED_COMMAND" --version 2>&1)"
fi

VERSION="$(tr -d '[:space:]' < "$PROJECT_ROOT/VERSION")"
PACKAGE_ROOT="oh-my-code-$VERSION"

echo "=== oh-my-code Offline Package and Installer Tests ==="
ARCHIVE_ONE="$RUN_ROOT/one/oh-my-code-$VERSION.tar.gz"
ARCHIVE_TWO="$RUN_ROOT/two/oh-my-code-$VERSION.tar.gz"
echo "Project root: $PROJECT_ROOT"
echo "Package helper: $PACKAGER"

echo "--- Deterministic public package ---"
"$PACKAGER" package "$ARCHIVE_ONE" >/dev/null
"$PACKAGER" package "$ARCHIVE_TWO" >/dev/null
if ! cmp -s "$ARCHIVE_ONE" "$ARCHIVE_TWO"; then
  fail "repeated package creation is not byte-identical"
fi
if [[ "$(sha256_file "$ARCHIVE_ONE")" != "$(sha256_file "$ARCHIVE_TWO")" ]]; then
  fail "identical archives produced different SHA-256 digests"
fi
echo "  SHA-256: $(sha256_file "$ARCHIVE_ONE")"
if "$PACKAGER" package "$ARCHIVE_ONE" >/dev/null 2>&1; then
  fail "package helper overwrote an existing archive"
fi
if [[ "$(sha256_file "$ARCHIVE_ONE")" != "$(sha256_file "$ARCHIVE_TWO")" ]]; then
  fail "refused-overwrite probe mutated the archive"
fi
echo "  PASS: byte-identical archive, stable checksum, overwrite refusal"

echo "--- Public archive manifest ---"
tar -tzf "$ARCHIVE_ONE" > "$MANIFEST"
manifest_has "$PACKAGE_ROOT/"
manifest_has "$PACKAGE_ROOT/bin/"
manifest_has "$PACKAGE_ROOT/bin/ohc"
manifest_has "$PACKAGE_ROOT/bin/novim-dev"
manifest_has "$PACKAGE_ROOT/config/"
manifest_has "$PACKAGE_ROOT/config/nvim/"
manifest_has "$PACKAGE_ROOT/config/nvim/init.lua"
manifest_has "$PACKAGE_ROOT/config/nvim/lua/novim/workbench.lua"
manifest_has "$PACKAGE_ROOT/config/nvim/pack/plugins/start/gitsigns.nvim/lua/gitsigns.lua"
manifest_has "$PACKAGE_ROOT/VERSION"
manifest_has "$PACKAGE_ROOT/LICENSE"
manifest_has "$PACKAGE_ROOT/THIRD_PARTY_LICENSES.md"

if grep -Eq '(^|/)\.git(/|$)|(^|/)\.dev-[^/]*(/|$)' "$MANIFEST"; then
  fail "package manifest contains Git metadata or development runtime state"
fi
if grep -Eiq '(^|/)(\.env([.]|$)|.*credential.*|.*secret.*|.*\.(pem|key|sqlite|db))(/|$)' "$MANIFEST"; then
  fail "package manifest contains a private or credential-like entry"
fi
if grep -Fqx "$PACKAGE_ROOT/bin/novim" "$MANIFEST"; then
  fail "package manifest contains the installed-release launcher"
fi
if grep -Eq '(^|/)\.\.(/|$)' "$MANIFEST"; then
  fail "package manifest contains a traversal entry"
fi
if tar -tvzf "$ARCHIVE_ONE" | grep -Eq '^[[:space:]]*[bchlps]'; then
  fail "package archive contains a link or special file"
fi
echo "  PASS: allowlisted contents, single safe root, no forbidden entries"
echo "--- Package source-tree fail-closed validation ---"
PRIVATE_SOURCE="$RUN_ROOT/private-source.txt"
printf 'private-source' > "$PRIVATE_SOURCE"
SYMLINK_PROBE_DIR="$RUN_ROOT/symlink-probe"
SYMLINK_PROBE_OUTPUT="$SYMLINK_PROBE_DIR/oh-my-code-$VERSION.tar.gz"
mkdir -p "$SYMLINK_PROBE_DIR"

mv "$PROJECT_ROOT/bin/ohc" "$RUN_ROOT/source-ohc-real"
ln -s "$PRIVATE_SOURCE" "$PROJECT_ROOT/bin/ohc"
if "$PACKAGER" package "$SYMLINK_PROBE_OUTPUT" >/dev/null 2>&1; then
  fail "package helper dereferenced a symlinked required file"
fi
[[ ! -e "$SYMLINK_PROBE_OUTPUT" && ! -L "$SYMLINK_PROBE_OUTPUT" ]] ||
  fail "symlinked required file still produced an archive"
[[ -z "$(find "$SYMLINK_PROBE_DIR" -name '.oh-my-code-package.*' -print -quit)" ]] ||
  fail "symlink probe left archive bytes in the output directory"
mv "$RUN_ROOT/source-ohc-real" "$PROJECT_ROOT/bin/ohc"

ln -s "$PRIVATE_SOURCE" "$PROJECT_ROOT/config/nvim/.package-test-leak"
if "$PACKAGER" package "$SYMLINK_PROBE_OUTPUT" >/dev/null 2>&1; then
  fail "package helper packaged a symlinked config/nvim entry"
fi
[[ ! -e "$SYMLINK_PROBE_OUTPUT" && ! -L "$SYMLINK_PROBE_OUTPUT" ]] ||
  fail "symlinked config entry still produced an archive"
rm -f "$PROJECT_ROOT/config/nvim/.package-test-leak"

"$PACKAGER" package "$SYMLINK_PROBE_OUTPUT" >/dev/null
[[ "$(sha256_file "$SYMLINK_PROBE_OUTPUT")" == "$(sha256_file "$ARCHIVE_ONE")" ]] ||
  fail "source validation changed the clean-tree package"
echo "  PASS: symlinked source inputs rejected with no archive; clean tree unchanged"

echo "--- Hostile archive fixtures ---"
FIXTURES="$RUN_ROOT/fixtures"
mkdir -p "$FIXTURES"
python3 - "$FIXTURES" "$VERSION" <<'PYFIXTURES'
import io, os, sys, tarfile

outdir = sys.argv[1]
version = sys.argv[2]
root = "oh-my-code-" + version
asset = root + ".tar.gz"

def fixture(kind):
    d = os.path.join(outdir, kind)
    os.makedirs(d, exist_ok=True)
    return os.path.join(d, asset)

def add(t, name, data=b"", mode=0o644, type_=None, linkname=""):
    ti = tarfile.TarInfo(name)
    ti.mode = mode
    ti.linkname = linkname
    if type_ is not None:
        ti.type = type_
    elif name.endswith("/"):
        ti.type = tarfile.DIRTYPE
    else:
        ti.type = tarfile.REGTYPE
    ti.size = len(data) if ti.type == tarfile.REGTYPE else 0
    if ti.type == tarfile.REGTYPE:
        t.addfile(ti, io.BytesIO(data))
    else:
        t.addfile(ti)

with tarfile.open(fixture("traversal"), "w:gz") as t:
    add(t, root + "/")
    add(t, root + "/VERSION", (version + "\n").encode())
    add(t, root + "/../../evil.txt", b"evil")

with tarfile.open(fixture("absolute"), "w:gz") as t:
    add(t, root + "/")
    add(t, "/etc/oh-my-code-pwned.txt", b"pwned")

with tarfile.open(fixture("symlink"), "w:gz") as t:
    add(t, root + "/")
    add(t, root + "/VERSION", (version + "\n").encode())
    add(t, root + "/LICENSE", b"MIT\n")
    add(t, root + "/THIRD_PARTY_LICENSES.md", b"third party\n")
    add(t, root + "/bin/")
    add(t, root + "/bin/ohc", b"#!/bin/sh\n", mode=0o755)
    add(t, root + "/bin/novim-dev", b"#!/bin/sh\n", mode=0o755)
    add(t, root + "/config/")
    add(t, root + "/config/nvim/")
    add(t, root + "/config/nvim/init.lua", b"-- init\n")
    add(t, root + "/config/nvim/evil-link", type_=tarfile.SYMTYPE,
        linkname="/etc/passwd")

with tarfile.open(fixture("extra-entry"), "w:gz") as t:
    add(t, root + "/")
    add(t, root + "/VERSION", (version + "\n").encode())
    add(t, root + "/extra-not-allowed.txt", b"x")

with tarfile.open(fixture("wrong-version"), "w:gz") as t:
    add(t, root + "/")
    add(t, root + "/VERSION", b"wrong-version\n")
    add(t, root + "/LICENSE", b"MIT\n")
    add(t, root + "/THIRD_PARTY_LICENSES.md", b"third party\n")
    add(t, root + "/bin/")
    add(t, root + "/bin/ohc", b"#!/bin/sh\n", mode=0o755)
    add(t, root + "/bin/novim-dev", b"#!/bin/sh\n", mode=0o755)
    add(t, root + "/config/")
    add(t, root + "/config/nvim/")
    add(t, root + "/config/nvim/init.lua", b"-- init\n")

with open(fixture("malformed"), "wb") as f:
    f.write(b"this is not a tar.gz archive")
PYFIXTURES
echo "  fixtures built: traversal, absolute, symlink-member, extra-entry, malformed, wrong-version"
echo "  PASS: hostile fixtures prepared"

echo "--- Offline helper install and launcher identity ---"
INSTALL_ROOT="$(cd "$RUN_ROOT" && pwd -P)/install"
"$PACKAGER" install "$ARCHIVE_ONE" "$INSTALL_ROOT" >/dev/null
[[ -x "$INSTALL_ROOT/bin/ohc" ]] || fail "installed public launcher is not executable"
[[ -x "$INSTALL_ROOT/bin/novim-dev" ]] || fail "installed alias launcher is not executable"
[[ ! -e "$INSTALL_ROOT/bin/novim" ]] || fail "install created an installed-release alias"
[[ ! -e "$INSTALL_ROOT/.git" ]] || fail "install extracted Git metadata"

NONEMPTY_ROOT="$RUN_ROOT/nonempty-install"
mkdir -p "$NONEMPTY_ROOT"
touch "$NONEMPTY_ROOT/preserved-marker"
if "$PACKAGER" install "$ARCHIVE_ONE" "$NONEMPTY_ROOT" >/dev/null 2>&1; then
  fail "installer overwrote a nonempty target"
fi
[[ -f "$NONEMPTY_ROOT/preserved-marker" ]] || fail "nonempty target was altered"

SYMLINK_ROOT="$RUN_ROOT/symlink-install"
mkdir -p "$RUN_ROOT/symlink-outside"
ln -s "$RUN_ROOT/symlink-outside" "$SYMLINK_ROOT"
if "$PACKAGER" install "$ARCHIVE_ONE" "$SYMLINK_ROOT" >/dev/null 2>&1; then
  fail "installer extracted through a symlinked root"
fi
[[ -L "$SYMLINK_ROOT" ]] || fail "symlinked root was replaced"
[[ -z "$(find "$RUN_ROOT/symlink-outside" -mindepth 1 -print -quit)" ]] || fail "symlinked root target was populated"

for fixture_name in traversal absolute symlink extra-entry malformed wrong-version; do
  if "$PACKAGER" install "$FIXTURES/$fixture_name/oh-my-code-$VERSION.tar.gz" "$RUN_ROOT/hostile-install" >/dev/null 2>&1; then
    fail "helper accepted the $fixture_name archive"
  fi
done
[[ ! -e "$RUN_ROOT/hostile-install" ]] || fail "hostile archive created an install root"
[[ ! -e "$RUN_ROOT/evil.txt" ]] || fail "traversal fixture escaped the archive boundary"
echo "--- Offline helper: archive VERSION identity mismatch ---"
VERSION_MISMATCH_ARCHIVE="$FIXTURES/wrong-version/oh-my-code-$VERSION.tar.gz"
if "$PACKAGER" install "$VERSION_MISMATCH_ARCHIVE" "$RUN_ROOT/version-mismatch-absent" >/dev/null 2>&1; then
  fail "offline helper accepted an archive whose VERSION disagrees with its root"
fi
[[ ! -e "$RUN_ROOT/version-mismatch-absent" ]] || fail "VERSION mismatch created an install root"
mkdir -p "$RUN_ROOT/version-mismatch-empty"
if "$PACKAGER" install "$VERSION_MISMATCH_ARCHIVE" "$RUN_ROOT/version-mismatch-empty" >/dev/null 2>&1; then
  fail "offline helper installed despite a VERSION mismatch"
fi
[[ -z "$(find "$RUN_ROOT/version-mismatch-empty" -mindepth 1 -print -quit)" ]] || fail "VERSION mismatch mutated an existing empty target"
echo "  PASS: VERSION mismatch refused with the target unchanged"

diff -ru "$PROJECT_ROOT/config/nvim" "$INSTALL_ROOT/config/nvim" >/dev/null || fail "installed config differs from package source"
cmp -s "$PROJECT_ROOT/VERSION" "$INSTALL_ROOT/VERSION" || fail "installed VERSION differs"
cmp -s "$PROJECT_ROOT/LICENSE" "$INSTALL_ROOT/LICENSE" || fail "installed LICENSE differs"
cmp -s "$PROJECT_ROOT/THIRD_PARTY_LICENSES.md" "$INSTALL_ROOT/THIRD_PARTY_LICENSES.md" || fail "installed attribution differs"

OHM_PACKAGE_IDENTITY="$("$INSTALL_ROOT/bin/ohc" --version)"
[[ "$OHM_PACKAGE_IDENTITY" == *"oh-my-code (ohc) $VERSION-dev"* ]] || fail "installed public identity mismatch"
PACKAGE_VERSION_OUTPUT="$("$INSTALL_ROOT/bin/novim-dev" --version)"
[[ "$PACKAGE_VERSION_OUTPUT" == *"novim-dev $VERSION-dev (custom checkout)"* ]] || fail "installed compatibility identity mismatch"
[[ "$PACKAGE_VERSION_OUTPUT" == *"one-release compatibility alias"* ]] || fail "installed alias does not label its one-release status"
PACKAGE_HELP_OUTPUT="$("$INSTALL_ROOT/bin/ohc" --help)"
[[ "$PACKAGE_HELP_OUTPUT" == *"Configuration root:"* ]] || fail "installed launcher help mismatch"

NO_ANIMATION_ROOT="$INSTALL_ROOT" "$INSTALL_ROOT/bin/ohc" --headless --no-animation \
  -c "lua local ok, err = pcall(function() assert(not vim.tbl_contains(vim.v.argv, '--no-animation'), '--no-animation was forwarded to Neovim') local root = vim.fs.normalize(os.getenv('NO_ANIMATION_ROOT')) assert(vim.fs.normalize(vim.fn.stdpath('config')) == root .. '/config/nvim', 'config path mismatch: ' .. vim.fn.stdpath('config')) assert(vim.fs.normalize(vim.fn.stdpath('data')) == root .. '/.dev-data/nvim', 'data path mismatch: ' .. vim.fn.stdpath('data')) assert(vim.fs.normalize(vim.fn.stdpath('state')) == root .. '/.dev-state/nvim', 'state path mismatch: ' .. vim.fn.stdpath('state')) assert(vim.fs.normalize(vim.fn.stdpath('cache')) == root .. '/.dev-cache/nvim', 'cache path mismatch: ' .. vim.fn.stdpath('cache')) assert(vim.fn.exists(':Workbench') == 2, 'Workbench command missing') assert(vim.fn.exists(':DiffWorkbench') == 2, 'DiffWorkbench command missing') assert(vim.fn.exists(':Settings') == 2, 'Settings command missing') end) if ok then vim.cmd('qall!') else io.stderr:write(err .. '\n') vim.cmd('cquit 1') end"

OHC_NO_ANIMATION=1 NO_ANIMATION_ROOT="$INSTALL_ROOT" "$INSTALL_ROOT/bin/ohc" --headless \
  -c "lua assert(true)" -c 'qall!'

[[ -d "$INSTALL_ROOT/.dev-data" ]] || fail "package data path was not isolated"
[[ -d "$INSTALL_ROOT/.dev-state" ]] || fail "package state path was not isolated"
[[ -d "$INSTALL_ROOT/.dev-cache" ]] || fail "package cache path was not isolated"
echo "  PASS: temporary install, identities, splash bypasses, isolated runtime"

echo "--- Installer: sandboxed happy path (local archive mode) ---"
SBX="$RUN_ROOT/home-happy"
mkdir -p "$SBX"
HOME="$SBX" env OHC_INSTALL_ARCHIVE="$ARCHIVE_ONE" "$INSTALLER" >/dev/null
OHM_SANDBOX_ROOT="$SBX/.local/share/oh-my-code"
[[ -x "$OHM_SANDBOX_ROOT/bin/ohc" ]] || fail "installer did not install the public launcher"
[[ -x "$OHM_SANDBOX_ROOT/bin/novim-dev" ]] || fail "installer did not install the alias launcher"
[[ -L "$SBX/.local/bin/ohc" ]] || fail "installer did not create the ohc link"
[[ "$(readlink "$SBX/.local/bin/ohc")" == "$OHM_SANDBOX_ROOT/bin/ohc" ]] || fail "ohc link does not point into the managed root"
[[ -L "$SBX/.local/bin/novim-dev" ]] || fail "installer did not create the novim-dev compatibility link"
[[ "$(readlink "$SBX/.local/bin/novim-dev")" == "$OHM_SANDBOX_ROOT/bin/novim-dev" ]] || fail "novim-dev link does not point into the managed root"
SANDBOX_IDENTITY="$(HOME="$SBX" "$SBX/.local/bin/ohc" --version)"
[[ "$SANDBOX_IDENTITY" == *"oh-my-code (ohc) $VERSION-dev"* ]] || fail "sandbox-installed ohc identity mismatch"
SANDBOX_ALIAS="$(HOME="$SBX" "$SBX/.local/bin/novim-dev" --version)"
[[ "$SANDBOX_ALIAS" == *"novim-dev $VERSION-dev (custom checkout)"* ]] || fail "sandbox-installed novim-dev identity mismatch"
[[ ! -e "$SBX/.local/bin/novim" ]] || fail "installer touched the installed novim command path"
[[ ! -e "$SBX/.local/share/novim" ]] || fail "installer touched the installed novim share path"
[[ ! -e "$OHM_SANDBOX_ROOT/bin/novim" ]] || fail "installer produced an installed-release alias"

INSTALL_ROOT_STATE="$(tree_state "$OHM_SANDBOX_ROOT")"
if HOME="$SBX" env OHC_INSTALL_ARCHIVE="$ARCHIVE_ONE" "$INSTALLER" >/dev/null 2>"$RUN_ROOT/rerun.log"; then
  fail "installer reinstalled over a nonempty root"
fi
[[ "$(tree_state "$OHM_SANDBOX_ROOT")" == "$INSTALL_ROOT_STATE" ]] || fail "failed reinstall mutated the installed root"

echo "--- Installer: absent-or-owned link rule ---"
SBX_OWNED="$RUN_ROOT/home-owned"
mkdir -p "$SBX_OWNED/.local/bin"
ln -s "$SBX_OWNED/.local/share/oh-my-code/bin/ohc" "$SBX_OWNED/.local/bin/ohc"
HOME="$SBX_OWNED" env OHC_INSTALL_ARCHIVE="$ARCHIVE_ONE" "$INSTALLER" >/dev/null
[[ "$(readlink "$SBX_OWNED/.local/bin/ohc")" == "$SBX_OWNED/.local/share/oh-my-code/bin/ohc" ]] || fail "owned ohc link was rewritten"
HOME="$SBX_OWNED" "$SBX_OWNED/.local/bin/ohc" --version >/dev/null || fail "kept owned link does not launch"
echo "  PASS: happy install, links, reinstall refusal, owned-link reuse"

echo "--- Installer: fail-closed collision and target cases ---"
SBX_FILE="$RUN_ROOT/home-collision-file"
mkdir -p "$SBX_FILE/.local/bin"
printf 'unrelated-user-file' > "$SBX_FILE/.local/bin/ohc"
expect_installer_failure "unrelated ohc file" "$SBX_FILE" \
  env OHC_INSTALL_ARCHIVE="$ARCHIVE_ONE" "$INSTALLER"
[[ "$(cat "$SBX_FILE/.local/bin/ohc")" == "unrelated-user-file" ]] || fail "unrelated ohc file was modified"
[[ ! -e "$SBX_FILE/.local/share/oh-my-code" ]] || fail "collision failure created an install root"

SBX_LINK="$RUN_ROOT/home-collision-link"
mkdir -p "$SBX_LINK/.local/bin"
ln -s /tmp "$SBX_LINK/.local/bin/novim-dev"
expect_installer_failure "unrelated novim-dev link" "$SBX_LINK" \
  env OHC_INSTALL_ARCHIVE="$ARCHIVE_ONE" "$INSTALLER"
[[ "$(readlink "$SBX_LINK/.local/bin/novim-dev")" == "/tmp" ]] || fail "unrelated novim-dev link was modified"

SBX_ROOT_LINK="$RUN_ROOT/home-symlink-root"
mkdir -p "$SBX_ROOT_LINK/.local/share" "$RUN_ROOT/root-link-target"
ln -s "$RUN_ROOT/root-link-target" "$SBX_ROOT_LINK/.local/share/oh-my-code"
expect_installer_failure "symlinked install root" "$SBX_ROOT_LINK" \
  env OHC_INSTALL_ARCHIVE="$ARCHIVE_ONE" "$INSTALLER"
[[ -L "$SBX_ROOT_LINK/.local/share/oh-my-code" ]] || fail "symlinked install root was replaced"
[[ -z "$(find "$RUN_ROOT/root-link-target" -mindepth 1 -print -quit)" ]] || fail "symlinked install root target was populated"

SBX_NONEMPTY="$RUN_ROOT/home-nonempty"
mkdir -p "$SBX_NONEMPTY/.local/share/oh-my-code"
printf 'keep' > "$SBX_NONEMPTY/.local/share/oh-my-code/marker"
expect_installer_failure "nonempty install root" "$SBX_NONEMPTY" \
  env OHC_INSTALL_ARCHIVE="$ARCHIVE_ONE" "$INSTALLER"
[[ "$(cat "$SBX_NONEMPTY/.local/share/oh-my-code/marker")" == "keep" ]] || fail "nonempty install root was altered"

SBX_BIN_LINK="$RUN_ROOT/home-bin-link"
mkdir -p "$SBX_BIN_LINK/.local" "$RUN_ROOT/bin-link-target"
ln -s "$RUN_ROOT/bin-link-target" "$SBX_BIN_LINK/.local/bin"
expect_installer_failure "symlinked command directory" "$SBX_BIN_LINK" \
  env OHC_INSTALL_ARCHIVE="$ARCHIVE_ONE" "$INSTALLER"
[[ -L "$SBX_BIN_LINK/.local/bin" ]] || fail "symlinked command directory was replaced"
echo "  PASS: collisions, symlinked roots, nonempty targets all fail closed"

echo "--- Installer: hostile and malformed archives ---"
for fixture_name in traversal absolute symlink extra-entry malformed wrong-version; do
  SBX_HOSTILE="$RUN_ROOT/home-hostile-$fixture_name"
  mkdir -p "$SBX_HOSTILE"
  expect_installer_failure "hostile archive ($fixture_name)" "$SBX_HOSTILE" \
    env OHC_INSTALL_ARCHIVE="$FIXTURES/$fixture_name/oh-my-code-$VERSION.tar.gz" "$INSTALLER"
done
[[ ! -e "$RUN_ROOT/home-hostile-traversal/.local/share/oh-my-code" ]] || fail "hostile archive created an install root"
[[ ! -e "$RUN_ROOT/home-hostile-wrong-version/.local/share/oh-my-code" ]] || fail "VERSION-mismatch archive created an install root"
[[ ! -e "$RUN_ROOT/evil.txt" ]] || fail "installer wrote a traversal entry outside the archive"
echo "  PASS: malformed, traversal, absolute, symlink, allowlist, and VERSION-mismatch refusals"

echo "--- Installer: networked download path over a local fixture server ---"
WWW_ROOT="$RUN_ROOT/www"
DOCROOT="$WWW_ROOT/releases/download/v$VERSION"
mkdir -p "$DOCROOT" "$WWW_ROOT/baddigest/releases/download/v$VERSION" "$WWW_ROOT/badname/releases/download/v$VERSION"
cp "$ARCHIVE_ONE" "$DOCROOT/oh-my-code-$VERSION.tar.gz"
( cd "$DOCROOT" && if command -v sha256sum >/dev/null 2>&1; then sha256sum "oh-my-code-$VERSION.tar.gz"; else shasum -a 256 "oh-my-code-$VERSION.tar.gz"; fi > "oh-my-code-$VERSION.tar.gz.sha256" )
cp "$DOCROOT/oh-my-code-$VERSION.tar.gz" "$WWW_ROOT/baddigest/releases/download/v$VERSION/"
( cd "$WWW_ROOT/baddigest/releases/download/v$VERSION" && awk 'BEGIN { printf "%064d  %s\n", 0, name }' name="oh-my-code-$VERSION.tar.gz" > "oh-my-code-$VERSION.tar.gz.sha256" )
cp "$DOCROOT/oh-my-code-$VERSION.tar.gz" "$WWW_ROOT/badname/releases/download/v$VERSION/"
( cd "$WWW_ROOT/badname/releases/download/v$VERSION" && sha256_file "oh-my-code-$VERSION.tar.gz" | awk '{print $1"  wrong-name.tar.gz"}' > "oh-my-code-$VERSION.tar.gz.sha256" )

SERVER_PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1]); s.close()')"
SERVER_LOG="$RUN_ROOT/server.log"
python3 -m http.server "$SERVER_PORT" --bind 127.0.0.1 --directory "$WWW_ROOT" >"$SERVER_LOG" 2>&1 &
SERVER_PID=$!
server_ready=0
for _ in 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20; do
  if python3 -c "import socket; socket.create_connection(('127.0.0.1', $SERVER_PORT), 0.5)" 2>/dev/null; then
    server_ready=1
    break
  fi
  sleep 0.2
done
[[ "$server_ready" == 1 ]] || { kill "$SERVER_PID" 2>/dev/null || true; fail "fixture HTTP server did not become ready"; }

BASE_URL="http://127.0.0.1:$SERVER_PORT/releases/download/v$VERSION"
ASSET_NAME="oh-my-code-$VERSION.tar.gz"

SBX_NET="$RUN_ROOT/home-net"
mkdir -p "$SBX_NET"
if ! HOME="$SBX_NET" env OHC_RELEASE_URL="$BASE_URL/$ASSET_NAME" "$INSTALLER" >/dev/null; then
  kill "$SERVER_PID" 2>/dev/null || true
  fail "networked install over the local fixture server failed"
fi
[[ -x "$SBX_NET/.local/share/oh-my-code/bin/ohc" ]] || fail "downloaded install lacks the public launcher"
[[ "$(HOME="$SBX_NET" "$SBX_NET/.local/bin/ohc" --version)" == *"oh-my-code (ohc) $VERSION-dev"* ]] || fail "downloaded install identity mismatch"
GET_ARCHIVE_COUNT="$(grep -cF "GET /releases/download/v$VERSION/$ASSET_NAME HTTP" "$SERVER_LOG" || true)"
GET_SHA_COUNT="$(grep -cF "GET /releases/download/v$VERSION/$ASSET_NAME.sha256 HTTP" "$SERVER_LOG" || true)"
GET_TOTAL="$(grep -c 'GET ' "$SERVER_LOG" || true)"
[[ "$GET_ARCHIVE_COUNT" == "1" ]] || fail "archive asset was not downloaded exactly once"
[[ "$GET_SHA_COUNT" == "1" ]] || fail "checksum asset was not downloaded exactly once"
[[ "$GET_TOTAL" == "2" ]] || fail "installer fetched unexpected extra resources ($GET_TOTAL GETs)"

expect_installer_failure "checksum digest mismatch" "$RUN_ROOT/home-baddigest" \
  env OHC_RELEASE_URL="http://127.0.0.1:$SERVER_PORT/baddigest/releases/download/v$VERSION/$ASSET_NAME" "$INSTALLER"
[[ ! -e "$RUN_ROOT/home-baddigest/.local/share/oh-my-code" ]] || fail "checksum-mismatch failure created an install root"

expect_installer_failure "checksum name mismatch" "$RUN_ROOT/home-badname" \
  env OHC_RELEASE_URL="http://127.0.0.1:$SERVER_PORT/badname/releases/download/v$VERSION/$ASSET_NAME" "$INSTALLER"

expect_installer_failure "missing asset download (404)" "$RUN_ROOT/home-404" \
  env OHC_RELEASE_URL="http://127.0.0.1:$SERVER_PORT/releases/download/v$VERSION-rc/$ASSET_NAME" "$INSTALLER"
expect_installer_failure "unreachable download host" "$RUN_ROOT/home-unreachable" \
  env OHC_RELEASE_URL="http://127.0.0.1:1/$ASSET_NAME" "$INSTALLER"

kill "$SERVER_PID" 2>/dev/null || true
wait "$SERVER_PID" 2>/dev/null || true
echo "  PASS: declared-asset-only download, checksum verification, failed downloads"

echo "--- Release workflow structure ---"
if command -v python3 >/dev/null 2>&1 && python3 -c 'import yaml' >/dev/null 2>&1; then
  python3 - "$WORKFLOW" <<'PYWORKFLOW'
import sys
import yaml

path = sys.argv[1]
with open(path) as f:
    doc = yaml.safe_load(f)

def die(msg):
    sys.stderr.write("release workflow validation failed: %s\n" % msg)
    sys.exit(1)

if doc.get("name") != "Release":
    die("unexpected workflow name")
on = doc.get("on", doc.get(True))
if not isinstance(on, dict) or list(on.keys()) != ["push"]:
    die("trigger must be tag-push only, got %r" % (list(on.keys()) if isinstance(on, dict) else on,))
if on["push"].get("tags") != ["v*"]:
    die("push trigger must filter to v* tags")
if any(k in on for k in ("pull_request", "workflow_dispatch", "schedule")):
    die("workflow must not run on extra triggers")
if doc.get("permissions") != {"contents": "write"}:
    die("permissions must be exactly contents: write")
job = (doc.get("jobs") or {}).get("release")
if not isinstance(job, dict):
    die("missing release job")
steps = job.get("steps")
if not steps:
    die("release job has no steps")
allowed_uses = {"actions/checkout@v4", "softprops/action-gh-release@v2"}
release_steps = []
for step in steps:
    if ("uses" in step) == ("run" in step):
        die("step %r must have exactly one of uses/run" % step.get("name"))
    if "uses" in step:
        if step["uses"] not in allowed_uses:
            die("unpinned or unknown action: %s" % step["uses"])
        if step["uses"] == "softprops/action-gh-release@v2":
            release_steps.append(step)
        continue
    for line in step["run"].splitlines():
        if "bin/novim" in line and "git diff --exit-code" not in line and "grep -Fqx" not in line:
            die("run step mutates or packages bin/novim: %s" % line.strip())
if len(release_steps) != 1:
    die("expected exactly one release publication step")
files = release_steps[0].get("with", {}).get("files", "")
if ".sha256" not in files:
    die("release assets must include the checksum companion")
print("  release workflow structure OK")
PYWORKFLOW
else
  echo "  SKIP: python3 with PyYAML unavailable; workflow YAML validation skipped"
fi

echo "--- Offline fixture validation of explicit sync boundaries ---"
SYNC_RUNBOOK="$PROJECT_ROOT/docs/UPSTREAM_SYNC.md"
for phrase in \
  'git fetch --no-tags upstream main' \
  'BASELINE="$(git rev-parse --verify HEAD)"' \
  'git diff --stat "$BASELINE..$UPSTREAM_MAIN"' \
  'git switch -c task/TASK-NNN-upstream-sync-review "$BASELINE"' \
  'git merge --no-ff --no-commit "$UPSTREAM_MAIN"' \
  'git cherry-pick --abort' \
  'git merge --abort' \
  'git revert -m 1 <sync-merge-commit>'; do
  grep -Fq "$phrase" "$SYNC_RUNBOOK" || fail "sync runbook is missing: $phrase"
done

REMOTE_REPO="$RUN_ROOT/upstream-fixture.git"
SEED_REPO="$RUN_ROOT/upstream-seed"
SYNC_REPO="$RUN_ROOT/sync-review"
git init --bare -q "$REMOTE_REPO"
git init -q "$SEED_REPO"
git -C "$SEED_REPO" config user.email 'package-test@example.com'
git -C "$SEED_REPO" config user.name 'Package Test Runner'
git -C "$SEED_REPO" commit --allow-empty -q -m 'fixture baseline'
git -C "$SEED_REPO" branch -M main
git -C "$SEED_REPO" remote add origin "$REMOTE_REPO"
git -C "$SEED_REPO" push -q origin main
git clone -q --branch main "$REMOTE_REPO" "$SYNC_REPO"
git -C "$SYNC_REPO" remote rename origin upstream
FIXTURE_BASELINE="$(git -C "$SYNC_REPO" rev-parse --verify HEAD)"
git -C "$SEED_REPO" commit --allow-empty -q -m 'fixture candidate'
git -C "$SEED_REPO" push -q origin main
git -C "$SYNC_REPO" fetch --no-tags upstream main >/dev/null
FIXTURE_UPSTREAM="$(git -C "$SYNC_REPO" rev-parse --verify upstream/main)"
[[ "$FIXTURE_BASELINE" != "$FIXTURE_UPSTREAM" ]] || fail "fixture upstream did not advance"
git -C "$SYNC_REPO" diff --stat "$FIXTURE_BASELINE..$FIXTURE_UPSTREAM" >/dev/null
[[ "$(git -C "$SYNC_REPO" rev-parse --verify HEAD)" == "$FIXTURE_BASELINE" ]] || fail "fixture compare mutated the review HEAD"
[[ -z "$(git -C "$SYNC_REPO" status --porcelain=v1)" ]] || fail "fixture compare dirtied the review tree"
echo "  PASS: runbook checkpoints and local-only fetch/compare fixture"

echo "--- Existing release and checkout invariance ---"
[[ "$(git -C "$PROJECT_ROOT" rev-parse --verify HEAD)" == "$SOURCE_HEAD_BEFORE" ]] || fail "source checkout HEAD changed"
[[ "$(git -C "$PROJECT_ROOT" status --porcelain=v1)" == "$SOURCE_STATUS_BEFORE" ]] || fail "source checkout status changed"
[[ "$(sha256_file "$PROJECT_ROOT/bin/novim")" == "$BIN_NOVIM_HASH_BEFORE" ]] || fail "bin/novim changed during packaging"
[[ "$(path_state "$INSTALLED_COMMAND")" == "$INSTALLED_STATE_BEFORE" ]] || fail "installed novim command changed"
[[ "$(path_state "$INSTALLED_SHARE")" == "$INSTALLED_SHARE_BEFORE" ]] || fail "installed novim share directory changed"
[[ "$(path_state "$NORMAL_NVIM_CONFIG")" == "$NORMAL_CONFIG_BEFORE" ]] || fail "normal Neovim configuration changed"
[[ "$(path_state "$PUBLIC_OHC_LINK")" == "$PUBLIC_OHC_BEFORE" ]] || fail "user ohc link changed"
[[ "$(path_state "$PUBLIC_NOVIM_DEV_LINK")" == "$PUBLIC_NOVIM_DEV_BEFORE" ]] || fail "user novim-dev link changed"
if [[ -x "$INSTALLED_COMMAND" ]]; then
  [[ "$("$INSTALLED_COMMAND" --version 2>&1)" == "$INSTALLED_VERSION_BEFORE" ]] || fail "installed novim version output changed"
fi
echo "  PASS: installed novim, normal Neovim config, unrelated links, and checkout unchanged"

echo "=== Offline Package and Installer Tests Passed ==="
