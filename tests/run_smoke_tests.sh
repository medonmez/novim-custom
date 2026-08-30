#!/bin/bash
# tests/run_smoke_tests.sh - Run deterministic regression smoke tests for the
# public ohc launcher and the novim-dev one-release compatibility alias.
# Part of the oh-my-code (novim-custom) checkout.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
OHC_LAUNCHER="$PROJECT_ROOT/bin/ohc"
COMPAT_LAUNCHER="$PROJECT_ROOT/bin/novim-dev"

echo "=== oh-my-code Regression Smoke Test Runner ==="
echo "Project root:    $PROJECT_ROOT"
echo "Public launcher: $OHC_LAUNCHER"
echo "Compat launcher: $COMPAT_LAUNCHER"

# Check required binaries
if ! command -v nvim >/dev/null 2>&1; then
  echo "Error: nvim is required but not found in PATH." >&2
  exit 1
fi

if ! command -v git >/dev/null 2>&1; then
  echo "Error: git is required but not found in PATH." >&2
  exit 1
fi

if [[ ! -x "$OHC_LAUNCHER" ]]; then
  echo "Error: Public launcher $OHC_LAUNCHER is not executable." >&2
  exit 1
fi

if [[ ! -x "$COMPAT_LAUNCHER" ]]; then
  echo "Error: Compatibility launcher $COMPAT_LAUNCHER is not executable." >&2
  exit 1
fi

# Create a run-specific temporary fixture root (works cross-platform on macOS and Linux)
RUN_TEMP_ROOT="$(mktemp -d "${TMPDIR:-/tmp}/novim_smoke_run_XXXXXX")"
export NOVIM_SMOKE_TEMP_ROOT="$RUN_TEMP_ROOT"
export NOVIM_PROJECT_ROOT="$PROJECT_ROOT"

CLEANUP_DIRS=("$RUN_TEMP_ROOT")
cleanup() {
  for d in "${CLEANUP_DIRS[@]}"; do
    if [[ -d "$d" ]]; then
      rm -rf "$d"
    fi
  done
}
trap cleanup EXIT

# Snapshot the checksum of every tracked product source file under bin/ and
# config/ before test execution. Step 6 compares against this snapshot so
# only mutations caused by the tests themselves fail the run; uncommitted
# task-branch changes made before the run are legitimate.
PRODUCT_SNAPSHOT="$(cd "$PROJECT_ROOT" && git ls-files -- bin/ config/ | while IFS= read -r path; do
  if [[ -f "$path" ]]; then
    shasum -a 256 "$path"
  fi
done)"

# Checkout base version used by both launcher identities
BASE_VERSION="$(tr -d '[:space:]' < "$PROJECT_ROOT/VERSION")"

echo ""
echo "--- Step 1: Public ohc CLI and Flag Smoke Checks ---"

# 1.1 Test --version
OHC_VERSION_OUT="$("$OHC_LAUNCHER" --version)"
echo "  [CLI] Checking ohc --version output:"
echo "        $OHC_VERSION_OUT"
if [[ "$OHC_VERSION_OUT" != *"oh-my-code"* || "$OHC_VERSION_OUT" != *"ohc"* || "$OHC_VERSION_OUT" != *"$BASE_VERSION-dev"* || "$OHC_VERSION_OUT" != *"powered by NVIM"* ]]; then
  echo "Error: ohc --version output format mismatch." >&2
  exit 1
fi
echo "  ✓ PASS: ohc --version identifies oh-my-code/ohc and preserves checkout version semantics"

# 1.2 Test -v alias
OHC_V_OUT="$("$OHC_LAUNCHER" -v)"
if [[ "$OHC_V_OUT" != "$OHC_VERSION_OUT" ]]; then
  echo "Error: ohc -v output differs from ohc --version." >&2
  exit 1
fi
echo "  ✓ PASS: ohc -v alias matches ohc --version"

