#!/bin/bash
# install.sh - Networked installer for the oh-my-code public Release asset
#
# Downloads only the declared oh-my-code release archive and its checksum,
# validates both fail-closed before extraction, installs only below
# ~/.local/share/oh-my-code, and creates ~/.local/bin/ohc plus the one-release
# ~/.local/bin/novim-dev compatibility link only when absent or already
# pointing into the managed root.
#
# The installer never invokes `novim --update`, never installs Neovim through
# a package manager, never uses sudo, and never touches ~/.local/bin/novim,
# ~/.local/share/novim, or the user's normal Neovim configuration.
#
# Usage:
#   ./install.sh [RELEASE_TAG]        (e.g. v1.0.0; default v1.0.0)
#   curl -fsSL <installer-url> | bash -s -- [RELEASE_TAG]
#
# Local validation overrides (not needed for a normal public install):
#   OHC_INSTALL_ARCHIVE  Install from this local oh-my-code-<VERSION>.tar.gz
#                        instead of downloading; full validation still applies.
#   OHC_RELEASE_URL      Download exactly this archive URL (its .sha256 sibling
#                        is fetched for verification).
#   OHC_RELEASE_REPO     GitHub repository override (default medonmez/oh-my-code).

set -euo pipefail

RELEASE_TAG_DEFAULT="v1.0.0"
INSTALL_ROOT="${HOME}/.local/share/oh-my-code"
BIN_DIR="${HOME}/.local/bin"
MIN_NVIM_VERSION="0.8.0"

TMP_DIR=""
INSTALL_OK=""
CREATED_ROOT=""
CREATED_LINKS=()
MOVED_ITEMS=()

cleanup() {
  if [[ -n "$TMP_DIR" && -d "$TMP_DIR" ]]; then
    rm -rf "$TMP_DIR"
  fi
}

rollback() {
  local item link
  for item in "${MOVED_ITEMS[@]:-}"; do
    if [[ -n "$item" && -e "$item" ]]; then
      rm -rf "$item"
    fi
  done
  if [[ -n "$CREATED_ROOT" && -d "$CREATED_ROOT" ]]; then
    rm -rf "$CREATED_ROOT"
  fi
  for link in "${CREATED_LINKS[@]:-}"; do
    if [[ -n "$link" && -L "$link" ]]; then
      rm -f "$link"
    fi
  done
}

trap 'cleanup; if [[ -z "$INSTALL_OK" ]]; then rollback; fi' EXIT

fail() {
  echo "Error: $*" >&2
  exit 1
}

usage() {
  cat <<'USAGE'
Install oh-my-code from its public GitHub Release asset.

Usage:
  install.sh [RELEASE_TAG]

The installer:
  1. downloads the declared oh-my-code-<VERSION>.tar.gz release asset and its
     .sha256 checksum companion (and nothing else);
  2. verifies the checksum and validates the archive structure fail-closed;
  3. installs only below ~/.local/share/oh-my-code; and
  4. creates ~/.local/bin/ohc and the one-release ~/.local/bin/novim-dev
     compatibility link only when absent or already pointing into the managed
     oh-my-code root.

Existing unrelated files or links are never replaced. Neovim >= 0.8.0 must
already be installed; this installer never installs Neovim, never uses sudo,
and never runs `novim --update`.
USAGE
}

check_neovim() {
  local version major minor micro min_major min_minor min_micro
  if ! command -v nvim >/dev/null 2>&1; then
    fail "Neovim is not installed. Install Neovim ${MIN_NVIM_VERSION}+ first (https://neovim.io/); this installer never installs Neovim or uses sudo."
  fi
  version="$(nvim --version 2>/dev/null | sed -n 's/^NVIM v\([0-9][0-9.]*\).*/\1/p' | head -1)"
  [[ -n "$version" ]] || fail "could not determine the Neovim version."
  IFS='.' read -r major minor micro <<< "$version"
  IFS='.' read -r min_major min_minor min_micro <<< "$MIN_NVIM_VERSION"
  if (( major * 1000000 + ${minor:-0} * 1000 + ${micro:-0} <
        min_major * 1000000 + ${min_minor:-0} * 1000 + ${min_micro:-0} )); then
    fail "Neovim ${version} is too old; oh-my-code requires ${MIN_NVIM_VERSION}+."
  fi
  echo "Neovim ${version} found."
}

fetch_url() {
  local url="$1" output="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL --connect-timeout 15 --retry 2 "$url" -o "$output" ||
      fail "download failed: $url"
  elif command -v wget >/dev/null 2>&1; then
    wget -q "$url" -O "$output" || fail "download failed: $url"
  else
    fail "curl or wget is required to download the release asset."
  fi
}

