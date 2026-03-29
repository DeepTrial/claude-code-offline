#!/usr/bin/env bash
# =============================================================================
# Claude Code One-Click Deployment Script for Offline Ubuntu System
# =============================================================================
# Purpose: Set up Claude Code for a team member using shared offline packages.
#          Each user provides their own API key and base URL.
#
# Usage:   bash /home/xingchencong/pub/setup-claude-code.sh
#
# Author:  DeepTrial
# Version: 1.0
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# 1. Banner & Safety Checks
# ---------------------------------------------------------------------------
echo "============================================================================="
echo "  Claude Code Deployment Script"
echo "============================================================================="
echo ""
echo "*** Only for Offline Ubuntu System ***"
echo "This script will set up Claude Code on your account using shared offline"
echo "packages. You will need to provide your own API key and base URL after"
echo "setup is complete."
echo ""

# Exit if running as root
if [ "$(id -u)" -eq 0 ]; then
    echo "ERROR: Do not run this script as root. Run it as your own user account."
    exit 1
fi

# Verify shared packages are readable
OFFLINE_PACKAGES="/home/xingchencong/pub/claude-offline-packages"
OFFLINE_BIN="$OFFLINE_PACKAGES/node_modules/.bin"
CLAUDE_BIN="$OFFLINE_BIN/claude"

if [ ! -r "$CLAUDE_BIN" ]; then
    echo "ERROR: Cannot read shared Claude Code packages at:"
    echo "  $CLAUDE_BIN"
    echo ""
    echo "Please Download the offline packages to /home/xingchencong/pub/claude-offline-packages and ensure permissions are correct."
    exit 1
fi

echo "[OK] Shared packages are accessible."
echo ""

# ---------------------------------------------------------------------------
# 2. Set Variables
# ---------------------------------------------------------------------------
USER_CLAUDE_DIR="$HOME/.claude"
USER_TMPDIR="$HOME/.claude/tmp"
BASHRC="$HOME/.bashrc"
MODULE_BASE_SH="/pub/tools/swtool/env/base.sh"
MODULE_LOAD_CMD="module load node/25.2.1"

# Sentinel markers for shell config
SETUP_START="# >>> CLAUDE_CODE_SETUP >>>"
SETUP_END="# <<< CLAUDE_CODE_SETUP <<<"
NODE_START="# >>> CLAUDE_CODE_NODE >>>"
NODE_END="# <<< CLAUDE_CODE_NODE <<<"

# ---------------------------------------------------------------------------
# 3. Ensure Node.js via Module System
# ---------------------------------------------------------------------------
echo "Step 1/7: Ensuring Node.js is available via module system..."

# Check if .bashrc already has both required entries
HAS_BASE_SH=false
HAS_MODULE_LOAD=false

if [ -f "$BASHRC" ]; then
    if grep -q "source /pub/tools/swtool/env/base.sh" "$BASHRC" 2>/dev/null; then
        HAS_BASE_SH=true
    fi
    if grep -q "module load node/25.2.1" "$BASHRC" 2>/dev/null; then
        HAS_MODULE_LOAD=true
    fi
fi

if [ "$HAS_BASE_SH" = true ] && [ "$HAS_MODULE_LOAD" = true ]; then
    echo "  Node.js module setup already present in .bashrc."
else
    echo "  Adding Node.js module setup to .bashrc..."
    touch "$BASHRC"

    # Check if our sentinel block already exists (partial setup)
    if grep -q "$NODE_START" "$BASHRC" 2>/dev/null; then
        echo "  Sentinel block found but incomplete. Replacing..."
        # Remove old block
        sed -i "/$NODE_START/,/$NODE_END/d" "$BASHRC"
    fi

    # Append the module setup block
    cat >> "$BASHRC" <<'NODEBLOCK'

# >>> CLAUDE_CODE_NODE >>>
# Claude Code Node.js setup (added by setup-claude-code.sh)
source /pub/tools/swtool/env/base.sh
module load node/25.2.1
# <<< CLAUDE_CODE_NODE <<<
NODEBLOCK

    echo "  Node.js module setup added to .bashrc."
fi

# Load Node.js for current session
echo "  Loading Node.js for current session..."
if [ -f "$MODULE_BASE_SH" ]; then
    source "$MODULE_BASE_SH"
else
    echo "ERROR: Cannot find $MODULE_BASE_SH"
    exit 1
fi

if command -v module >/dev/null 2>&1; then
    module load node/25.2.1 2>/dev/null || true
