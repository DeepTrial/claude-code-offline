#!/usr/bin/env bash
# =============================================================================
# Offline upgrade flow end-to-end test
# =============================================================================
# Builds two fake offline packages (v1 -> v2) with a stub claude binary and a
# stub setup script, then verifies:
#   1. update-offline.sh upgrades the package in place (PATH block untouched)
#   2. previously installed skills are updated from the new bundle
#   3. a backup is created and --rollback restores the old version
#
# Usage: bash tests/test-update-offline.sh
# Requires: bash, tar, jq (system jq)
# =============================================================================

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

info() { echo "[INFO] $*"; }
ok()   { echo "  [OK] $*"; }
fail() { echo "[FAIL] $*" >&2; exit 1; }

command -v jq  >/dev/null 2>&1 || fail "jq is required for this test"
command -v tar >/dev/null 2>&1 || fail "tar is required for this test"

WORK=$(mktemp -d)
trap 'rm -rf "$WORK"' EXIT
FAKE_HOME="$WORK/home"
mkdir -p "$FAKE_HOME"
touch "$FAKE_HOME/.bashrc"

# ---------------------------------------------------------------------------
# Fake package factory:  make_pkg <dir> <version> <skill_a_content>
# ---------------------------------------------------------------------------
make_pkg() {
    local dir="$1" version="$2" skill_a_content="$3"
    mkdir -p "$dir/node_modules/@anthropic-ai/claude-code/bin" \
             "$dir/node_modules/.bin" \
             "$dir/skills/offline-skills/skill-a" \
             "$dir/skills/offline-skills/skill-b" \
             "$dir/skills/bin"

    # Stub native binary: prints the package version
    cat > "$dir/node_modules/@anthropic-ai/claude-code/bin/claude.exe" << EOF
#!/usr/bin/env bash
echo "$version (stub)"
EOF
    chmod +x "$dir/node_modules/@anthropic-ai/claude-code/bin/claude.exe"

    cat > "$dir/node_modules/.bin/claude" << 'LAUNCHER'
#!/usr/bin/env bash
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$SELF_DIR/../@anthropic-ai/claude-code/bin/claude.exe" "$@"
LAUNCHER
    chmod +x "$dir/node_modules/.bin/claude"

    # Stub setup script: only maintains the PATH block in ~/.bashrc,
    # mirroring the real setup-claude-code.sh marker format.
    cat > "$dir/setup-claude-code.sh" << 'STUBSETUP'
#!/usr/bin/env bash
set -euo pipefail
PKG=""
while [[ $# -gt 0 ]]; do
    case "$1" in
        --offline-path) PKG="$2"; shift 2 ;;
        *) shift ;;
    esac
done
[ -n "$PKG" ] || { echo "stub setup: --offline-path required" >&2; exit 1; }
BASHRC="$HOME/.bashrc"
touch "$BASHRC"
sed -i '/# >>> CLAUDE_CODE_SETUP >>>/,/# <<< CLAUDE_CODE_SETUP <<</d' "$BASHRC" 2>/dev/null || true
cat >> "$BASHRC" << BLOCK

# >>> CLAUDE_CODE_SETUP >>>
export PATH="$PKG/node_modules/.bin:\$PATH"
# <<< CLAUDE_CODE_SETUP <<<
BLOCK
echo "stub setup done for $PKG"
STUBSETUP
    chmod +x "$dir/setup-claude-code.sh"

    cat > "$dir/package-info.json" << EOF
{"name": "claude-offline-packages", "version": "$version"}
EOF

    # Skills bundle: real installer + manifest + two test skills
    cp "$REPO_ROOT/skills/install-skills.sh" "$dir/skills/"
    cp "$REPO_ROOT/update-offline.sh" "$dir/"
    chmod +x "$dir/skills/install-skills.sh" "$dir/update-offline.sh"
    cat > "$dir/skills/offline-skills/skills-manifest.json" << 'MANIFEST'
{
  "version": "1.0.0",
  "skills": {
    "skill-a": {"name": "skill-a", "description": "test skill A", "category": "tool", "offline_compatible": true},
    "skill-b": {"name": "skill-b", "description": "test skill B", "category": "tool", "offline_compatible": true}
  }
}
MANIFEST
    echo "$skill_a_content" > "$dir/skills/offline-skills/skill-a/SKILL.md"
    echo "skill-b content"      > "$dir/skills/offline-skills/skill-b/SKILL.md"
}