# 1.3 Test --help
OHC_HELP_OUT="$("$OHC_LAUNCHER" --help)"
echo "  [CLI] Checking ohc --help output"
if [[ "$OHC_HELP_OUT" != *"Usage: ohc"* || "$OHC_HELP_OUT" != *"oh-my-code"* || "$OHC_HELP_OUT" != *"Configuration root:"* || "$OHC_HELP_OUT" != *"Runtime state:"* || "$OHC_HELP_OUT" != *"novim-dev"* ]]; then
  echo "Error: ohc --help output format mismatch." >&2
  exit 1
fi
echo "  ✓ PASS: ohc --help reports public identity, isolated runtime directories, and alias note"

echo ""
echo "--- Step 2: Compatibility Alias novim-dev CLI Smoke Checks ---"

# 2.1 Test --version keeps checkout semantics and labels the compatibility alias
COMPAT_VERSION_OUT="$("$COMPAT_LAUNCHER" --version)"
echo "  [CLI] Checking novim-dev --version output:"
echo "        $COMPAT_VERSION_OUT"
if [[ "$COMPAT_VERSION_OUT" != *"novim-dev"* || "$COMPAT_VERSION_OUT" != *"-dev (custom checkout)"* || "$COMPAT_VERSION_OUT" != *"one-release compatibility alias"* || "$COMPAT_VERSION_OUT" != *"ohc"* || "$COMPAT_VERSION_OUT" != *"powered by NVIM"* ]]; then
  echo "Error: novim-dev --version output format mismatch." >&2
  exit 1
fi
echo "  ✓ PASS: novim-dev --version keeps checkout version semantics and labels the compatibility alias"

# 2.2 Test -v alias
COMPAT_V_OUT="$("$COMPAT_LAUNCHER" -v)"
if [[ "$COMPAT_V_OUT" != "$COMPAT_VERSION_OUT" ]]; then
  echo "Error: novim-dev -v output differs from novim-dev --version." >&2
  exit 1
fi
echo "  ✓ PASS: novim-dev -v alias matches novim-dev --version"

# 2.3 Test --help
COMPAT_HELP_OUT="$("$COMPAT_LAUNCHER" --help)"
echo "  [CLI] Checking novim-dev --help output"
if [[ "$COMPAT_HELP_OUT" != *"Usage: novim-dev"* || "$COMPAT_HELP_OUT" != *"Configuration root:"* || "$COMPAT_HELP_OUT" != *"Runtime state:"* || "$COMPAT_HELP_OUT" != *"one-release compatibility alias"* ]]; then
  echo "Error: novim-dev --help output format mismatch." >&2
  exit 1
fi
echo "  ✓ PASS: novim-dev --help remains usable and explicitly labels compatibility status"

echo ""
echo "--- Step 3: Working Directory and Symlink Isolation (both commands) ---"

EXTERNAL_TMP="$(mktemp -d "${TMPDIR:-/tmp}/novim_ext_cwd_XXXXXX")"
CLEANUP_DIRS+=("$EXTERNAL_TMP")

# 3.1 ohc from an external working directory (CLI + real headless startup)
EXT_OHC_VERSION="$(cd "$EXTERNAL_TMP" && "$OHC_LAUNCHER" --version)"
if [[ "$EXT_OHC_VERSION" != *"oh-my-code"* ]]; then
  echo "Error: ohc --version lost public identity from an external working directory." >&2
  exit 1
fi

(cd "$EXTERNAL_TMP" && "$OHC_LAUNCHER" --headless -c "lua assert(vim.fs.normalize(vim.fn.stdpath('config')) == vim.fs.normalize('$PROJECT_ROOT/config/nvim'), 'external cwd config path mismatch') assert(vim.fs.normalize(vim.fn.stdpath('data')) == vim.fs.normalize('$PROJECT_ROOT/.dev-data/nvim'), 'external cwd data path mismatch') assert(vim.fs.normalize(vim.fn.stdpath('state')) == vim.fs.normalize('$PROJECT_ROOT/.dev-state/nvim'), 'external cwd state path mismatch') assert(vim.fs.normalize(vim.fn.stdpath('cache')) == vim.fs.normalize('$PROJECT_ROOT/.dev-cache/nvim'), 'external cwd cache path mismatch')" -c "qall!")
echo "  ✓ PASS: ohc resolves the repository root and all isolated runtime paths from an external working directory"