# checksum_of FILE -> prints the SHA-256 hex digest
checksum_of() {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 "$1" | awk '{print $1}'
  else
    fail "sha256sum or shasum is required to verify the release checksum."
  fi
}

# verify_checksum ARCHIVE CHECKSUM_FILE EXPECTED_BASENAME
verify_checksum() {
  local archive="$1" checksum_file="$2" expected="$3"
  local recorded actual entries
  entries="$(awk -v name="$expected" 'NF >= 2 && $2 == name { n++ } END { print n+0 }' "$checksum_file")"
  if [[ "$entries" -ne 1 ]]; then
    fail "checksum file does not declare exactly one entry for $expected."
  fi
  recorded="$(awk -v name="$expected" 'NF >= 2 && $2 == name { print $1 }' "$checksum_file")"
  if [[ ! "$recorded" =~ ^[0-9a-fA-F]{64}$ ]]; then
    fail "checksum file does not contain a valid SHA-256 digest for $expected."
  fi
  actual="$(checksum_of "$archive" | tr '[:upper:]' '[:lower:]')"
  recorded="$(printf '%s' "$recorded" | tr '[:upper:]' '[:lower:]')"
  if [[ "$actual" != "$recorded" ]]; then
    fail "checksum mismatch for $expected (recorded $recorded, actual $actual)."
  fi
}