echo "======================================================================"
echo "  Offline upgrade flow test"
echo "======================================================================"

# ---------------------------------------------------------------------------
# 1. "Install" v1 + one skill
# ---------------------------------------------------------------------------
info "Building fake packages (v1.0.0 / v2.0.0)..."
PKG_V1_SRC="$WORK/pkg-v1"
PKG_V2_SRC="$WORK/pkg-v2"
make_pkg "$PKG_V1_SRC" "1.0.0" "skill-a v1"
make_pkg "$PKG_V2_SRC" "2.0.0" "skill-a v2 UPDATED"

INSTALL_DIR="$WORK/target/claude-offline-packages"
mkdir -p "$WORK/target"
cp -a "$PKG_V1_SRC" "$INSTALL_DIR"

export HOME="$FAKE_HOME"

bash "$INSTALL_DIR/setup-claude-code.sh" --offline-path "$INSTALL_DIR" >/dev/null
[ -f "$FAKE_HOME/.bashrc" ] || fail "stub setup did not write ~/.bashrc"
grep -q "$INSTALL_DIR/node_modules/.bin" "$FAKE_HOME/.bashrc" \
    || fail "PATH block missing from ~/.bashrc"
ok "v1 installed at $INSTALL_DIR"

bash "$INSTALL_DIR/skills/install-skills.sh" "$INSTALL_DIR/skills/offline-skills" --only skill-a --yes >/dev/null
[ -f "$FAKE_HOME/.claude/skills/skill-a/SKILL.md" ] || fail "skill-a was not installed"
grep -q "skill-a v1" "$FAKE_HOME/.claude/skills/skill-a/SKILL.md" || fail "skill-a v1 content wrong"
[ -f "$FAKE_HOME/.claude/skills-installed.json" ] || fail "state file not created"
jq -e '.entries["skill-a"]' "$FAKE_HOME/.claude/skills-installed.json" >/dev/null \
    || fail "state file missing skill-a entry"
ok "skill-a installed and recorded in state file"

# --list shows install status
LIST_OUT=$(bash "$INSTALL_DIR/skills/install-skills.sh" "$INSTALL_DIR/skills/offline-skills" --list)
echo "$LIST_OUT" | grep -q "skill-a.*installed" || fail "--list does not mark skill-a as installed"
echo "$LIST_OUT" | grep -q "skill-b.*available" || fail "--list does not mark skill-b as available"
ok "--list reports installed/available correctly"

# ---------------------------------------------------------------------------
# 2. Upgrade to v2 (directory input)
# ---------------------------------------------------------------------------
info "Upgrading to v2..."
bash "$INSTALL_DIR/update-offline.sh" "$PKG_V2_SRC" --yes \
    || fail "update-offline.sh exited non-zero"

# Version swapped
NEW_VER=$(jq -r .version "$INSTALL_DIR/package-info.json")
[ "$NEW_VER" = "2.0.0" ] || fail "package-info.json version is $NEW_VER, expected 2.0.0"
ok "package upgraded in place (version 2.0.0)"

# PATH block still points at the same directory
grep -q "$INSTALL_DIR/node_modules/.bin" "$FAKE_HOME/.bashrc" \
    || fail "PATH block no longer points at the install dir after upgrade"
[ "$(grep -c 'CLAUDE_CODE_SETUP' "$FAKE_HOME/.bashrc")" -eq 2 ] \
    || fail "PATH block duplicated in ~/.bashrc"
ok "~/.bashrc PATH block unchanged (no duplicates)"

# Previously installed skill got updated; unselected skill NOT installed
grep -q "skill-a v2 UPDATED" "$FAKE_HOME/.claude/skills/skill-a/SKILL.md" \
    || fail "skill-a was not updated from the new bundle"
[ ! -d "$FAKE_HOME/.claude/skills/skill-b" ] || fail "skill-b should NOT have been installed by --update"
ok "installed skills updated, unselected skills untouched"