else
    echo "ERROR: 'module' command not available after sourcing base.sh."
    exit 1
fi

# Verify Node.js version >= 18
if ! command -v node >/dev/null 2>&1; then
    echo "ERROR: Node.js not found after loading module. Setup failed."
    exit 1
fi

NODE_VERSION=$(node --version | sed 's/v//')
NODE_MAJOR=$(echo "$NODE_VERSION" | cut -d. -f1)
if [ "$NODE_MAJOR" -lt 18 ]; then
    echo "ERROR: Node.js version $NODE_VERSION is too old. Need >= 18."
    exit 1
fi

echo "  [OK] Node.js $NODE_VERSION is available."
echo ""

# ---------------------------------------------------------------------------
# 4. Create Directory Structure
# ---------------------------------------------------------------------------
echo "Step 2/7: Creating ~/.claude/ directory structure..."

mkdir -p "$USER_CLAUDE_DIR"
mkdir -p "$USER_CLAUDE_DIR/tmp"
mkdir -p "$USER_CLAUDE_DIR/backups"
mkdir -p "$USER_CLAUDE_DIR/plugins"

echo "  [OK] Directories created."
echo ""

# ---------------------------------------------------------------------------
# 5. Generate Config Files (with placeholders, NO shared credentials)
# ---------------------------------------------------------------------------
echo "Step 3/7: Generating configuration files..."

# --- settings.json ---
SETTINGS_FILE="$USER_CLAUDE_DIR/settings.json"
if [ -f "$SETTINGS_FILE" ]; then
    BACKUP_NAME="settings.json.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$SETTINGS_FILE" "$USER_CLAUDE_DIR/backups/$BACKUP_NAME"
    echo "  [SKIP] settings.json already exists. Backed up to backups/$BACKUP_NAME"
else
    cat > "$SETTINGS_FILE" <<'SETTINGSJSON'
{
  "env": {
    "ANTHROPIC_BASE_URL": "YOUR_BASE_URL_HERE",
    "ANTHROPIC_API_KEY": "YOUR_API_KEY_HERE",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "YOUR_MODEL_HERE",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "YOUR_MODEL_HERE",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "YOUR_MODEL_HERE",
    "DISABLE_AUTOUPDATER": "1",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1"
  },
  "autoUpdate": { "enabled": false }
}
SETTINGSJSON
    echo "  [OK] Created settings.json with placeholder values."
fi

# --- config.json ---
CONFIG_FILE="$USER_CLAUDE_DIR/config.json"
if [ -f "$CONFIG_FILE" ]; then
    echo "  [SKIP] config.json already exists."
else
    cat > "$CONFIG_FILE" <<'CONFIGJSON'
{ "primaryApiKey": "mimo" }
CONFIGJSON
    echo "  [OK] Created config.json."
fi

# --- .claude.json ---
CLAUDE_JSON="$HOME/.claude.json"
FIRST_START=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

if [ -f "$CLAUDE_JSON" ]; then
    # Ensure hasCompletedOnboarding: true, preserve other fields
    BACKUP_NAME=".claude.json.backup.$(date +%Y%m%d_%H%M%S)"
    cp "$CLAUDE_JSON" "$USER_CLAUDE_DIR/backups/$BACKUP_NAME"

    if command -v python3 >/dev/null 2>&1; then
        python3 -c "
import json, sys
with open('$CLAUDE_JSON', 'r') as f:
    data = json.load(f)
