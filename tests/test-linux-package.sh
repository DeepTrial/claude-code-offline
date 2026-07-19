#!/usr/bin/env bash
# =============================================================================
# Linux offline package end-to-end test
# =============================================================================
# Verifies the built claude-offline-packages directory:
#   1. Structure: real native binary (>100MB), real (non-symlink) .bin launcher
#   2. node_modules/.bin/claude --version prints the expected version
#   3. Clean-room install in a node-less ubuntu:22.04 container:
#      bash setup-claude-code.sh --offline-path <pkg> --yes must succeed and
#      `claude --version` must work afterwards (fake HOME, no Node.js).
#
# Usage: bash tests/test-linux-package.sh <package_dir> <expected_version>
# =============================================================================

set -euo pipefail

PKG_DIR="${1:?Usage: $0 <package_dir> <expected_version>}"
EXPECTED_VERSION="${2:?Usage: $0 <package_dir> <expected_version>}"

info() { echo "[INFO] $*"; }
ok()   { echo "  [OK] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

PKG_DIR="$(cd "$PKG_DIR" && pwd)"

echo "======================================================================"
echo "  Linux package test"
echo "  Package: $PKG_DIR"
echo "  Expect:  v$EXPECTED_VERSION"
echo "======================================================================"

# ---------------------------------------------------------------------------
# 1. Structure assertions
# ---------------------------------------------------------------------------
info "Checking package structure..."

MAIN_BIN="$PKG_DIR/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
[ -f "$MAIN_BIN" ] || fail "bin/claude.exe is missing"
BIN_SIZE=$(stat -c%s "$MAIN_BIN" 2>/dev/null || echo 0)
[ "$BIN_SIZE" -gt 104857600 ] || fail "bin/claude.exe is only $BIN_SIZE bytes (<= 100MB) - looks like a stub"
ok "bin/claude.exe is a real binary ($BIN_SIZE bytes)"

LAUNCHER="$PKG_DIR/node_modules/.bin/claude"
[ -e "$LAUNCHER" ] || fail ".bin/claude launcher is missing"
[ -x "$LAUNCHER" ] || fail ".bin/claude is not executable"
[ ! -L "$LAUNCHER" ] || fail ".bin/claude is a symlink (must be a real launcher script)"
ok ".bin/claude is a real, executable launcher script (not a symlink)"

[ -f "$PKG_DIR/setup-claude-code.sh" ] || fail "setup-claude-code.sh is missing"
ok "setup-claude-code.sh present"

# ---------------------------------------------------------------------------
# 2. Direct version check
# ---------------------------------------------------------------------------
info "Running node_modules/.bin/claude --version ..."
VERSION_OUT="$("$LAUNCHER" --version 2>&1)" || fail "claude --version failed: $VERSION_OUT"
echo "    output: $VERSION_OUT"
echo "$VERSION_OUT" | grep -q "$EXPECTED_VERSION" \
    || fail "version output does not contain expected version $EXPECTED_VERSION"
ok "version check passed"

# ---------------------------------------------------------------------------
# 3. Clean-room install test (docker, no Node.js, fake HOME)
# ---------------------------------------------------------------------------
if command -v docker >/dev/null 2>&1; then
    info "Running clean-room install test in ubuntu:22.04 (no Node.js, fake HOME)..."
    # The container's unprivileged user must be able to rewrite the launcher
    chmod -R a+rwX "$PKG_DIR" 2>/dev/null || true
    docker run --rm \
        -v "$PKG_DIR:/pkg" \
        -e EXPECTED_VERSION="$EXPECTED_VERSION" \
        ubuntu:22.04 bash -c '
            set -e
            export DEBIAN_FRONTEND=noninteractive
            apt-get update -qq
            apt-get install -y -qq bash curl tar >/dev/null
            useradd -m tester
            mkdir -p /tmp/fakehome && chown tester:tester /tmp/fakehome

            if ! su tester -c "HOME=/tmp/fakehome bash /pkg/setup-claude-code.sh --offline-path /pkg --yes < /dev/null" > /tmp/install.log 2>&1; then
                echo "[FAIL] setup-claude-code.sh exited non-zero. Last log lines:"
                tail -40 /tmp/install.log
                exit 1
            fi
            echo "  [OK] setup-claude-code.sh --yes completed (exit 0, no Node.js present)"

            VER=$(su tester -c "HOME=/tmp/fakehome bash -c \"source ~/.bashrc && claude --version\"")
            echo "    claude --version: $VER"
            echo "$VER" | grep -q "$EXPECTED_VERSION" || { echo "[FAIL] unexpected version output"; exit 1; }
        ' || fail "docker clean-room install test failed"
    ok "clean-room install + claude --version passed (Node.js was NOT installed)"
else
    info "docker not available; skipping clean-room container test"
fi

echo ""
echo "ALL LINUX PACKAGE TESTS PASSED"