# New binary stub reports the new version through the launcher
VER_OUT=$("$INSTALL_DIR/node_modules/.bin/claude" --version)
echo "$VER_OUT" | grep -q "2.0.0" || fail "launcher reports wrong version: $VER_OUT"
ok "claude launcher reports v2.0.0"

# Backup exists
BACKUP=$(ls -1dt "$FAKE_HOME/.claude/backups"/claude-offline-packages-* 2>/dev/null | head -1 || true)
[ -n "$BACKUP" ] || fail "no backup was created"
[ "$(jq -r .version "$BACKUP/package-info.json")" = "1.0.0" ] || fail "backup has wrong version"
ok "backup of v1 created: $(basename "$BACKUP")"

# ---------------------------------------------------------------------------
# 3. Upgrade again from a .tar.gz (archive input path)
# ---------------------------------------------------------------------------
info "Building v3 archive and upgrading from tar.gz..."
PKG_V3_SRC="$WORK/pkg-v3"
make_pkg "$PKG_V3_SRC" "3.0.0" "skill-a v3"
mkdir -p "$WORK/dist"
tar -czf "$WORK/dist/claude-offline-packages-linux.tar.gz" -C "$WORK" pkg-v3
# The archive top dir is pkg-v3, not claude-offline-packages*: rename inside
STAGE=$(mktemp -d)
mkdir -p "$STAGE/claude-offline-packages"
cp -a "$PKG_V3_SRC/." "$STAGE/claude-offline-packages/"
tar -czf "$WORK/dist/claude-offline-packages-linux.tar.gz" -C "$STAGE" claude-offline-packages
rm -rf "$STAGE"
( cd "$WORK/dist" && sha256sum claude-offline-packages-linux.tar.gz > claude-offline-packages-linux.tar.gz.sha256 )

bash "$INSTALL_DIR/update-offline.sh" "$WORK/dist/claude-offline-packages-linux.tar.gz" --yes >/dev/null \
    || fail "archive upgrade exited non-zero"
[ "$(jq -r .version "$INSTALL_DIR/package-info.json")" = "3.0.0" ] \
    || fail "archive upgrade did not reach v3.0.0"
grep -q "skill-a v3" "$FAKE_HOME/.claude/skills/skill-a/SKILL.md" \
    || fail "skill-a not updated to v3"
ok "upgrade from .tar.gz archive (with checksum) works"

# ---------------------------------------------------------------------------
# 4. Rollback to the previous backup (v2.0.0)
# ---------------------------------------------------------------------------
info "Rolling back..."
bash "$INSTALL_DIR/update-offline.sh" --rollback --yes \
    || fail "rollback exited non-zero"
[ "$(jq -r .version "$INSTALL_DIR/package-info.json")" = "2.0.0" ] \
    || fail "rollback did not restore v2.0.0"
grep -q "$INSTALL_DIR/node_modules/.bin" "$FAKE_HOME/.bashrc" \
    || fail "PATH block broken after rollback"
ok "rollback restored v2.0.0"

# Corrupted archive must be rejected by checksum verification
info "Verifying corrupted-archive rejection..."
cp "$WORK/dist/claude-offline-packages-linux.tar.gz" "$WORK/dist/corrupt.tar.gz"
cp "$WORK/dist/claude-offline-packages-linux.tar.gz.sha256" "$WORK/dist/corrupt.tar.gz.sha256"
sed -i 's/claude-offline-packages-linux.tar.gz/corrupt.tar.gz/' "$WORK/dist/corrupt.tar.gz.sha256"
echo "garbage" >> "$WORK/dist/corrupt.tar.gz"
if bash "$INSTALL_DIR/update-offline.sh" "$WORK/dist/corrupt.tar.gz" --yes >/dev/null 2>&1; then
    fail "corrupted archive was NOT rejected"
fi
[ "$(jq -r .version "$INSTALL_DIR/package-info.json")" = "2.0.0" ] \
    || fail "installation changed despite failed checksum"
ok "corrupted archive rejected by checksum verification"

echo ""
echo "ALL OFFLINE UPGRADE FLOW TESTS PASSED"