# 3.2 ohc via symlinked launcher (CLI + real headless startup)
SYMLINK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/novim_symlink_XXXXXX")"
CLEANUP_DIRS+=("$SYMLINK_DIR")
ln -s "$OHC_LAUNCHER" "$SYMLINK_DIR/ohc-symlink"

LINK_OHC_VERSION="$("$SYMLINK_DIR/ohc-symlink" --version)"
if [[ "$LINK_OHC_VERSION" != *"oh-my-code"* ]]; then
  echo "Error: symlinked ohc --version lost public identity." >&2
  exit 1
fi

(cd "$EXTERNAL_TMP" && "$SYMLINK_DIR/ohc-symlink" --headless -c "lua assert(vim.fs.normalize(vim.fn.stdpath('config')) == vim.fs.normalize('$PROJECT_ROOT/config/nvim'), 'symlink config path mismatch') assert(vim.fs.normalize(vim.fn.stdpath('state')) == vim.fs.normalize('$PROJECT_ROOT/.dev-state/nvim'), 'symlink state path mismatch')" -c "qall!")
echo "  ✓ PASS: Symlinked ohc resolves the real repository root in CLI and headless startup"

# 3.3 novim-dev keeps its external working directory and symlink behavior
EXT_COMPAT_VERSION="$(cd "$EXTERNAL_TMP" && "$COMPAT_LAUNCHER" --version)"
if [[ "$EXT_COMPAT_VERSION" != *"novim-dev"* ]]; then
  echo "Error: novim-dev --version identity changed from an external working directory." >&2
  exit 1
fi

(cd "$EXTERNAL_TMP" && "$COMPAT_LAUNCHER" --headless -c "lua assert(vim.fs.normalize(vim.fn.stdpath('config')) == vim.fs.normalize('$PROJECT_ROOT/config/nvim'), 'external cwd config path mismatch') assert(vim.fs.normalize(vim.fn.stdpath('data')) == vim.fs.normalize('$PROJECT_ROOT/.dev-data/nvim'), 'external cwd data path mismatch')" -c "qall!")

ln -s "$COMPAT_LAUNCHER" "$SYMLINK_DIR/novim-dev-symlink"
LINK_COMPAT_VERSION="$("$SYMLINK_DIR/novim-dev-symlink" --version)"
if [[ "$LINK_COMPAT_VERSION" != *"novim-dev"* ]]; then
  echo "Error: symlinked novim-dev --version identity changed." >&2
  exit 1
fi

(cd "$EXTERNAL_TMP" && "$SYMLINK_DIR/novim-dev-symlink" --headless -c "lua assert(vim.fs.normalize(vim.fn.stdpath('config')) == vim.fs.normalize('$PROJECT_ROOT/config/nvim'), 'symlink config path mismatch')" -c "qall!")
echo "  ✓ PASS: novim-dev alias keeps external working directory and symlink root resolution"

# 3.4 Installed novim independence check
if [[ -x "/Users/mert/.local/bin/novim" ]]; then
  INSTALLED_VERSION="$(/Users/mert/.local/bin/novim --version 2>&1 || true)"
  echo "  [INFO] Installed novim version: $INSTALLED_VERSION"
  if [[ "$INSTALLED_VERSION" == *"-dev (custom checkout)"* || "$INSTALLED_VERSION" == *"oh-my-code"* ]]; then
    echo "Error: Installed novim was overwritten by a development launcher identity." >&2
    exit 1
  fi
  echo "  ✓ PASS: Installed novim binary remains untouched and independent"
fi

echo ""
echo "--- Step 4: Neovim Argument and File Passthrough (both commands) ---"

PASSTHROUGH_DIR="$(mktemp -d "${TMPDIR:-/tmp}/novim_passthrough_XXXXXX")"
CLEANUP_DIRS+=("$PASSTHROUGH_DIR")
PASSTHROUGH_FILE="$PASSTHROUGH_DIR/passthrough_target.lua"
printf 'return "passthrough"\n' > "$PASSTHROUGH_FILE"