# validate_archive ARCHIVE ROOT_NAME MANIFEST
# Shared fail-closed archive contract: one safe root, a strict allowlist, and
# no traversal, links, special files, Git metadata, or private entries.
validate_archive() {
  local archive="$1" expected_root="$2" manifest="$3"
  local first_entry archive_root entry

  if [[ ! -s "$manifest" ]]; then
    fail "release archive is empty: $archive"
  fi

  first_entry="$(sed -n '1p' "$manifest")"
  archive_root="${first_entry%%/*}"
  if [[ -z "$archive_root" || "$archive_root" != "$expected_root" ]]; then
    fail "release archive root is not $expected_root."
  fi

  if grep -Eq '(^|/)\.\.(/|$)' "$manifest"; then
    fail "release archive contains a path traversal entry."
  fi
  if grep -Eq '^/' "$manifest"; then
    fail "release archive contains an absolute-path entry."
  fi
  if grep -qF "\\" "$manifest"; then
    fail "release archive contains a backslash path entry."
  fi

  while IFS= read -r entry; do
    case "$entry" in
      "$expected_root/"|"$expected_root/bin/"|"$expected_root/config/"|\
"$expected_root/bin/ohc"|"$expected_root/bin/novim-dev"|\
"$expected_root/VERSION"|"$expected_root/LICENSE"|\
"$expected_root/THIRD_PARTY_LICENSES.md") ;;
      "$expected_root"/config/nvim|"$expected_root"/config/nvim/*) ;;
      *)
        fail "release archive contains an entry outside the allowlist: $entry"
        ;;
    esac
  done < "$manifest"

  for required in \
    "$expected_root/bin/ohc" \
    "$expected_root/bin/novim-dev" \
    "$expected_root/config/nvim/" \
    "$expected_root/config/nvim/init.lua" \
    "$expected_root/VERSION" \
    "$expected_root/LICENSE" \
    "$expected_root/THIRD_PARTY_LICENSES.md"; do
    if ! grep -Fqx "$required" "$manifest"; then
      fail "release archive is missing required entry: $required"
    fi
  done

  if grep -Fqx "$expected_root/bin/novim" "$manifest"; then
    fail "release archive contains the installed-release launcher."
  fi
  if grep -Eq '(^|/)\.git(/|$)|(^|/)\.dev-[^/]*(/|$)' "$manifest"; then
    fail "release archive contains Git metadata or runtime state."
  fi
  if grep -Eiq '(^|/)(\.env([.]|$)|.*credential.*|.*secret.*|.*\.(pem|key|sqlite|db))(/|$)' "$manifest"; then
    fail "release archive contains a private or credential-like entry."
  fi
  if tar -tvzf "$archive" 2>/dev/null | grep -Eq '^[[:space:]]*[bchlps]'; then
    fail "release archive contains a link or special file."
  fi
}

# root_from_basename ARCHIVE_BASENAME -> sets ROOT_NAME and RELEASE_VERSION
root_from_basename() {
  local basename="$1"
  case "$basename" in
    oh-my-code-*.tar.gz) ;;
    *) fail "archive must be named oh-my-code-<VERSION>.tar.gz: $basename" ;;
  esac
  ROOT_NAME="${basename%.tar.gz}"
  RELEASE_VERSION="${ROOT_NAME#oh-my-code-}"
  if [[ -z "$RELEASE_VERSION" || "$RELEASE_VERSION" == *[!0-9A-Za-z._-]* ]]; then
    fail "archive name has an unsafe version identity: $basename"
  fi
}

# resolve_install_root -> sets RESOLVED_INSTALL_ROOT (physical when possible)
resolve_install_root() {
  local parent
  parent="$(dirname "$INSTALL_ROOT")"
  if [[ -d "$parent" ]]; then
    RESOLVED_INSTALL_ROOT="$(cd "$parent" && pwd -P)/$(basename "$INSTALL_ROOT")"
  else
    RESOLVED_INSTALL_ROOT="$INSTALL_ROOT"
  fi
}

# link_target_abs LINK -> absolute target of a symlink
link_target_abs() {
  local link="$1" target
  target="$(readlink "$link")" || return 1
  case "$target" in
    /*) ;;
    *) target="$(cd "$(dirname "$link")" && pwd -P)/$target" ;;
  esac
  if command -v realpath >/dev/null 2>&1 && realpath "$target" >/dev/null 2>&1; then
    realpath "$target"
  else
    printf '%s\n' "$target"
  fi
}

# ensure_link_state LINK NAME -> dies unless the path is absent or owned
ensure_link_state() {
  local link="$1" name="$2" target
  if [[ -L "$link" ]]; then
    target="$(link_target_abs "$link")" ||
      fail "cannot read the existing $name link: $link"
    if [[ "$target" != "$RESOLVED_INSTALL_ROOT" && "$target" != "$RESOLVED_INSTALL_ROOT"/* &&
          "$target" != "$INSTALL_ROOT" && "$target" != "$INSTALL_ROOT"/* ]]; then
      fail "refusing to touch the existing $name link pointing outside the managed oh-my-code root ($link -> $(readlink "$link"))."
    fi
  elif [[ -e "$link" ]]; then
    fail "refusing to replace the existing unrelated $name path: $link"
  fi
}

create_link() {
  local link="$1" target="$2" name="$3"
  if [[ -L "$link" ]]; then
    echo "Kept existing $name link: $link -> $(readlink "$link")"
    return
  fi
  ln -s "$target" "$link" || fail "could not create the $name link: $link"
  CREATED_LINKS+=("$link")
  echo "Created $name link: $link -> $target"
}

# prepare_install_root verifies the target and records (not creates) the root
prepare_install_root() {
  if [[ -L "$INSTALL_ROOT" ]]; then
    fail "refusing to install through a symlinked root: $INSTALL_ROOT"
  fi
  if [[ -e "$INSTALL_ROOT" && ! -d "$INSTALL_ROOT" ]]; then
    fail "install root is not a directory: $INSTALL_ROOT"
  fi
  if [[ -d "$INSTALL_ROOT" ]]; then
    local entries=()
    shopt -s nullglob dotglob
    entries=("$INSTALL_ROOT"/*)
    shopt -u nullglob dotglob
    if (( ${#entries[@]} > 0 )); then
      fail "install root must be new or empty: $INSTALL_ROOT (this installer does not update in place; remove the root explicitly first if you intend a reinstall)."
    fi
  else
    CREATED_ROOT="$INSTALL_ROOT"
  fi
}

move_payload() {
  local staging_root="$1" item
  if [[ -n "$CREATED_ROOT" ]]; then
    mkdir -p "$(dirname "$INSTALL_ROOT")"
    mv "$staging_root" "$INSTALL_ROOT"
  else
    shopt -s nullglob dotglob
    for item in "$staging_root"/*; do
      mv "$item" "$INSTALL_ROOT/"
      MOVED_ITEMS+=("$INSTALL_ROOT/$(basename "$item")")
    done
    shopt -u nullglob dotglob
  fi
}

main() {
  local arg="${1:-}"
  case "$arg" in
    -h|--help)
      usage
      exit 0
      ;;
    "") ;;
    v*) ;;
    *) usage >&2; fail "release tag must look like v1.0.0 (got: $arg)" ;;
  esac

  local release_tag="${arg:-$RELEASE_TAG_DEFAULT}"
  if [[ ! "$release_tag" =~ ^v[0-9A-Za-z._-]+$ ]]; then
    fail "unsafe release tag: $release_tag"
  fi

  check_neovim
  TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/oh-my-code-install_XXXXXX")"
  local staging_dir="$TMP_DIR/staging"
  local manifest="$TMP_DIR/manifest.txt"
  local staging_root

  if [[ -n "${OHC_INSTALL_ARCHIVE:-}" ]]; then
    # Local-archive validation mode: no download; identical fail-closed checks.
    local local_archive="$OHC_INSTALL_ARCHIVE"
    [[ -f "$local_archive" && ! -L "$local_archive" ]] ||
      fail "local archive is not a regular file: $local_archive"
    ASSET_BASENAME="$(basename "$local_archive")"
    root_from_basename "$ASSET_BASENAME"
    cp "$local_archive" "$TMP_DIR/$ASSET_BASENAME"
    echo "Using local release archive: $local_archive"
  else
    local asset_url
    if [[ -n "${OHC_RELEASE_URL:-}" ]]; then
      asset_url="$OHC_RELEASE_URL"
      root_from_basename "$(basename "$asset_url")"
    else
      local repo="${OHC_RELEASE_REPO:-medonmez/oh-my-code}"
      [[ "$repo" =~ ^[A-Za-z0-9._-]+/[A-Za-z0-9._-]+$ ]] ||
        fail "unsafe repository identity: $repo"
      ASSET_BASENAME="oh-my-code-${release_tag#v}.tar.gz"
      root_from_basename "$ASSET_BASENAME"
      asset_url="https://github.com/$repo/releases/download/$release_tag/$ASSET_BASENAME"
    fi
    ASSET_BASENAME="$(basename "$asset_url")"
    echo "Downloading release asset: $asset_url"
    fetch_url "$asset_url" "$TMP_DIR/$ASSET_BASENAME"
    echo "Downloading checksum asset: $asset_url.sha256"
    fetch_url "$asset_url.sha256" "$TMP_DIR/$ASSET_BASENAME.sha256"
    verify_checksum "$TMP_DIR/$ASSET_BASENAME" "$TMP_DIR/$ASSET_BASENAME.sha256" "$ASSET_BASENAME"
    echo "Checksum verified."
  fi

  tar -tzf "$TMP_DIR/$ASSET_BASENAME" > "$manifest" 2>/dev/null ||
    fail "release archive is unreadable or malformed: $ASSET_BASENAME"
  validate_archive "$TMP_DIR/$ASSET_BASENAME" "$ROOT_NAME" "$manifest"
  echo "Archive validated: single root $ROOT_NAME with the public allowlist only."

  # Extract and verify inside temporary staging before touching the target.
  mkdir -p "$staging_dir"
  tar -xzf "$TMP_DIR/$ASSET_BASENAME" -C "$staging_dir"
  staging_root="$staging_dir/$ROOT_NAME"
  if [[ ! -d "$staging_root" ]]; then
    fail "release archive did not produce the expected root: $ROOT_NAME"
  fi
  if [[ -n "$(find "$staging_dir" -mindepth 1 -maxdepth 1 | grep -Fvx "$staging_dir/$ROOT_NAME" || true)" ]]; then
    fail "release archive extracted unexpected top-level entries."
  fi
  local staged_version
  staged_version="$(tr -d '[:space:]' < "$staging_root/VERSION" 2>/dev/null || true)"
  if [[ "$staged_version" != "$RELEASE_VERSION" ]]; then
    fail "archive VERSION (${staged_version:-missing}) does not match the release identity ($RELEASE_VERSION)."
  fi
  [[ -f "$staging_root/bin/ohc" && -f "$staging_root/bin/novim-dev" ]] ||
    fail "release archive is missing the public launchers."

  resolve_install_root

  if [[ -e "$BIN_DIR" && ! -d "$BIN_DIR" ]]; then
    fail "refusing to use a non-directory command directory: $BIN_DIR"
  fi
  if [[ -L "$BIN_DIR" ]]; then
    fail "refusing to use a symlinked command directory: $BIN_DIR"
  fi

  # Both command paths are checked before either link is created and before
  # the install root is created, so a collision leaves nothing behind.
  ensure_link_state "$BIN_DIR/ohc" "ohc"
  ensure_link_state "$BIN_DIR/novim-dev" "novim-dev"

  prepare_install_root

  move_payload "$staging_root"
  chmod +x "$INSTALL_ROOT/bin/ohc" "$INSTALL_ROOT/bin/novim-dev"

  mkdir -p "$BIN_DIR"
  create_link "$BIN_DIR/ohc" "$INSTALL_ROOT/bin/ohc" "ohc"
  create_link "$BIN_DIR/novim-dev" "$INSTALL_ROOT/bin/novim-dev" "novim-dev"

  echo ""
  echo "oh-my-code $RELEASE_VERSION installed."
  echo "  Install root:   $INSTALL_ROOT"
  echo "  Public command: $BIN_DIR/ohc"
  echo "  Compatibility alias (one release): $BIN_DIR/novim-dev"
  if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
    echo ""
    echo "  Add this to your shell config (.zshrc or .bashrc):"
    echo "    export PATH=\"\$HOME/.local/bin:\$PATH\""
  fi
  echo ""
  echo "  Start with: ohc"
  echo ""
  echo "Untouched by design: ~/.local/bin/novim, ~/.local/share/novim, and your"
  echo "normal Neovim configuration. This installer does not update or uninstall."
  INSTALL_OK=1
}

main "$@"