data['hasCompletedOnboarding'] = True
with open('$CLAUDE_JSON', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true
    elif command -v jq >/dev/null 2>&1; then
        jq '.hasCompletedOnboarding = true' "$CLAUDE_JSON" > "$CLAUDE_JSON.tmp" && mv "$CLAUDE_JSON.tmp" "$CLAUDE_JSON" 2>/dev/null || true
    fi
    echo "  [OK] Updated .claude.json (hasCompletedOnboarding: true). Backed up to backups/$BACKUP_NAME."
else
    cat > "$CLAUDE_JSON" <<CLAUDEJSON
{
  "hasCompletedOnboarding": true,
  "firstStartTime": "$FIRST_START"
}
CLAUDEJSON
    echo "  [OK] Created .claude.json."
fi

echo ""

# ---------------------------------------------------------------------------
# 6. Update Shell Config (PATH + TMPDIR)
# ---------------------------------------------------------------------------
echo "Step 4/7: Updating shell configuration (PATH + TMPDIR)..."

touch "$BASHRC"

if grep -q "$SETUP_START" "$BASHRC" 2>/dev/null; then
    echo "  [SKIP] PATH/TMPDIR block already present in .bashrc."
else
    cat >> "$BASHRC" <<SETUPBLOCK

# >>> CLAUDE_CODE_SETUP >>>
# Claude Code shared offline packages (added by setup-claude-code.sh)
export PATH="/home/xingchencong/pub/claude-offline-packages/node_modules/.bin:\$PATH"
export TMPDIR="\$HOME/.claude/tmp"
# Claude Code setup - do not edit above this marker
# <<< CLAUDE_CODE_SETUP <<<
SETUPBLOCK
    echo "  [OK] PATH and TMPDIR exports added to .bashrc."
fi

echo ""

# ---------------------------------------------------------------------------
# 7. Verification & Summary
# ---------------------------------------------------------------------------
echo "Step 5/7: Verifying setup..."

# Export PATH for current session
export PATH="/home/xingchencong/pub/claude-offline-packages/node_modules/.bin:$PATH"
export TMPDIR="$HOME/.claude/tmp"

# Verify claude command works
if command -v claude >/dev/null 2>&1; then
    CLAUDE_VER=$(claude --version 2>/dev/null || echo "(version check failed)")
    echo "  [OK] claude command available: $CLAUDE_VER"
else
    echo "  [WARN] claude command not found in PATH yet. You may need to open a new terminal."
fi

# Verify config files
echo ""
echo "Step 6/7: Checking configuration files..."
for f in "$SETTINGS_FILE" "$CONFIG_FILE" "$CLAUDE_JSON"; do
    if [ -f "$f" ]; then
        echo "  [OK] $(basename "$f") exists"
    else
        echo "  [MISSING] $(basename "$f")"
    fi
done

echo ""
echo "Step 7/7: Setup complete!"
echo ""
echo "============================================================================="
echo "  SETUP SUMMARY"
echo "============================================================================="
echo ""
echo "  Configured:"
echo "    - Node.js module system in .bashrc"
echo "    - ~/.claude/ directory structure"
echo "    - ~/.claude/settings.json (with placeholder values)"
echo "    - ~/.claude/config.json"
echo "    - ~/.claude.json (onboarding complete)"
echo "    - PATH and TMPDIR in .bashrc"
echo ""
echo "============================================================================="
echo "  !!! ACTION REQUIRED !!!"
echo "============================================================================="
echo ""
echo "  You MUST edit your settings.json to add your own credentials:"
echo ""
echo "    nano ~/.claude/settings.json"
echo ""
echo "  Replace these placeholder values with your actual API key and base URL:"
echo ""
echo "    \"ANTHROPIC_BASE_URL\": \"YOUR_BASE_URL_HERE\"   -> your actual base URL"
echo "    \"ANTHROPIC_API_KEY\": \"YOUR_API_KEY_HERE\"     -> your actual API key"
echo ""
echo "  DO NOT use anyone else's credentials. Each user must have their own."
echo ""
echo "============================================================================="
echo "  NEXT STEPS"
echo "============================================================================="
echo ""
echo "  1. Edit ~/.claude/settings.json with your API key and base URL"
echo "  2. Open a new terminal (or run: source ~/.bashrc)"
echo "  3. Verify: claude --version"
echo "  4. Verify: echo \$TMPDIR  (should show ~/.claude/tmp)"
echo "  5. (Optional) Install cc extension manually :"
echo "      -- /home/xingchencong/pub/anthropic.claude-code-2.1.74-linux-x64.vsix"
echo ""
echo "============================================================================="
echo "  TMP DIRECTORY CLEANUP"
echo "============================================================================="
echo ""
echo "  Claude Code uses ~/.claude/tmp as its temporary directory (TMPDIR)."
echo "  This directory is NOT automatically cleaned by the system."
echo "  To manually check and clean it, run:"
echo ""
echo "    bash ~/.claude/clean-tmp.sh"
echo ""
echo "  The script will:"
echo "    - Detect and report the current size of ~/.claude/tmp"
echo "    - Let you choose whether to clean"
echo "    - Offer three cleanup options:"
echo "        1) Clean items older than 7 days"
echo "        2) Clean items older than 3 days"
echo "        3) Clean everything"
echo "    - Require a final confirmation before deleting anything"
echo ""
echo "  Recommended: Run this periodically to reclaim disk space."
echo ""
echo "============================================================================="
echo "  To re-run this script safely (idempotent):"
echo "    bash /home/xingchencong/pub/setup-claude-code.sh"
echo ""
echo "============================================================================="