run_passthrough_assert() {
  local launcher="$1" label="$2"
  # Neovim resolves the file argument to its real path, so compare real paths
  # instead of literal strings. A failed assertion must exit non-zero (cquit)
  # because the trailing "qall!" would otherwise mask the failure.
  if ! "$launcher" --headless "$PASSTHROUGH_FILE" \
      -c "lua local ok, err = pcall(function() assert(vim.fn.argc() == 1, 'argc was ' .. vim.fn.argc()) local argv_real = vim.uv.fs_realpath(tostring(vim.fn.argv(0))) local expect_real = vim.uv.fs_realpath('$PASSTHROUGH_FILE') assert(argv_real ~= nil and expect_real ~= nil, 'realpath unavailable') assert(argv_real == expect_real, 'argv was ' .. tostring(vim.fn.argv(0))) end) if not ok then io.stderr:write(tostring(err) .. '\n') vim.cmd('cquit 1') end" \
      -c "qall!"; then
    echo "Error: $label did not pass the fixture file through to Neovim." >&2
    exit 1
  fi
}
run_passthrough_assert "$OHC_LAUNCHER" "ohc"
run_passthrough_assert "$COMPAT_LAUNCHER" "novim-dev"
echo "  ✓ PASS: File arguments and Neovim flags pass through both ohc and novim-dev"

echo ""
echo "--- Step 5: Interactive Splash PTY, Duration, and Script-Safe Bypass Coverage ---"

SPLASH_TAGLINE="oh-my-code | terminal-first code workbench"
# 5.1 --no-animation is consumed by the launchers and never forwarded to Neovim
for PAIR in "$OHC_LAUNCHER:ohc" "$COMPAT_LAUNCHER:novim-dev"; do
  LAUNCHER_PATH="${PAIR%%:*}"
  LAUNCHER_LABEL="${PAIR##*:}"
  if ! "$LAUNCHER_PATH" --no-animation --headless \
      -c "lua local ok, err = pcall(function() assert(not vim.tbl_contains(vim.v.argv, '--no-animation'), 'splash disable flag was forwarded to Neovim') end) if not ok then io.stderr:write(tostring(err) .. '\n') vim.cmd('cquit 1') end" \
      -c "qall!"; then
    echo "Error: $LAUNCHER_LABEL forwarded --no-animation to Neovim." >&2
    exit 1
  fi
done
echo "  ✓ PASS: --no-animation is consumed and never forwarded by ohc and novim-dev"

# 5.2 Help and version launches never render the splash
for PAIR in "$OHC_LAUNCHER:ohc" "$COMPAT_LAUNCHER:novim-dev"; do
  LAUNCHER_PATH="${PAIR%%:*}"
  LAUNCHER_LABEL="${PAIR##*:}"
  for FLAG in --version -v --help -h; do
    if [[ "$("$LAUNCHER_PATH" "$FLAG")" == *"$SPLASH_TAGLINE"* ]]; then
      echo "Error: $LAUNCHER_LABEL $FLAG rendered splash content." >&2
      exit 1
    fi
  done
done
echo "  ✓ PASS: version and help launches for both commands stay splash-free"

# 5.3 Direct PTY matrix: interactive splash rendering, the one-second duration
# bound, and every bypass (flag, env, headless-under-TTY, piped) per launcher.
if command -v python3 >/dev/null 2>&1; then
  if ! python3 - "$OHC_LAUNCHER" "$COMPAT_LAUNCHER" "$BASE_VERSION" "$PROJECT_ROOT" <<'PY'
import fcntl, os, pty, select, shutil, struct, subprocess, sys, tempfile, termios, time

ohc_launcher, compat_launcher, base_version, project_root = sys.argv[1:5]
tagline = "oh-my-code | terminal-first code workbench"
final_marker = "v" + base_version + "-dev"
art_row = "| |_| || | | || |___ "


def fail(msg):
    print("  [SPLASH-FAIL] " + msg, file=sys.stderr)
    sys.exit(1)


def read_pty(cmd, cwd, env=None, keys=b":qa!\r", key_delay=1.5, timeout=30.0):
    master, slave = pty.openpty()
    fcntl.ioctl(slave, termios.TIOCSWINSZ, struct.pack("HHHH", 40, 120, 0, 0))
    proc = subprocess.Popen(cmd, cwd=cwd, stdin=slave, stdout=slave, stderr=slave,
                            env=env, start_new_session=True)
    os.close(slave)
    chunks = []
    start = time.monotonic()
    sent = False
    while True:
        now = time.monotonic()
        if not sent and (now - start) >= key_delay:
            try:
                os.write(master, keys)
            except OSError:
                pass
            sent = True
        if (now - start) > timeout:
            proc.kill()
            proc.wait()
            fail("PTY run timed out: %r" % (cmd,))
        r, _, _ = select.select([master], [], [], 0.05)
        if master in r:
            try:
                data = os.read(master, 65536)
            except OSError:
                break
            if not data:
                break
            chunks.append((time.monotonic() - start, data))
            continue
        if proc.poll() is not None:
            r, _, _ = select.select([master], [], [], 0.2)
            if master in r:
                try:
                    data = os.read(master, 65536)
                except OSError:
                    data = b""
                if data:
                    chunks.append((time.monotonic() - start, data))
            break
    rc = proc.wait()
    end = time.monotonic() - start
    os.close(master)
    return chunks, rc, end


def output(chunks):
    return b"".join(d for _, d in chunks).decode("utf-8", "replace")


def marker_time(chunks, marker):
    acc = b""
    for t, d in chunks:
        acc += d
        if marker.encode() in acc:
            return t
    return None


fixture_root = os.environ.get("NOVIM_SMOKE_TEMP_ROOT") or tempfile.mkdtemp(prefix="splash_pty_")
workdir = tempfile.mkdtemp(prefix="splash_work_", dir=fixture_root)
with open(os.path.join(workdir, "splash_fixture.txt"), "w") as handle:
    handle.write("splash fixture\n")

try:
    for launcher, label in ((ohc_launcher, "ohc"), (compat_launcher, "novim-dev")):
        # Interactive TTY launch: splash renders, is bounded, then Neovim starts.
        chunks, rc, _ = read_pty([launcher], cwd=workdir)
        text = output(chunks)
        if tagline not in text or art_row not in text:
            fail(label + " interactive TTY launch did not render the splash")
        elapsed = marker_time(chunks, final_marker)
        if elapsed is None:
            fail(label + " splash never reached its final frame")
        if not (0.60 <= elapsed <= 1.80):
            fail("%s splash duration %.2fs outside the one-second bound" % (label, elapsed))
        first = chunks[0][0] if chunks else None
        if first is None or first > 0.50:
            fail("%s splash did not start promptly (%.2fs to first output)" % (label, first if first is not None else -1.0))
        if rc != 0:
            fail("%s interactive launch did not exit cleanly (rc=%d)" % (label, rc))

        # --no-animation bypass: no splash frames, no pre-editor wait.
        chunks, rc, _ = read_pty([launcher, "--no-animation"], cwd=workdir, key_delay=0.6)
        text = output(chunks)
        if tagline in text or final_marker in text:
            fail(label + " rendered the splash despite --no-animation")
        first = chunks[0][0] if chunks else None
        if first is None or first > 0.50:
            fail("%s --no-animation launch waited before starting (%.2fs)" % (label, first if first is not None else -1.0))
        if rc != 0:
            fail("%s --no-animation launch did not exit cleanly (rc=%d)" % (label, rc))

        # OHC_NO_ANIMATION=1 bypass under the same PTY conditions.
        env = dict(os.environ, OHC_NO_ANIMATION="1")
        chunks, rc, _ = read_pty([launcher], cwd=workdir, env=env, key_delay=0.6)
        text = output(chunks)
        if tagline in text or final_marker in text:
            fail(label + " rendered the splash despite OHC_NO_ANIMATION=1")
        first = chunks[0][0] if chunks else None
        if first is None or first > 0.50:
            fail("%s OHC_NO_ANIMATION=1 launch waited before starting (%.2fs)" % (label, first if first is not None else -1.0))
        if rc != 0:
            fail("%s OHC_NO_ANIMATION=1 launch did not exit cleanly (rc=%d)" % (label, rc))

        # --headless bypass even when stdout is a real TTY.
        chunks, rc, total = read_pty([launcher, "--headless", "-c", "qall!"], cwd=workdir, keys=b"")
        text = output(chunks)
        if tagline in text or final_marker in text:
            fail(label + " rendered the splash in --headless mode")
        if rc != 0:
            fail("%s --headless launch failed (rc=%d)" % (label, rc))
        if total > 1.00:
            fail("%s --headless launch waited %.2fs for the splash" % (label, total))

        # Piped (non-TTY) launch bypasses the splash without waiting.
        start = time.monotonic()
        completed = subprocess.run([launcher, "-es"], input=b"qa!\n", cwd=workdir,
                                   stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=30)
        elapsed = time.monotonic() - start
        text = completed.stdout.decode("utf-8", "replace")
        if tagline in text or final_marker in text:
            fail(label + " rendered the splash in piped (non-TTY) mode")
        if completed.returncode != 0:
            fail("%s piped launch failed (rc=%d): %s" % (label, completed.returncode, text[:200]))
        if elapsed > 1.00:
            fail("%s piped launch waited %.2fs for the splash" % (label, elapsed))
finally:
    shutil.rmtree(workdir, ignore_errors=True)

print("  [SPLASH] interactive splash, duration bound, and all bypass controls verified")
sys.exit(0)
PY
  then
    echo "Error: Splash PTY coverage failed." >&2
    exit 1
  fi
  echo "  ✓ PASS: PTY splash rendering, ~1s duration bound, and flag/env/headless/piped bypasses verified for both commands"
else
  echo "  [WARN] python3 not available; PTY splash matrix skipped (run direct PTY checks manually)"
fi

echo ""
echo "--- Step 6: Headless Neovim Regression Smoke Suite (public ohc startup) ---"
# Note: uses the public launcher's normal startup path (loads checkout config automatically, without -u)
"$OHC_LAUNCHER" --headless -c "luafile $PROJECT_ROOT/tests/test_smoke.lua"
echo "  ✓ PASS: All headless regression smoke tests passed under the public ohc launcher"

echo ""
echo "--- Step 7: Post-Run Artifact and Cleanup Verification ---"

# Verify no leftover test fixtures in the run-specific temp root
LEFTOVER_COUNT=0
if [[ -d "$RUN_TEMP_ROOT" ]]; then
  shopt -s nullglob dotglob
  LEFTOVER_ENTRIES=("$RUN_TEMP_ROOT"/*)
  shopt -u nullglob dotglob
  LEFTOVER_COUNT=${#LEFTOVER_ENTRIES[@]}
  if [[ "$LEFTOVER_COUNT" -gt 0 ]]; then
    echo "Error: Detected uncleaned smoke fixture(s) in $RUN_TEMP_ROOT:" >&2
    for entry in "${LEFTOVER_ENTRIES[@]}"; do
      echo "  - $entry" >&2
    done
    exit 1
  fi
fi
echo "  ✓ PASS: Zero fixture residue left in run temporary root ($RUN_TEMP_ROOT)"

# Verify tracked product source files were not modified by test execution:
# compare current checksums against the snapshot taken before the run. A task
# branch may legitimately contain uncommitted product changes made before the
# run; only changes made DURING the run fail this check.
PRODUCT_SNAPSHOT_END="$(cd "$PROJECT_ROOT" && git ls-files -- bin/ config/ | while IFS= read -r path; do
  if [[ -f "$path" ]]; then
    shasum -a 256 "$path"
  fi
done)"
if [[ "$PRODUCT_SNAPSHOT_END" != "$PRODUCT_SNAPSHOT" ]]; then
  echo "Error: Product code in bin/ or config/ was modified during the test run:" >&2
  diff <(echo "$PRODUCT_SNAPSHOT") <(echo "$PRODUCT_SNAPSHOT_END") >&2 || true
  exit 1
fi
echo "  ✓ PASS: Product source tree remains clean"
