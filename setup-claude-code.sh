#!/usr/bin/env bash
# =============================================================================
# Claude Code One-Click Deployment Script for Offline/Online System
# =============================================================================
# Purpose: Set up Claude Code for a team member using offline packages or
#          automatic download with automatic mirror source detection.
#
# Usage:   bash setup-claude-code.sh [--offline-path PATH] [--auto-download]
#
# Author:  DeepTrial (Enhanced)
# Version: 2.3 - Native binary support, offline resilience, non-interactive mode
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
# Configuration & Constants
# ---------------------------------------------------------------------------
# Get absolute path of script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Convert to absolute path in case it's relative
SCRIPT_DIR="$(cd "$SCRIPT_DIR" && pwd)"

# Source common utilities (if available)
if [ -f "${SCRIPT_DIR}/skills/lib/common.sh" ]; then
    source "${SCRIPT_DIR}/skills/lib/common.sh"
fi

# Fallback definitions if common.sh was not sourced
if ! type log_info >/dev/null 2>&1; then
    log_info() { echo "[INFO] $1"; }
    log_ok()   { echo "  [OK] $1"; }
    log_warn() { echo "  [WARN] $1"; }
    log_error(){ echo "  [ERROR] $1" >&2; }
fi
if ! type command_exists >/dev/null 2>&1; then
    command_exists() { command -v "$1" >/dev/null 2>&1; }
fi
if ! type test_url_accessible >/dev/null 2>&1; then
    test_url_accessible() {
        local url="$1" timeout="${2:-10}"
        if command_exists curl; then
            curl -fsSL --max-time "$timeout" --retry 2 -I "$url" >/dev/null 2>&1
        elif command_exists wget; then
            wget --timeout="$timeout" --tries=2 -q --spider "$url" 2>/dev/null
        else
            return 1
        fi
    }
fi
if ! type download_with_mirrors >/dev/null 2>&1; then
    download_with_mirrors() {
        local output_file="$1"; shift; local mirrors=("$@"); local success=false
        for mirror in "${mirrors[@]}"; do
            log_info "Trying mirror: $mirror"
            if command_exists curl; then
                curl -fsSL --max-time 10 --retry 2 -o "$output_file" "$mirror" 2>/dev/null && { success=true; log_ok "Downloaded from: $mirror"; break; }
            elif command_exists wget; then
                wget --timeout=10 --tries=2 -q -O "$output_file" "$mirror" 2>/dev/null && { success=true; log_ok "Downloaded from: $mirror"; break; }
            fi
            log_warn "Failed to download from: $mirror"
        done
        [ "$success" = true ]
    }
fi

USER_CLAUDE_DIR="$HOME/.claude"
USER_TMPDIR="$HOME/.claude/tmp"
BASHRC="$HOME/.bashrc"

# GitHub Release Configuration
GITHUB_REPO="DeepTrial/claude-code-offline"
GITHUB_API_URL="https://api.github.com/repos/${GITHUB_REPO}/releases/latest"

# Default offline package path (relative to script location)
DEFAULT_OFFLINE_PATH="${SCRIPT_DIR}/claude-offline-packages"

# Sentinel markers for shell config
SETUP_START="# >>> CLAUDE_CODE_SETUP >>>"
SETUP_END="# <<< CLAUDE_CODE_SETUP <<<"
NODE_START="# >>> CLAUDE_CODE_NODE >>>"
NODE_END="# <<< CLAUDE_CODE_NODE <<<"

# Network timeout settings (seconds)
NETWORK_TIMEOUT=10
CURL_RETRY=2

# Non-interactive mode flags (set by argument parsing)
ASSUME_YES=false
NON_INTERACTIVE=false

# Network status: unknown / true / false (set by check_network_status)
NETWORK_AVAILABLE="unknown"

# ---------------------------------------------------------------------------
# Mirror Source Configuration
# ---------------------------------------------------------------------------

# Node.js binary mirror sources
NODE_MIRRORS=(
    "https://nodejs.org/dist/"
    "https://npmmirror.com/mirrors/node/"
    "http://mirrors.cloud.tencent.com/nodejs-release/"
)

# npm registry mirror sources
NPM_MIRRORS=(
    "https://registry.npmjs.org/"
    "https://registry.npmmirror.com"
)

# nvm install script mirror sources
NVM_INSTALL_MIRRORS=(
    "https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh"
    "https://cdn.jsdelivr.net/gh/nvm-sh/nvm@v0.39.7/install.sh"
    "https://raw.gitmirror.com/nvm-sh/nvm/v0.39.7/install.sh"
)

# GitHub API/Release mirror sources (for fetching download URLs)
GITHUB_MIRRORS=(
    "https://api.github.com"
    "https://hub.gitmirror.com/https://api.github.com"
    "https://ghproxy.com/https://api.github.com"
    "https://ghps.cc/https://api.github.com"
)

# ---------------------------------------------------------------------------
# Uninstall Functions
# ---------------------------------------------------------------------------

# Detect if Claude Code is already installed
detect_existing_installation() {
    local found=false
    local install_paths=""
    
    # Check if claude exists in PATH (use type instead of command -v for speed)
    if type claude >/dev/null 2>&1; then
        found=true
        install_paths="  - Claude binary: $(type -P claude 2>/dev/null || echo 'in PATH')"
    fi
    
    # Check for npm global installation - use only direct path checks, no npm commands
    # Get home directory for path construction
    local home_dir="$HOME"
    
    # Check common npm global paths
    if [ -d "$home_dir/.local/lib/node_modules/@anthropic-ai/claude-code" ]; then
        found=true
        install_paths="$install_paths
  - npm global: $home_dir/.local/lib/node_modules/@anthropic-ai/claude-code"
    elif [ -d "/usr/local/lib/node_modules/@anthropic-ai/claude-code" ]; then
        found=true
        install_paths="$install_paths
  - npm global: /usr/local/lib/node_modules/@anthropic-ai/claude-code"
    elif [ -d "/usr/lib/node_modules/@anthropic-ai/claude-code" ]; then
        found=true
        install_paths="$install_paths
  - npm global: /usr/lib/node_modules/@anthropic-ai/claude-code"
    fi
    
    # Check WSL Windows npm path
    if [ -f /proc/version ] && grep -q Microsoft /proc/version 2>/dev/null; then
        # Extract username from Windows path
        local win_user="${USER:-$(whoami)}"
        local win_npm_path="/mnt/c/Users/$win_user/AppData/Roaming/npm/node_modules/@anthropic-ai/claude-code"
        if [ -d "$win_npm_path" ]; then
            found=true
            install_paths="$install_paths
  - Windows npm: $win_npm_path"
        fi
    fi
    
    # Check ~/.claude directory
    if [ -d "$home_dir/.claude" ]; then
        found=true
        install_paths="$install_paths
  - Config directory: $home_dir/.claude"
    fi
    
    # Check ~/.claude.json
    if [ -f "$home_dir/.claude.json" ]; then
        found=true
        install_paths="$install_paths
  - Config file: $home_dir/.claude.json"
    fi
    
    # Check .bashrc for configuration
    if [ -f "$BASHRC" ] && grep -q "$SETUP_START" "$BASHRC" 2>/dev/null; then
        found=true
        install_paths="$install_paths
  - Shell configuration: $BASHRC"
    fi
    
    if [ "$found" = true ]; then
        echo "$install_paths"
        return 0
    else
        return 1
    fi
}

# Uninstall Claude Code
uninstall_claude_code() {
    echo "============================================================================="
    echo "  Claude Code Uninstaller"
    echo "============================================================================="
    echo ""
    
    # Detect existing installation
    local existing
    existing=$(detect_existing_installation)
    
    # Also check for npm global installation (avoid all npm commands which can hang on WSL)
    local npm_global_claude=""
    # Check common npm global paths directly
    if [ -d "$HOME/.local/lib/node_modules/@anthropic-ai/claude-code" ]; then
        npm_global_claude="npm: $HOME/.local/lib/node_modules/@anthropic-ai/claude-code"
    elif [ -d "/usr/local/lib/node_modules/@anthropic-ai/claude-code" ]; then
        npm_global_claude="npm: /usr/local/lib/node_modules/@anthropic-ai/claude-code"
    elif [ -d "/usr/lib/node_modules/@anthropic-ai/claude-code" ]; then
        npm_global_claude="npm: /usr/lib/node_modules/@anthropic-ai/claude-code"
    fi
    
    if [ -z "$existing" ] && [ -z "$npm_global_claude" ]; then
        log_warn "No existing Claude Code installation detected."
        return 0
    fi
    
    if [ -n "$existing" ]; then
        echo "Detected existing installation at:"
        echo "$existing"
        echo ""
    fi
    
    if [ -n "$npm_global_claude" ]; then
        echo "Detected npm global installation:"
        echo "  $npm_global_claude"
        echo ""
    fi
    
    if ! confirm_uninstall; then
        log_info "Uninstall cancelled."
        return 0
    fi
    
    echo ""
    log_info "Starting uninstallation..."
    
    # 1. Backup configuration (ask user)
    if [ -d "$HOME/.claude" ] || [ -f "$HOME/.claude.json" ]; then
        if confirm "Do you want to backup configuration files before uninstalling?" y; then
            local backup_dir="$HOME/.claude-backup-$(date +%Y%m%d_%H%M%S)"
            mkdir -p "$backup_dir"
            
            if [ -d "$HOME/.claude" ]; then
                cp -r "$HOME/.claude" "$backup_dir/"
                log_ok "Configuration backed up to: $backup_dir"
            fi
            
            if [ -f "$HOME/.claude.json" ]; then
                cp "$HOME/.claude.json" "$backup_dir/"
            fi
        fi
    fi
    
    # 2. Remove npm global installation if exists (Linux side)
    if [ -n "$npm_global_claude" ]; then
        log_info "Removing npm global installation of Claude Code..."
        # Check if npm is available and not pointing to Windows
        if type npm >/dev/null 2>&1 && ! which npm | grep -q "/mnt/c"; then
            npm uninstall -g @anthropic-ai/claude-code 2>/dev/null || {
                log_warn "Failed to remove npm global installation automatically"
                log_info "You may need to run manually: npm uninstall -g @anthropic-ai/claude-code"
            }
        else
            log_warn "npm not available or using Windows npm, skipping npm uninstall"
            log_info "You may need to manually remove: $npm_global_claude"
        fi
    fi
    
    # 2.5 Special handling for WSL Windows npm installations
    if [ -f /proc/version ] && grep -q "Microsoft" /proc/version 2>/dev/null; then
        # Check for Windows npm claude
        local windows_npm_claude="/mnt/c/Users/$USER/AppData/Roaming/npm/claude"
        if [ -f "$windows_npm_claude" ] || [ -L "$windows_npm_claude" ]; then
            log_warn "Detected Windows npm installation at: $windows_npm_claude"
            log_info "Attempting to remove Windows npm installation..."
            
            # Try to use Windows npm to uninstall (with timeout to prevent hanging)
            if type cmd.exe >/dev/null 2>&1; then
                log_info "Running: cmd.exe /C npm uninstall -g @anthropic-ai/claude-code"
                timeout 10 cmd.exe /C "npm uninstall -g @anthropic-ai/claude-code" 2>/dev/null || {
                    log_warn "Failed to uninstall via Windows npm (timed out or failed)"
                }
            fi
            
            # Directly remove the files if npm uninstall failed
            if [ -f "$windows_npm_claude" ] || [ -L "$windows_npm_claude" ]; then
                log_info "Manually removing Windows npm files..."
                rm -f "$windows_npm_claude" 2>/dev/null || true
                rm -f "/mnt/c/Users/$USER/AppData/Roaming/npm/claude.cmd" 2>/dev/null || true
                rm -rf "/mnt/c/Users/$USER/AppData/Roaming/npm/node_modules/@anthropic-ai" 2>/dev/null || true
            fi
            
            log_ok "Windows npm installation removed"
        fi
        
        # Also check for other common Windows npm paths
        for win_path in "/mnt/c/Program Files/nodejs/claude" "/mnt/c/ProgramData/npm/claude"; do
            if [ -f "$win_path" ] 2>/dev/null; then
                log_warn "Found additional Windows installation at: $win_path"
                rm -f "$win_path" 2>/dev/null || true
            fi
        done
    fi
    
    # 3. Remove wrapper alias from .bashrc
    if [ -f "$BASHRC" ]; then
        # Remove claude wrapper alias
        if grep -q "claude-wrapper" "$BASHRC" 2>/dev/null; then
            log_info "Removing claude wrapper alias from .bashrc..."
            sed -i '/# Claude Code wrapper/d' "$BASHRC"
            sed -i "/alias claude='bash/d" "$BASHRC" 2>/dev/null || true
            log_ok "Removed wrapper alias"
        fi
        
        if grep -q "$SETUP_START" "$BASHRC" 2>/dev/null; then
            log_info "Removing PATH/TMPDIR configuration from .bashrc..."
            sed -i "/$SETUP_START/,/$SETUP_END/d" "$BASHRC"
            log_ok "Removed PATH/TMPDIR configuration"
        fi
        
        if grep -q "$NODE_START" "$BASHRC" 2>/dev/null; then
            log_info "Removing Node.js configuration from .bashrc..."
            sed -i "/$NODE_START/,/$NODE_END/d" "$BASHRC"
            log_ok "Removed Node.js configuration"
        fi
        
        # Remove NVM configuration (if added by this script)
        if grep -q "NVM CONFIGURATION" "$BASHRC" 2>/dev/null; then
            if confirm "Remove NVM configuration from .bashrc? (Select 'n' if you use nvm for other projects)" n; then
                sed -i '/# >>> NVM CONFIGURATION >>>/,/# <<< NVM CONFIGURATION <<</d' "$BASHRC"
                log_ok "Removed NVM configuration"
            fi
        fi
        
        # Remove Node.js PATH (if installed to ~/.local/node)
        if grep -q "/.local/node/bin" "$BASHRC" 2>/dev/null; then
            if confirm "Remove Node.js PATH from .bashrc? (Select 'n' if you use this Node.js for other projects)" n; then
                sed -i '/\/\.local\/node\/bin/d' "$BASHRC"
                log_ok "Removed Node.js PATH"
            fi
        fi
    fi
    
    # 4. Delete configuration files
    if [ -f "$HOME/.claude.json" ]; then
        log_info "Removing ~/.claude.json..."
        rm -f "$HOME/.claude.json"
        log_ok "Removed ~/.claude.json"
    fi
    
    # 5. Delete ~/.claude directory
    if [ -d "$HOME/.claude" ]; then
        log_info "Removing ~/.claude directory..."
        rm -rf "$HOME/.claude"
        log_ok "Removed ~/.claude directory"
    fi
    
    # 6. Ask if user wants to remove offline packages
    if [ -d "$USER_CLAUDE_DIR/offline-packages" ]; then
        if confirm "Remove downloaded offline packages?" n; then
            rm -rf "$USER_CLAUDE_DIR/offline-packages"
            log_ok "Removed offline packages"
        fi
    fi
    
    # 7. Ask if user wants to remove Node.js
    if [ -d "$HOME/.local/node" ]; then
        echo ""
        log_warn "Detected Node.js installation at: $HOME/.local/node"
        if confirm "Remove this Node.js installation? (Select 'n' if you use it for other projects)" n; then
            rm -rf "$HOME/.local/node"
            log_ok "Removed Node.js from $HOME/.local/node"
        fi
    fi
    
    # 8. Ask if user wants to remove nvm
    if [ -d "$HOME/.nvm" ]; then
        echo ""
        log_warn "Detected nvm installation at: $HOME/.nvm"
        if confirm "Remove nvm? (Select 'n' if you use it for other projects)" n; then
            rm -rf "$HOME/.nvm"
            log_ok "Removed nvm from $HOME/.nvm"
        fi
    fi
    
    echo ""
    echo "============================================================================="
    echo "  Uninstallation Complete"
    echo "============================================================================="
    echo ""
    echo "Claude Code has been uninstalled."
    echo ""
    echo "IMPORTANT: To complete the uninstallation, please:"
    echo "  1. Close and reopen your terminal (NOT just source ~/.bashrc)"
    echo "     This ensures all environment variables are cleared"
    echo "  2. Or run: exec bash -l"
    echo "  3. Verify: which claude (should return nothing)"
    echo ""
    
    # 9. For WSL: optionally fix PATH to remove Windows npm
    if [ -f /proc/version ] && grep -q "Microsoft" /proc/version 2>/dev/null; then
        if echo "$PATH" | grep -q "/mnt/c.*npm"; then
            echo ""
            if confirm "Detected Windows npm in WSL PATH. Add automatic fix to .bashrc?" y; then
                log_info "Adding PATH fix to .bashrc..."
                cat >> "$BASHRC" << 'WSLFIX'

# >>> WSL PATH FIX >>>
# Remove Windows npm from PATH to avoid conflicts
export PATH=$(echo "$PATH" | tr ':' '\n' | grep -v '/mnt/c.*npm' | tr '\n' ':')
# <<< WSL PATH FIX <<<
WSLFIX
                log_ok "PATH fix added to .bashrc"
            fi
        fi
    fi
    
    # WSL specific warning
    if [ -f /proc/version ] && grep -q "Microsoft" /proc/version 2>/dev/null; then
        echo "============================================================================="
        echo "  WSL Environment Detected"
        echo "============================================================================="
        echo ""
        echo "You appear to be running in WSL (Windows Subsystem for Linux)."
        echo ""
        echo "IF YOU STILL SEE 'Permission denied' ERRORS:"
        echo ""
        echo "1. Remove Windows npm from your WSL PATH:"
        echo "   Add this line to your ~/.bashrc:"
        echo ""
        echo "   export PATH=\$(echo \$PATH | tr ':' '\\n' | grep -v '/mnt/c.*npm' | tr '\\n' ':')"
        echo ""
        echo "2. Or manually remove Windows npm files:"
        echo "   rm -f /mnt/c/Users/\$USER/AppData/Roaming/npm/claude"
        echo "   rm -f /mnt/c/Users/\$USER/AppData/Roaming/npm/claude.cmd"
        echo ""
        echo "3. Alternative - Open Windows PowerShell and run:"
        echo "   npm uninstall -g @anthropic-ai/claude-code"
        echo ""
        echo "4. Then restart your terminal completely"
        echo "============================================================================="
    fi
    echo ""
    
    return 0
}

# ---------------------------------------------------------------------------
# Helper Functions
# ---------------------------------------------------------------------------

# Common utilities (log_*, command_exists, test_url_accessible, download_with_mirrors)
# are sourced from skills/lib/common.sh above.

# ---------------------------------------------------------------------------
# Interactivity helpers (--yes / --non-interactive support)
# ---------------------------------------------------------------------------

# Unified confirmation helper.
# Usage: confirm "Prompt text" [y|n]     (second arg = default answer, default n)
# Returns 0 for yes, 1 for no.
# When ASSUME_YES/NON_INTERACTIVE is set or stdin is not a TTY, the default
# answer is chosen automatically and the choice is printed.
confirm() {
    local prompt="$1"
    local default="${2:-n}"
    local yn_hint answer

    if [ "$default" = y ]; then yn_hint="[Y/n]"; else yn_hint="[y/N]"; fi

    if [ "$ASSUME_YES" = true ] || [ "$NON_INTERACTIVE" = true ] || [ ! -t 0 ]; then
        echo "$prompt $yn_hint: $default (auto)"
        [ "$default" = y ] && return 0 || return 1
    fi

    read -p "$prompt $yn_hint: " -n 1 -r answer || answer=""
    echo
    [ -z "$answer" ] && answer="$default"
    [[ "$answer" =~ ^[Yy]$ ]]
}

# Uninstall confirmation: always requires an explicit yes interactively,
# but --yes (ASSUME_YES) auto-confirms.
confirm_uninstall() {
    if [ "$ASSUME_YES" = true ]; then
        echo "Are you sure you want to uninstall Claude Code? [y/N]: y (auto, --yes)"
        return 0
    fi
    confirm "Are you sure you want to uninstall Claude Code?" n
}

# ---------------------------------------------------------------------------
# Network resilience helpers
# ---------------------------------------------------------------------------

# Probe npm registry and GitHub with a 5 second timeout each.
# Sets NETWORK_AVAILABLE=true/false and prints a clear conclusion.
check_network_status() {
    local npm_ok=false gh_ok=false
    local npm_probe="${NPM_MIRRORS[0]}"
    local gh_probe="${GITHUB_MIRRORS[0]}"

    log_info "Checking network connectivity (5s timeout per probe)..."

    if test_url_accessible "$npm_probe" 5; then
        npm_ok=true
        log_ok "npm registry reachable: $npm_probe"
    else
        log_warn "npm registry UNREACHABLE: $npm_probe"
    fi

    if test_url_accessible "$gh_probe" 5; then
        gh_ok=true
        log_ok "GitHub reachable: $gh_probe"
    else
        log_warn "GitHub UNREACHABLE: $gh_probe"
    fi

    if [ "$npm_ok" = true ] || [ "$gh_ok" = true ]; then
        NETWORK_AVAILABLE=true
        log_ok "Network available"
    else
        NETWORK_AVAILABLE=false
        log_warn "Network appears UNAVAILABLE (npm registry and GitHub both unreachable)"
    fi
    return 0
}

# Fail-fast guard for steps that require network access.
# Usage: require_network_or_fail "download offline packages"
require_network_or_fail() {
    local what="$1"
    if [ "$NETWORK_AVAILABLE" = "unknown" ]; then
        check_network_status
    fi
    if [ "$NETWORK_AVAILABLE" != true ]; then
        log_error "Cannot $what: network is unreachable."
        echo ""
        echo "Troubleshooting suggestions:"
        echo "  - Check your internet connection / proxy / firewall settings"
        echo "  - Behind a proxy? export HTTPS_PROXY=http://proxy-host:port"
        echo "  - Use a mirror, e.g.: NPM_MIRROR=https://registry.npmmirror.com bash $0 --auto-download"
        echo "  - Fully offline? use a pre-downloaded package: bash $0 --offline-path /path/to/claude-offline-packages"
        return 1
    fi
    return 0
}

# Run npm with a timeout and clear diagnostics.
# Usage: run_npm_with_timeout <seconds> <npm args...>
run_npm_with_timeout() {
    local seconds="$1"; shift
    echo "Running: npm $* (timeout ${seconds}s)"
    if timeout "$seconds" npm "$@"; then
        return 0
    fi
    local rc=$?
    if [ $rc -eq 124 ]; then
        log_error "'npm $*' timed out after ${seconds}s"
    else
        log_error "'npm $*' failed (exit code $rc)"
    fi
    echo ""
    echo "Possible causes:"
    echo "  - npm registry unreachable (check network / proxy / firewall)"
    echo "  - the configured registry is down or blocked"
    echo "Try specifying a mirror, e.g.:"
    echo "  NPM_MIRROR=https://registry.npmmirror.com bash $0"
    return $rc
}

# ---------------------------------------------------------------------------
# Native binary / launcher helpers (claude-code 2.x standalone binaries)
# ---------------------------------------------------------------------------

# Print the platform package binary path for this machine, if present.
# Usage: platform_native_binary <packages_dir>
platform_native_binary() {
    local pkg_dir="$1"
    local os arch suffix=""
    os="$(uname -s)"
    arch="$(uname -m)"
    case "$os" in
        Linux*)
            case "$arch" in
                x86_64|amd64)   suffix="linux-x64" ;;
                aarch64|arm64)  suffix="linux-arm64" ;;
            esac
            ;;
        Darwin*)
            case "$arch" in
                x86_64|amd64)   suffix="darwin-x64" ;;
                arm64)          suffix="darwin-arm64" ;;
            esac
            ;;
        CYGWIN*|MINGW*|MSYS*)
            case "$arch" in
                x86_64|amd64)   suffix="win32-x64" ;;
                arm64|aarch64)  suffix="win32-arm64" ;;
            esac
            ;;
    esac
    [ -z "$suffix" ] && return 1
    local candidate="$pkg_dir/node_modules/@anthropic-ai/claude-code-${suffix}/claude"
    case "$suffix" in
        win32-*) candidate="${candidate}.exe" ;;
    esac
    if [ -f "$candidate" ]; then
        echo "$candidate"
        return 0
    fi
    return 1
}

# File size that works on both GNU (Linux) and BSD (macOS) stat
file_size() {
    stat -c%s "$1" 2>/dev/null || stat -f%z "$1" 2>/dev/null || echo 0
}

# Test whether a native binary actually runs (--version within 30s)
native_binary_runs() {
    local bin="$1"
    [ -f "$bin" ] || return 1
    chmod +x "$bin" 2>/dev/null || true
    timeout 30 "$bin" --version >/dev/null 2>&1
}

# Detect how this package can run:
#   "native"   -> bin/claude.exe is a real, runnable native binary (no Node.js needed)
#   "platform" -> bin/claude.exe is a stub but the platform package binary runs
#   "node"     -> no usable native binary; Node.js wrapper fallback required
detect_runtime_mode() {
    local pkg_dir="$1"
    local main_bin="$pkg_dir/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
    local size plat_bin
    size=$(file_size "$main_bin")
    if [ "$size" -gt 100000 ] && native_binary_runs "$main_bin"; then
        echo "native"
        return 0
    fi
    plat_bin=$(platform_native_binary "$pkg_dir" || true)
    if [ -n "$plat_bin" ] && native_binary_runs "$plat_bin"; then
        echo "platform"
        return 0
    fi
    echo "node"
}

# Always (re)build node_modules/.bin/claude as a REAL launcher script
# (plain text file, never a symlink). This repairs packages whose symlinks
# were lost when the tar.gz was extracted with Windows tools (Explorer/7z).
# Returns: 0 = launcher execs native binary, 2 = Node.js wrapper fallback,
#          1 = fatal (no entry point found)
rebuild_claude_launcher() {
    local pkg_dir="$1"
    local bin_dir="$pkg_dir/node_modules/.bin"
    local launcher="$bin_dir/claude"
    local main_bin="$pkg_dir/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
    local size target_rel=""
    size=$(file_size "$main_bin")

    mkdir -p "$bin_dir"

    if [ "$size" -gt 100000 ]; then
        target_rel="../@anthropic-ai/claude-code/bin/claude.exe"
    else
        # bin/claude.exe is missing or a stub (<100KB): exec the platform
        # package binary instead (chosen by uname -s/-m)
        local plat_bin plat_name
        plat_bin=$(platform_native_binary "$pkg_dir" || true)
        if [ -n "$plat_bin" ]; then
            plat_name=$(basename "$(dirname "$plat_bin")")
            target_rel="../@anthropic-ai/${plat_name}/$(basename "$plat_bin")"
            log_warn "bin/claude.exe is a stub (${size} bytes); launcher will use ${plat_name} binary"
        fi
    fi

    rm -f "$launcher" 2>/dev/null || true

    if [ -n "$target_rel" ]; then
        cat > "$launcher" <<LAUNCHER
#!/usr/bin/env bash
# Claude Code launcher (generated by setup-claude-code.sh)
# Real file (NOT a symlink) so it survives Windows extraction tools.
# Locates its own directory via BASH_SOURCE, then execs the native binary.
SELF_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
exec "\$SELF_DIR/${target_rel}" "\$@"
LAUNCHER
        chmod +x "$launcher"
        log_ok "Rebuilt launcher as real file (execs native binary): $launcher"
        return 0
    fi

    # Fallback: Node.js wrapper (requires Node.js at runtime)
    if [ -f "$pkg_dir/node_modules/@anthropic-ai/claude-code/cli-wrapper.cjs" ]; then
        cat > "$launcher" << 'WRAPPER'
#!/usr/bin/env node
require('../@anthropic-ai/claude-code/cli-wrapper.cjs');
WRAPPER
        chmod +x "$launcher"
        log_warn "No usable native binary; launcher uses cli-wrapper.cjs (Node.js required at runtime)"
        return 2
    elif [ -f "$pkg_dir/node_modules/@anthropic-ai/claude-code/cli.js" ]; then
        cat > "$launcher" << 'LAUNCHER'
#!/usr/bin/env node
require('../@anthropic-ai/claude-code/cli.js');
LAUNCHER
        chmod +x "$launcher"
        log_warn "No usable native binary; launcher uses cli.js (Node.js required at runtime)"
        return 2
    fi

    log_error "Could not create claude launcher: no native binary or Node.js wrapper found in package"
    return 1
}

# ---------------------------------------------------------------------------
# jq helper for the skills installer (system -> bundled -> package manager)
# ---------------------------------------------------------------------------
ensure_jq_for_skills() {
    local pkg_dir="$1"

    if command -v jq &>/dev/null; then
        return 0
    fi

    log_warn "jq is required for skills installation"
    log_info "Attempting to use bundled jq from offline package..."

    # Try bundled jq first (no sudo required)
    local bundled_jq=""
    local os_jq arch_jq
    os_jq="$(uname -s)"
    arch_jq="$(uname -m)"

    case "$os_jq" in
        Linux*)
            case "$arch_jq" in
                x86_64|amd64)   bundled_jq="linux-amd64/jq" ;;
                aarch64|arm64)  bundled_jq="linux-arm64/jq" ;;
            esac
            ;;
        Darwin*)
            case "$arch_jq" in
                x86_64|amd64)   bundled_jq="macos-amd64/jq" ;;
                arm64)          bundled_jq="macos-arm64/jq" ;;
            esac
            ;;
        CYGWIN*|MINGW*|MSYS*)
            bundled_jq="windows-amd64/jq.exe"
            ;;
    esac

    # Search both known layouts: tools/jq/<platform> (legacy) and
    # skills/bin/<platform> (current packages)
    local candidate=""
    if [ -n "$bundled_jq" ]; then
        local base
        for base in "${pkg_dir}/tools/jq" "${pkg_dir}/skills/bin"; do
            if [ -x "${base}/${bundled_jq}" ]; then
                candidate="${base}/${bundled_jq}"
                break
            fi
        done
    fi

    if [ -n "$candidate" ]; then
        # Create a temporary jq in PATH so `command -v jq` succeeds
        local tmp_jq_dir
        tmp_jq_dir=$(mktemp -d)
        ln -sf "$candidate" "$tmp_jq_dir/jq"
        export PATH="$tmp_jq_dir:$PATH"
        log_ok "Using bundled jq from offline package (no sudo required): $candidate"
        return 0
    fi

    # Fallback: try to install system jq (requires sudo and network)
    log_info "No bundled jq found for ${os_jq}/${arch_jq}, attempting system install..."
    if ! require_network_or_fail "install jq"; then
        return 1
    fi
    if command -v apt-get &>/dev/null; then
        sudo apt-get update && sudo apt-get install -y jq
    elif command -v yum &>/dev/null; then
        sudo yum install -y jq
    elif command -v brew &>/dev/null; then
        brew install jq
    else
        log_error "Could not install jq automatically"
        return 1
    fi
}

# ---------------------------------------------------------------------------
# Direct npm installation of Claude Code (requires network)
# ---------------------------------------------------------------------------
install_via_npm_direct() {
    local target_dir="$1"
    mkdir -p "$target_dir"
    cd "$target_dir"

    if ! require_network_or_fail "install Claude Code via npm"; then
        return 1
    fi

    # Select the fastest npm mirror (or the default when skipping tests)
    local npm_mirror
    if [ "$SKIP_MIRROR_TEST" = true ]; then
        npm_mirror="${NPM_MIRRORS[0]}"
    else
        npm_mirror=$(select_fastest_npm_mirror)
    fi
    npm config set registry "$npm_mirror"

    log_info "Installing Claude Code via npm..."
    if ! run_npm_with_timeout 180 install @anthropic-ai/claude-code --production; then
        return 1
    fi
    mkdir -p node_modules/.bin
    if [ -f "node_modules/@anthropic-ai/claude-code/cli.js" ]; then
        ln -sf ../@anthropic-ai/claude-code/cli.js node_modules/.bin/claude
        chmod +x node_modules/.bin/claude
    fi
    log_ok "Claude Code installed"
}

# ---------------------------------------------------------------------------
# Config File Generators (used by both --config-only and normal mode)
# ---------------------------------------------------------------------------

generate_settings_json() {
    local settings_file="$USER_CLAUDE_DIR/settings.json"
    if [ -f "$settings_file" ]; then
        local backup_name="settings.json.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$settings_file" "$USER_CLAUDE_DIR/backups/$backup_name"
        log_warn "settings.json already exists. Backed up to backups/$backup_name"
    else
        cat > "$settings_file" << 'SETTINGSJSON'
{
  "env": {
    "ANTHROPIC_BASE_URL": "YOUR_BASE_URL_HERE",
    "ANTHROPIC_API_KEY": "YOUR_API_KEY_HERE",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "YOUR_MODEL_HERE",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "YOUR_MODEL_HERE",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "YOUR_MODEL_HERE",
    "DISABLE_AUTOUPDATER": "1",
    "CLAUDE_CODE_EXPERIMENTAL_AGENT_TEAMS": "1",
    "CLAUDE_CODE_SKIP_FIRST_RUN": "1",
    "CLAUDE_CODE_TELEMETRY": "0",
    "DISABLE_TELEMETRY": "1",
    "CLAUDE_CODE_WEB_FETCH_SKIP_SAFETY_CHECK": "1"
  },
  "autoUpdate": { "enabled": false },
  "hasCompletedOnboarding": true,
  "skipOnboarding": true,
  "telemetry": { "enabled": false }
}
SETTINGSJSON
        log_ok "Created settings.json with placeholder values"
    fi
}

generate_config_json() {
    local config_file="$USER_CLAUDE_DIR/config.json"
    if [ -f "$config_file" ]; then
        log_ok "config.json already exists"
    else
        cat > "$config_file" << 'CONFIGJSON'
{ "primaryApiKey": "mimo" }
CONFIGJSON
        log_ok "Created config.json"
    fi
}

generate_claude_json() {
    local claude_json="$HOME/.claude.json"
    local first_start
    first_start=$(date -u +"%Y-%m-%dT%H:%M:%S.000Z")

    if [ -f "$claude_json" ]; then
        local backup_name=".claude.json.backup.$(date +%Y%m%d_%H%M%S)"
        cp "$claude_json" "$USER_CLAUDE_DIR/backups/$backup_name"

        if command_exists python3; then
            python3 -c "
import json, sys
try:
    with open('$claude_json', 'r') as f:
        data = json.load(f)
    data['hasCompletedOnboarding'] = True
    with open('$claude_json', 'w') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    pass
" 2>/dev/null || true
        elif command_exists jq; then
            jq '.hasCompletedOnboarding = true' "$claude_json" > "$claude_json.tmp" && mv "$claude_json.tmp" "$claude_json" 2>/dev/null || true
        fi
        log_ok "Updated .claude.json (backed up to backups/$backup_name)"
    else
        cat > "$claude_json" << CLAUDEJSON
{
  "hasCompletedOnboarding": true,
  "firstStartTime": "$first_start",
  "skipOnboarding": true,
  "onboardingCompleted": true,
  "hasSeenInitialMessage": true,
  "hasAcceptedTerms": true,
  "telemetry": {
    "enabled": false,
    "consentGiven": false
  },
  "regionCheck": {
    "bypassed": true,
    "checkedAt": "$first_start"
  }
}
CLAUDEJSON
        log_ok "Created .claude.json"
    fi
}

generate_claude_wrapper() {
    local wrapper="$USER_CLAUDE_DIR/claude-wrapper.sh"
    cat > "$wrapper" << 'WRAPPER'
#!/usr/bin/env bash
# Claude Code Wrapper Script
# This script sets up necessary environment variables to bypass region checks

# 禁用自动更新
export DISABLE_AUTOUPDATER=1

# 禁用遥测
export CLAUDE_CODE_TELEMETRY=0
export DISABLE_TELEMETRY=1

# 跳过首次运行检查
export CLAUDE_CODE_SKIP_FIRST_RUN=1

# 跳过引导流程
export CLAUDE_CODE_SKIP_ONBOARDING=1

# 禁用 Web Tool 的域名安全检查（离线环境下无法连接 claude.ai 验证）
# 这样 Web Tool 会直接获取网页内容而不需要安全检查
export CLAUDE_CODE_WEB_FETCH_SKIP_SAFETY_CHECK=1

# 设置 API 配置（如果用户已配置）
if [ -f "$HOME/.claude/settings.json" ]; then
    # Try to read API configuration from settings.json
    if command -v jq >/dev/null 2>&1; then
        BASE_URL=$(jq -r '.env.ANTHROPIC_BASE_URL // empty' "$HOME/.claude/settings.json" 2>/dev/null)
        API_KEY=$(jq -r '.env.ANTHROPIC_API_KEY // empty' "$HOME/.claude/settings.json" 2>/dev/null)
        [ -n "$BASE_URL" ] && export ANTHROPIC_BASE_URL="$BASE_URL"
        [ -n "$API_KEY" ] && export ANTHROPIC_API_KEY="$API_KEY"
    fi
fi

# Execute original claude command
exec claude "$@"
WRAPPER
    chmod +x "$wrapper"
    log_ok "Created claude-wrapper.sh"
}

generate_clean_tmp() {
    local script="$USER_CLAUDE_DIR/clean-tmp.sh"
    cat > "$script" << 'CLEANTMP'
#!/usr/bin/env bash
# Clean Claude Code tmp directory

TMPDIR="$HOME/.claude/tmp"

echo "Claude Code TMP Directory Cleaner"
echo "=================================="
echo ""

if [ ! -d "$TMPDIR" ]; then
    echo "TMP directory does not exist: $TMPDIR"
    exit 0
fi

# Show current size
SIZE=$(du -sh "$TMPDIR" 2>/dev/null | cut -f1)
echo "Current TMP directory size: $SIZE"
echo ""

# Count files
FILE_COUNT=$(find "$TMPDIR" -type f 2>/dev/null | wc -l)
echo "Number of files: $FILE_COUNT"
echo ""

read -p "Do you want to clean the TMP directory? [y/N]: " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

echo ""
echo "Select cleanup option:"
echo "  1) Clean items older than 7 days"
echo "  2) Clean items older than 3 days"
echo "  3) Clean everything"
echo ""
read -p "Select option [1-3]: " -r option

case $option in
    1)
        FIND_MTIME=7
        ;;
    2)
        FIND_MTIME=3
        ;;
    3)
        FIND_MTIME=0
        ;;
    *)
        echo "Invalid option. Cancelling."
        exit 1
        ;;
esac

# Show what will be deleted
echo ""
echo "The following items will be deleted:"
if [ "$FIND_MTIME" -eq 0 ]; then
    find "$TMPDIR" -mindepth 1 -exec ls -ld {} \;
else
    find "$TMPDIR" -mindepth 1 -mtime +$FIND_MTIME -exec ls -ld {} \;
fi

echo ""
read -p "Confirm deletion? [y/N]: " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Cleanup cancelled."
    exit 0
fi

# Perform cleanup
if [ "$FIND_MTIME" -eq 0 ]; then
    rm -rf "$TMPDIR"/*
    rm -rf "$TMPDIR"/.* 2>/dev/null || true
else
    find "$TMPDIR" -mindepth 1 -mtime +$FIND_MTIME -delete
fi

NEW_SIZE=$(du -sh "$TMPDIR" 2>/dev/null | cut -f1)
echo ""
echo "Cleanup complete. New size: $NEW_SIZE"
CLEANTMP
    chmod +x "$script"
    log_ok "Created clean-tmp.sh"
}

# Generic mirror speed test
# NOTE: log output goes to stderr so `mirror=$(select_fastest_*)` captures
# only the mirror URL on stdout.
select_fastest_mirror() {
    local name="$1"
    shift
    local mirrors=("$@")
    local best_mirror="${mirrors[0]}"
    local min_time=9999

    # Honor --skip-mirror-test: use the first (default) mirror without probing
    if [ "${SKIP_MIRROR_TEST:-false}" = true ]; then
        log_info "Skipping ${name} mirror test, using default: $best_mirror" >&2
        echo "$best_mirror"
        return 0
    fi

    log_info "Testing ${name} mirrors for best speed..." >&2

    for mirror in "${mirrors[@]}"; do
        local start_time end_time elapsed
        start_time=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")

        if test_url_accessible "$mirror" 3; then
            end_time=$(date +%s%N 2>/dev/null || echo "$(date +%s)000000000")
            elapsed=$(( (end_time - start_time) / 1000000 ))

            log_info "  $mirror: ${elapsed}ms" >&2

            if [ "$elapsed" -lt "$min_time" ]; then
                min_time=$elapsed
                best_mirror="$mirror"
            fi
        else
            log_warn "  $mirror: UNREACHABLE" >&2
        fi
    done

    log_ok "Selected ${name} mirror: $best_mirror" >&2
    echo "$best_mirror"
}

# Wrapper functions for backward compatibility
select_fastest_node_mirror()   { select_fastest_mirror "Node.js" "${NODE_MIRRORS[@]}"; }
select_fastest_npm_mirror()    { select_fastest_mirror "npm" "${NPM_MIRRORS[@]}"; }
select_fastest_github_mirror() { select_fastest_mirror "GitHub" "${GITHUB_MIRRORS[@]}"; }

# Get Node.js major version number
get_node_major_version() {
    local version
    version=$(node --version 2>/dev/null | sed 's/v//' | cut -d. -f1)
    echo "${version:-0}"
}

# Check if Node.js meets requirements (>= 18, including v25+)
# Supports Node.js 18, 20, 22, 25 and future versions
check_nodejs_requirement() {
    local min_version=18
    local max_tested_version=30  # Future-proof: tested up to v25, should work for higher
    
    if ! command_exists node; then
        return 1
    fi
    
    local current_version
    current_version=$(get_node_major_version)
    
    # Check if version is >= 18
    if [ "$current_version" -ge "$min_version" ]; then
        # Warn if version is very new (beyond tested range)
        if [ "$current_version" -gt "$max_tested_version" ]; then
            log_warn "Node.js v$current_version is newer than tested versions (up to v$max_tested_version)"
            log_info "It should work, but if you encounter issues, consider using Node.js LTS (v20 or v22)"
        fi
        return 0
    else
        return 1
    fi
}

# Get recommended Node.js version based on availability
get_recommended_node_version() {
    local node_version
    node_version=$(get_node_major_version)
    
    # If we already have a suitable version, use it
    if [ "$node_version" -ge 18 ]; then
        echo "$node_version"
        return
    fi
    
    # Default to 22 (LTS; claude-code 2.x package.json engines require node >= 22
    # for the npm wrapper path; the native binary itself does not need Node.js)
    echo "22"
}

# Download and install Node.js binary
# Supports versions 18, 20, 22, 25 and future versions
download_and_install_nodejs() {
    local install_dir="$1"
    local version="${2:-22.11.0}"  # Default to Node.js 22 LTS
    local arch="linux-x64"
    
    log_info "Downloading Node.js v${version}..."
    
    local mirror
    mirror=$(select_fastest_node_mirror)
    
    local filename="node-v${version}-${arch}.tar.xz"
    local download_url="${mirror}v${version}/${filename}"
    local temp_file="/tmp/${filename}"
    
    log_info "Downloading from: $download_url"
    
    if command_exists curl; then
        if ! curl -fsSL --progress-bar --max-time 300 -o "$temp_file" "$download_url"; then
            log_error "Failed to download Node.js"
            return 1
        fi
    elif command_exists wget; then
        if ! wget --progress=bar:force --timeout=300 -O "$temp_file" "$download_url"; then
            log_error "Failed to download Node.js"
            return 1
        fi
    else
        log_error "Neither curl nor wget is available"
        return 1
    fi
    
    log_info "Extracting Node.js to $install_dir..."
    mkdir -p "$install_dir"
    tar -xJf "$temp_file" -C "$install_dir" --strip-components=1
    rm -f "$temp_file"
    
    # Add to PATH
    if ! grep -q "$install_dir/bin" "$BASHRC" 2>/dev/null; then
        echo "export PATH=\"$install_dir/bin:\$PATH\"" >> "$BASHRC"
    fi
    export PATH="$install_dir/bin:$PATH"
    
    log_ok "Node.js v${version} installed to $install_dir"
    return 0
}

# Get the latest LTS or specific Node version
download_latest_node() {
    local install_dir="$1"
    local preferred_version="${2:-22}"
    
    log_info "Attempting to install Node.js v${preferred_version}..."
    
    # Map major version to latest known release
    local version_map
    case "$preferred_version" in
        18) version_map="18.20.5" ;;
        20) version_map="20.18.0" ;;
        22) version_map="22.11.0" ;;
        25) version_map="25.0.0" ;;  # Latest as of 2026
        *)  version_map="${preferred_version}.0.0" ;;  # Try generic for future versions
    esac
    
    # Try specific version first
    if download_and_install_nodejs "$install_dir" "$version_map"; then
        return 0
    fi
    
    # Fall back to Node.js 22 LTS
    log_warn "Failed to download Node.js v${version_map}, trying v22 LTS..."
    if download_and_install_nodejs "$install_dir" "22.11.0"; then
        return 0
    fi
    
    return 1
}

# Install Node.js (using nvm or direct download)
# Supports Node.js 18, 20, 22, 25 and future versions
install_nodejs() {
    log_info "Installing Node.js (>= 18, supports up to v25+)..."
    
    # Determine best version to install (prefer 20 if no suitable version exists)
    local target_version
    target_version=$(get_recommended_node_version)
    
    # Method 1: Check if nvm already exists
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        log_info "Using existing nvm to install Node.js..."
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        # Set Node.js mirror source for nvm (use npmmirror for Node.js binaries)
        export NVM_NODEJS_ORG_MIRROR="https://npmmirror.com/mirrors/node/"
        
        # Try to install preferred version, fallback to lts if not available
        if ! nvm install "$target_version" 2>/dev/null; then
            log_warn "Node.js $target_version not available via nvm, trying LTS..."
            if ! nvm install 22 2>/dev/null; then
                log_warn "Node.js 22 not available, trying any LTS..."
                nvm install --lts || {
                    log_error "Failed to install Node.js via nvm"
                    return 1
                }
            fi
        fi
        nvm use "$target_version" 2>/dev/null || nvm use 22 2>/dev/null || nvm use --lts
        nvm alias default "$target_version" 2>/dev/null || nvm alias default 22 2>/dev/null || nvm alias default --lts
        log_ok "Node.js installed via nvm"
        return 0
    fi
    
    # Method 2: Install nvm then install Node.js
    log_info "Installing nvm..."
    local nvm_install_script="/tmp/nvm-install.sh"
    
    if download_with_mirrors "$nvm_install_script" "${NVM_INSTALL_MIRRORS[@]}"; then
        chmod +x "$nvm_install_script"
        # Install nvm without modifying shell config (we'll do it manually)
        PROFILE=/dev/null bash "$nvm_install_script" 2>/dev/null || bash "$nvm_install_script"
        rm -f "$nvm_install_script"
        
        export NVM_DIR="$HOME/.nvm"
        [ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"
        
        # 添加到 .bashrc
        if ! grep -q "NVM_DIR" "$BASHRC" 2>/dev/null; then
            cat >> "$BASHRC" << 'NVMBLOCK'

# >>> NVM CONFIGURATION >>>
export NVM_DIR="$HOME/.nvm"
[ -s "$NVM_DIR/nvm.sh" ] && \. "$NVM_DIR/nvm.sh"  # This loads nvm
[ -s "$NVM_DIR/bash_completion" ] && \. "$NVM_DIR/bash_completion"  # This loads nvm bash_completion
# <<< NVM CONFIGURATION <<<
NVMBLOCK
        fi
        
        # 设置镜像源
        local npm_mirror
        npm_mirror=$(select_fastest_npm_mirror)
        export NVM_NODEJS_ORG_MIRROR="${npm_mirror/https:\/\/registry.npmmirror.com\/}/mirrors/node/"
        
        # Try to install preferred version, fallback to 20 then lts
        if ! nvm install "$target_version" 2>/dev/null; then
            log_warn "Node.js $target_version not available, trying 22..."
            if ! nvm install 22 2>/dev/null; then
                log_warn "Node.js 22 not available, trying LTS..."
                nvm install --lts || {
                    log_error "Failed to install Node.js via nvm"
                    return 1
                }
            fi
        fi
        nvm use "$target_version" 2>/dev/null || nvm use 22 2>/dev/null || nvm use --lts
        nvm alias default "$target_version" 2>/dev/null || nvm alias default 22 2>/dev/null || nvm alias default --lts
        
        log_ok "Node.js installed via nvm"
        return 0
    fi
    
    # Method 3: Download binary directly
    log_info "Downloading Node.js binary directly..."
    if download_latest_node "$HOME/.local/node" "$target_version"; then
        return 0
    fi
    
    log_error "Failed to install Node.js"
    return 1
}

# Ensure Node.js is available
ensure_nodejs() {
    log_info "Checking Node.js environment..."
    
    if check_nodejs_requirement; then
        local node_version
        node_version=$(node --version)
        log_ok "Node.js $node_version is available"
        return 0
    fi
    
    log_warn "Node.js >= 18 is required but not found"
    
    if confirm "Do you want to install Node.js automatically?" y; then
        if ! require_network_or_fail "install Node.js"; then
            return 1
        fi
        if install_nodejs; then
            # 重新检查
            if check_nodejs_requirement; then
                local node_version
                node_version=$(node --version)
                log_ok "Node.js $node_version is now available"
                return 0
            else
                log_error "Node.js installation failed"
                return 1
            fi
        else
            log_error "Node.js installation failed"
            return 1
        fi
    else
        log_error "Node.js >= 18 is required. Please install it manually and re-run this script."
        return 1
    fi
}

# Download offline packages from GitHub Release
download_offline_packages() {
    log_info "Downloading offline packages from GitHub Release..."
    
    local download_dir="$1"
    mkdir -p "$download_dir"
    
    # Fail fast (with clear guidance) when the network is unreachable
    if ! require_network_or_fail "download offline packages"; then
        return 1
    fi
    
    # Get fastest GitHub mirror
    local github_mirror
    if [ "$SKIP_MIRROR_TEST" = true ]; then
        github_mirror="${GITHUB_MIRRORS[0]}"
    else
        github_mirror=$(select_fastest_github_mirror)
    fi
    
    log_info "Using GitHub mirror: $github_mirror"
    
    # Get latest release download URL
    log_info "Fetching latest release info..."
    
    local release_info
    release_info=$(curl -fsSL --max-time "$NETWORK_TIMEOUT" "$github_mirror/repos/${GITHUB_REPO}/releases/latest" 2>/dev/null) || {
        log_error "Failed to fetch release info"
        return 1
    }
    
    local download_url
    download_url=$(echo "$release_info" | grep "browser_download_url.*claude-offline-packages.tar.gz\"" | head -1 | cut -d '"' -f 4)
    
    if [ -z "$download_url" ]; then
        log_error "Could not find offline packages in latest release"
        log_info "Trying to download from alternative source..."
        
        # Fallback: Direct npm install
        log_info "Installing Claude Code directly via npm..."
        
        # Set fastest npm mirror
        local npm_mirror
        if [ "$SKIP_MIRROR_TEST" = true ]; then
            npm_mirror="${NPM_MIRRORS[0]}"
        else
            npm_mirror=$(select_fastest_npm_mirror)
        fi
        npm config set registry "$npm_mirror"
        
        mkdir -p "$download_dir"
        cd "$download_dir"
        if ! run_npm_with_timeout 180 install @anthropic-ai/claude-code --production; then
            return 1
        fi
        
        # 创建 .bin 链接
        mkdir -p node_modules/.bin
        if [ -f "node_modules/@anthropic-ai/claude-code/cli.js" ]; then
            ln -sf ../@anthropic-ai/claude-code/cli.js node_modules/.bin/claude
            chmod +x node_modules/.bin/claude
        fi
        
        log_ok "Claude Code installed via npm"
        return 0
    fi
    
    # Use mirror to accelerate download
    local accelerated_url
    if [[ "$github_mirror" == "https://api.github.com" ]]; then
        accelerated_url="$download_url"
    else
        # Replace API URL with download acceleration URL
        accelerated_url="${github_mirror/https:\/\/api.github.com/https:\/\/github.com}"
        accelerated_url="${download_url/https:\/\/github.com/$accelerated_url}"
    fi
    
    log_info "Downloading from: $accelerated_url"
    
    local temp_file="$download_dir/claude-offline-packages.tar.gz"
    
    # Download file
    if command_exists wget; then
        wget -q --show-progress --timeout=300 -O "$temp_file" "$accelerated_url"
    else
        curl -fsSL --progress-bar --max-time 300 -o "$temp_file" "$accelerated_url"
    fi
    
    # Verify download
    if [ ! -f "$temp_file" ] || [ ! -s "$temp_file" ]; then
        log_error "Download failed or file is empty"
        return 1
    fi
    
    # Extract
    log_info "Extracting packages..."
    tar -xzf "$temp_file" -C "$download_dir" --strip-components=1
    rm -f "$temp_file"
    
    log_ok "Offline packages downloaded and extracted"
    return 0
}

# Find offline package path
# Supports both old (node_modules) and new (.tgz + package.json) formats
find_offline_packages() {
    local paths=(
        "${SCRIPT_DIR}/claude-offline-packages"
        "${SCRIPT_DIR}/../claude-offline-packages"
        "$HOME/claude-offline-packages"
        "/opt/claude-offline-packages"
        "/usr/local/claude-offline-packages"
    )
    
    for path in "${paths[@]}"; do
        # New format: pre-extracted node_modules with @anthropic-ai/claude-code
        # (cli.js legacy, native binary, or Node.js wrapper entry points)
        if [ -r "$path/node_modules/@anthropic-ai/claude-code/cli.js" ] \
            || [ -r "$path/node_modules/@anthropic-ai/claude-code/bin/claude.exe" ] \
            || [ -r "$path/node_modules/@anthropic-ai/claude-code/cli-wrapper.cjs" ]; then
            echo "$path"
            return 0
        fi
        # Check alternative format: package.json with .tgz files (needs extraction)
        if [ -f "$path/package.json" ] && ls "$path"/*.tgz >/dev/null 2>&1; then
            echo "$path"
            return 0
        fi
        # Old format: pre-installed node_modules with .bin/claude
        if [ -r "$path/node_modules/.bin/claude" ]; then
            echo "$path"
            return 0
        fi
    done
    
    return 1
}

# Install offline packages from .tgz files
install_from_tgz_packages() {
    local pkg_dir="$1"
    local target_dir="$2"
    
    log_info "Installing from local .tgz packages..."
    
    mkdir -p "$target_dir"
    cd "$target_dir"
    
    # Copy package files
    cp "$pkg_dir/package.json" "$pkg_dir/package-lock.json" . 2>/dev/null || true
    cp "$pkg_dir"/*.tgz . 2>/dev/null || true
    
    # Install dependencies
    if [ -f "package.json" ]; then
        run_npm_with_timeout 180 ci --production 2>/dev/null || run_npm_with_timeout 180 install --production 2>/dev/null || {
            log_warn "npm install failed, trying npm ci..."
            run_npm_with_timeout 180 ci --production
        }
    fi
    
    log_ok "Packages installed to $target_dir"
}

# ---------------------------------------------------------------------------
# Banner & Safety Checks
# ---------------------------------------------------------------------------
echo "============================================================================="
echo "  Claude Code Deployment Script v2.3 - Native Binary / Offline Resilient"
echo "============================================================================="
echo ""

# Exit if running as root
if [ "$(id -u)" -eq 0 ]; then
    log_error "Do not run this script as root. Run it as your own user account."
    exit 1
fi

# ---------------------------------------------------------------------------
# Parse Arguments (before interactive prompts so --help etc. work immediately)
# ---------------------------------------------------------------------------
OFFLINE_PATH=""
AUTO_DOWNLOAD=false
FORCE_DOWNLOAD=false
SKIP_MIRROR_TEST=false
CONFIG_ONLY=false
SKILLS_ONLY=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --offline-path)
            OFFLINE_PATH="$2"
            shift 2
            ;;
        --auto-download)
            AUTO_DOWNLOAD=true
            shift
            ;;
        --force-download)
            FORCE_DOWNLOAD=true
            shift
            ;;
        --skip-mirror-test)
            SKIP_MIRROR_TEST=true
            shift
            ;;
        --config-only)
            CONFIG_ONLY=true
            shift
            ;;
        --skills-only)
            SKILLS_ONLY=true
            shift
            ;;
        --yes|-y)
            ASSUME_YES=true
            shift
            ;;
        --non-interactive)
            NON_INTERACTIVE=true
            shift
            ;;
        --uninstall)
            uninstall_claude_code
            exit 0
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --offline-path PATH    Specify path to offline packages"
            echo "  --auto-download        Automatically download packages from GitHub"
            echo "  --force-download       Force re-download even if packages exist"
            echo "  --skip-mirror-test     Skip mirror speed test (use default sources)"
            echo "  --config-only          Only generate configuration files (skip Claude installation)"
            echo "  --skills-only          Only install offline skills"
            echo "  --yes, -y              Assume 'yes' for all prompts (fully unattended install)"
            echo "  --non-interactive      Never prompt; use default answers (safe for scripts/CI)"
            echo "  --uninstall            Uninstall Claude Code and related configuration"
            echo "  --help, -h             Show this help message"
            echo ""
            echo "Node.js note:"
            echo "  claude-code 2.x ships a standalone native binary that does NOT need"
            echo "  Node.js. When a runnable native binary is detected, Node.js setup is"
            echo "  optional (skipped by default). Node.js >= 18 (22 recommended) is only"
            echo "  required when the package must fall back to the Node.js wrapper."
            echo ""
            echo "Environment Variables:"
            echo "  NODE_MIRROR            Custom Node.js mirror URL"
            echo "  NPM_MIRROR             Custom npm registry URL"
            echo "  GITHUB_MIRROR          Custom GitHub API mirror URL"
            echo ""
            echo "Examples:"
            echo "  $0                                    # Auto-detect or interactive mode"
            echo "  $0 --offline-path /path/to/packages   # Use specific offline packages"
            echo "  $0 --auto-download                    # Auto-download with mirror detection"
            echo "  $0 --offline-path ./pkg --yes         # Unattended offline install"
            echo "  $0 --config-only                      # Only generate config files"
            echo "  $0 --skills-only                      # Only install offline skills"
            echo "  NODE_MIRROR=https://... $0            # Use custom mirror"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Apply environment variable overrides
if [ -n "${NODE_MIRROR:-}" ]; then
    NODE_MIRRORS=("$NODE_MIRROR" "${NODE_MIRRORS[@]}")
fi
if [ -n "${NPM_MIRROR:-}" ]; then
    NPM_MIRRORS=("$NPM_MIRROR" "${NPM_MIRRORS[@]}")
fi
if [ -n "${GITHUB_MIRROR:-}" ]; then
    GITHUB_MIRRORS=("$GITHUB_MIRROR" "${GITHUB_MIRRORS[@]}")
fi

# ---------------------------------------------------------------------------
# Handle --config-only mode (skip package installation)
# ---------------------------------------------------------------------------
if [ "$CONFIG_ONLY" = true ]; then
    echo "============================================================================="
    echo "  Configuration Only Mode"
    echo "============================================================================="
    echo ""
    log_info "Generating configuration files only (skipping Claude installation)"
    echo ""

    # Step 3: Create Directory Structure
    echo "Step 1/2: Creating ~/.claude/ directory structure..."

    mkdir -p "$USER_CLAUDE_DIR"
    mkdir -p "$USER_CLAUDE_DIR/tmp"
    mkdir -p "$USER_CLAUDE_DIR/backups"
    mkdir -p "$USER_CLAUDE_DIR/plugins"

    log_ok "Directories created"
    echo ""

    # Step 4: Generate Config Files (inline for CONFIG_ONLY mode)
    echo "Step 2/2: Generating configuration files..."

    # Generate config files using shared functions
    generate_settings_json
    generate_config_json
    generate_claude_json
    generate_claude_wrapper
    generate_clean_tmp

    echo ""
    echo "============================================================================="
    echo "  Configuration Complete"
    echo "============================================================================="
    echo ""
    echo "  Generated files:"
    echo "    - ~/.claude/settings.json"
    echo "    - ~/.claude/config.json"
    echo "    - ~/.claude.json"
    echo "    - ~/.claude/claude-wrapper.sh"
    echo "    - ~/.claude/clean-tmp.sh"
    echo ""
    echo "  IMPORTANT: Edit ~/.claude/settings.json with your API credentials:"
    echo ""
    echo "    nano ~/.claude/settings.json"
    echo ""
    echo "============================================================================="
    exit 0
fi

# ---------------------------------------------------------------------------
# Handle --skills-only mode
# ---------------------------------------------------------------------------
if [ "$SKILLS_ONLY" = true ]; then
    echo "============================================================================="
    echo "  Skills Installation Only Mode"
    echo "============================================================================="
    echo ""

    # Find skills directory
    SKILLS_DIR=""

    # Check common locations
    if [ -n "$OFFLINE_PATH" ] && [ -d "$OFFLINE_PATH/skills" ]; then
        SKILLS_DIR="$OFFLINE_PATH/skills"
    elif [ -d "${SCRIPT_DIR}/claude-offline-packages/skills" ]; then
        SKILLS_DIR="${SCRIPT_DIR}/claude-offline-packages/skills"
    elif [ -d "${SCRIPT_DIR}/skills" ]; then
        SKILLS_DIR="${SCRIPT_DIR}/skills"
    elif [ -d "$HOME/.claude/offline-packages/skills" ]; then
        SKILLS_DIR="$HOME/.claude/offline-packages/skills"
    fi

    if [ -z "$SKILLS_DIR" ] || [ ! -d "$SKILLS_DIR" ]; then
        log_error "Skills directory not found"
        log_info "Please specify with --offline-path or run from correct directory"
        log_info "Searched:"
        log_info "  - \${SCRIPT_DIR}/claude-offline-packages/skills"
        log_info "  - \${SCRIPT_DIR}/skills"
        log_info "  - ~/.claude/offline-packages/skills"
        exit 1
    fi

    log_info "Found skills at: $SKILLS_DIR"

    if [ -f "$SKILLS_DIR/install-skills.sh" ]; then
        log_info "Running skills installer..."
        if bash "$SKILLS_DIR/install-skills.sh" "$SKILLS_DIR/offline-skills"; then
            log_ok "Offline skills installed successfully"
        else
            log_warn "Some skills may have failed to install"
        fi
    else
        log_error "Skills installer not found: $SKILLS_DIR/install-skills.sh"
        exit 1
    fi

    echo ""
    echo "============================================================================="
    echo "  Skills Installation Complete"
    echo "============================================================================="
    echo ""
    echo "  Installed skills to: ~/.claude/skills/"
    echo ""
    echo "  To use skills, simply mention them in Claude Code:"
    echo "    Example: 'Create a Word document with...'"
    echo "    Example: 'Design a frontend for...'"
    echo ""
    echo "============================================================================="
    exit 0
fi

# ---------------------------------------------------------------------------
# Step 1: Determine Offline Packages Location (Normal Mode)
# ---------------------------------------------------------------------------

# For normal mode: detect existing installation first (interactive prompts)
if [ "$CONFIG_ONLY" = false ] && [ "$SKILLS_ONLY" = false ]; then
    echo "This script will set up Claude Code on your account."
    echo "Automatic mirror source detection is enabled for better download speed."
    echo ""

    # 检测是否已安装
    echo "Checking for existing installation..."
    # Disable 'set -e' temporarily for this function call since it returns 1 when no installation found
    set +e
    EXISTING_INSTALL=$(detect_existing_installation 2>&1)
    DETECT_EXIT=$?
    set -e

    if [ -n "$EXISTING_INSTALL" ]; then
        echo ""
        log_warn "Detected existing Claude Code installation:"
        echo "$EXISTING_INSTALL"
        echo ""
        echo "Options:"
        echo "  1) Reinstall / Update (backup existing config and reinstall)"
        echo "  2) Uninstall (completely remove Claude Code)"
        echo "  3) Continue anyway (may cause conflicts)"
        echo "  4) Exit"
        echo ""
        if [ "$ASSUME_YES" = true ] || [ "$NON_INTERACTIVE" = true ] || [ ! -t 0 ]; then
            choice="1"
            echo "Select option [1-4]: 1 (auto, non-interactive)"
        else
            read -p "Select option [1-4]: " -r choice
        fi

        case $choice in
            1)
                echo ""
                log_info "Backing up existing configuration and reinstalling..."
                # 创建备份
                BACKUP_DIR="$HOME/.claude-backup-$(date +%Y%m%d_%H%M%S)"
                mkdir -p "$BACKUP_DIR"

                if [ -d "$HOME/.claude" ]; then
                    cp -r "$HOME/.claude" "$BACKUP_DIR/" 2>/dev/null || true
                    log_ok "Backed up ~/.claude to $BACKUP_DIR"
                fi
                if [ -f "$HOME/.claude.json" ]; then
                    cp "$HOME/.claude.json" "$BACKUP_DIR/" 2>/dev/null || true
                fi

                # 清理旧的配置块（保留配置目录，会被覆盖）
                if [ -f "$BASHRC" ]; then
                    sed -i "/$SETUP_START/,/$SETUP_END/d" "$BASHRC" 2>/dev/null || true
                    sed -i "/$NODE_START/,/$NODE_END/d" "$BASHRC" 2>/dev/null || true
                fi
                ;;
            2)
                echo ""
                uninstall_claude_code
                exit 0
                ;;
            3)
                log_warn "Continuing with existing installation (may cause conflicts)..."
                ;;
            4|*)
                log_info "Exiting. No changes made."
                exit 0
                ;;
        esac
        echo ""
    fi
fi

echo "Step 1/7: Locating Claude Code packages..."

# Helper function to check if path contains valid packages (new or old format)
is_valid_package_path() {
    local path="$1"
    # New format: package.json with file: references + .tgz files
    if [ -f "$path/package.json" ] && ls "$path"/*.tgz >/dev/null 2>&1; then
        return 0
    fi
    # Pre-installed node_modules: any known claude entry point
    # (.bin launcher, native binary, Node.js wrappers, or legacy cli.js)
    if [ -r "$path/node_modules/.bin/claude" ] \
        || [ -r "$path/node_modules/@anthropic-ai/claude-code/bin/claude.exe" ] \
        || [ -r "$path/node_modules/@anthropic-ai/claude-code/cli-wrapper.cjs" ] \
        || [ -r "$path/node_modules/@anthropic-ai/claude-code/cli.js" ]; then
        return 0
    fi
    return 1
}

if [ -n "$OFFLINE_PATH" ]; then
    # User specified path
    OFFLINE_PACKAGES="$OFFLINE_PATH"
    if ! is_valid_package_path "$OFFLINE_PACKAGES"; then
        log_error "Cannot find valid Claude Code packages at: $OFFLINE_PACKAGES"
        log_info "Expected: package.json with .tgz files OR node_modules with claude installed"
        exit 1
    fi
    log_ok "Using specified offline packages: $OFFLINE_PACKAGES"
elif [ "$AUTO_DOWNLOAD" = true ] || [ "$FORCE_DOWNLOAD" = true ]; then
    # Auto-download mode
    OFFLINE_PACKAGES="$USER_CLAUDE_DIR/offline-packages"
    
    if [ "$FORCE_DOWNLOAD" = true ] || ! is_valid_package_path "$OFFLINE_PACKAGES"; then
        if ! download_offline_packages "$OFFLINE_PACKAGES"; then
            log_error "Failed to download offline packages"
            exit 1
        fi
    else
        log_ok "Using existing downloaded packages"
    fi
else
    # Auto-detect
    OFFLINE_PACKAGES=$(find_offline_packages || true)
    
    if [ -z "$OFFLINE_PACKAGES" ]; then
        log_warn "Offline packages not found in default locations"

        # Non-interactive mode: cannot ask the user; fail with clear guidance
        if [ "$ASSUME_YES" = true ] || [ "$NON_INTERACTIVE" = true ] || [ ! -t 0 ]; then
            log_error "No offline packages found and interactive selection is disabled."
            echo ""
            echo "Run one of:"
            echo "  bash $0 --offline-path /path/to/claude-offline-packages --yes"
            echo "  bash $0 --auto-download --yes"
            exit 1
        fi

        echo ""
        echo "Options:"
        echo "  1) Download from GitHub Release automatically (with mirror detection)"
        echo "  2) Specify offline packages path"
        echo "  3) Install Claude Code directly via npm (requires internet)"
        echo "  4) Exit and manually download"
        echo ""
        read -p "Select option [1-4]: " -r choice
        
        case $choice in
            1)
                OFFLINE_PACKAGES="$USER_CLAUDE_DIR/offline-packages"
                if ! download_offline_packages "$OFFLINE_PACKAGES"; then
                    exit 1
                fi
                ;;
            2)
                read -p "Enter path to offline packages: " -r OFFLINE_PACKAGES
                if ! is_valid_package_path "$OFFLINE_PACKAGES"; then
                    log_error "Invalid path or packages not found"
                    exit 1
                fi
                ;;
            3)
                OFFLINE_PACKAGES="$USER_CLAUDE_DIR/offline-packages"
                if ! install_via_npm_direct "$OFFLINE_PACKAGES"; then
                    exit 1
                fi
                ;;
            4|*)
                log_info "Please download the packages and re-run this script with --offline-path"
                exit 0
                ;;
        esac
    else
        log_ok "Found offline packages at: $OFFLINE_PACKAGES"
    fi
fi

# Convert OFFLINE_PACKAGES to absolute path
OFFLINE_PACKAGES="$(cd "$OFFLINE_PACKAGES" && pwd)"
log_info "Using absolute path: $OFFLINE_PACKAGES"

# Handle new format: .tgz packages need to be installed
if [ -f "$OFFLINE_PACKAGES/package.json" ] && ls "$OFFLINE_PACKAGES"/*.tgz >/dev/null 2>&1; then
    log_info "Detected .tgz package format"
    
    # Check if already installed
    if [ ! -d "$OFFLINE_PACKAGES/node_modules/@anthropic-ai" ]; then
        if ! command_exists npm; then
            log_error "This package must be assembled with npm, but Node.js/npm is not installed."
            log_info "Use a pre-assembled package (containing node_modules/) or install Node.js >= 18 first."
            exit 1
        fi
        if ! require_network_or_fail "assemble packages with npm"; then
            exit 1
        fi
        log_info "Installing packages from .tgz files..."
        cd "$OFFLINE_PACKAGES"
        run_npm_with_timeout 240 install --production 2>/dev/null || run_npm_with_timeout 240 ci --production 2>/dev/null || {
            log_warn "Standard npm install failed, trying alternative..."
            # Extract and install manually
            for tgz in "$OFFLINE_PACKAGES"/*.tgz; do
                [ -f "$tgz" ] || continue
                run_npm_with_timeout 120 install "$tgz" --production 2>/dev/null || true
            done
        }
    fi
fi

# Fix permissions for the package files (also repairs exec bits lost when the
# archive was extracted with Windows tools such as Explorer/7z)
log_info "Fixing permissions..."
chmod -R +x "$OFFLINE_PACKAGES/node_modules/.bin/" 2>/dev/null || true
chmod -R +x "$OFFLINE_PACKAGES/node_modules/@anthropic-ai/claude-code/" 2>/dev/null || true
if [ -f "$OFFLINE_PACKAGES/node_modules/@anthropic-ai/claude-code/cli.js" ]; then
    chmod +x "$OFFLINE_PACKAGES/node_modules/@anthropic-ai/claude-code/cli.js"
fi
for _plat_bin in "$OFFLINE_PACKAGES"/node_modules/@anthropic-ai/claude-code-*/claude*; do
    if [ -f "$_plat_bin" ]; then
        chmod +x "$_plat_bin" 2>/dev/null || true
    fi
done

# Verify which runtime this package can use (native binary vs Node.js wrapper)
log_info "Verifying Claude Code binary..."
RUNTIME_MODE="$(detect_runtime_mode "$OFFLINE_PACKAGES")"
NEED_NODE=false
case "$RUNTIME_MODE" in
    native)
        log_ok "Native binary detected, Node.js optional (bin/claude.exe)"
        ;;
    platform)
        log_ok "Native binary detected, Node.js optional (platform package binary)"
        ;;
    node)
        log_warn "No runnable native binary found for this platform"
        log_info "The package will fall back to the Node.js wrapper (requires Node.js at runtime)"
        NEED_NODE=true
        ;;
esac

# Always rebuild node_modules/.bin/claude as a REAL launcher script (never a
# symlink). This repairs packages whose symlinks were lost during extraction
# with Windows tools, and points the launcher at the best available binary.
set +e
rebuild_claude_launcher "$OFFLINE_PACKAGES"
LAUNCHER_RC=$?
set -e
if [ "$LAUNCHER_RC" -eq 1 ]; then
    exit 1
elif [ "$LAUNCHER_RC" -eq 2 ]; then
    NEED_NODE=true
fi

# Set binary path
if [ -r "$OFFLINE_PACKAGES/node_modules/.bin/claude" ]; then
    CLAUDE_BIN="$OFFLINE_PACKAGES/node_modules/.bin/claude"
else
    CLAUDE_BIN="$OFFLINE_PACKAGES/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
fi

export PATH="$OFFLINE_PACKAGES/node_modules/.bin:$PATH"
echo ""

# ---------------------------------------------------------------------------
# Step 2: Runtime Environment (Node.js is OPTIONAL for native binaries)
# ---------------------------------------------------------------------------
echo "Step 2/7: Ensuring runtime environment..."

if [ "$NEED_NODE" = true ]; then
    # Only the Node.js wrapper fallback truly requires Node.js (>= 18)
    log_warn "This package requires Node.js (Node.js wrapper fallback)"
    if ! ensure_nodejs; then
        exit 1
    fi
else
    # Native binary present: Node.js is optional, offer but skip by default
    if command_exists node && check_nodejs_requirement; then
        log_ok "Node.js $(node --version) available (optional)"
    elif confirm "Install Node.js anyway? (optional; only needed for npm-based tools and the wrapper fallback)" n; then
        if require_network_or_fail "install Node.js"; then
            if install_nodejs; then
                log_ok "Node.js installed (optional)"
            else
                log_warn "Node.js installation failed; continuing with the native binary"
            fi
        else
            log_warn "Skipping optional Node.js installation (offline)"
        fi
    else
        log_info "Skipping Node.js installation (not required for the native binary)"
    fi
fi

# Clean up old module configuration (if exists)
if [ -f "$BASHRC" ]; then
    if grep -q "$NODE_START" "$BASHRC" 2>/dev/null; then
        log_info "Removing old module system configuration..."
        sed -i "/$NODE_START/,/$NODE_END/d" "$BASHRC"
    fi
fi

echo ""

# ---------------------------------------------------------------------------
# Step 3: Create Directory Structure
# ---------------------------------------------------------------------------
echo "Step 3/7: Creating ~/.claude/ directory structure..."

mkdir -p "$USER_CLAUDE_DIR"
mkdir -p "$USER_CLAUDE_DIR/tmp"
mkdir -p "$USER_CLAUDE_DIR/backups"
mkdir -p "$USER_CLAUDE_DIR/plugins"

log_ok "Directories created"
echo ""

# ---------------------------------------------------------------------------
# Step 4: Generate Config Files
# ---------------------------------------------------------------------------
echo "Step 4/7: Generating configuration files..."

# Generate config files using shared functions
generate_settings_json
generate_config_json
generate_claude_json
generate_claude_wrapper

# Add wrapper to PATH (in .bashrc) - only in normal mode, not --config-only
CLAUDE_WRAPPER="$USER_CLAUDE_DIR/claude-wrapper.sh"
if ! grep -q "claude-wrapper" "$BASHRC" 2>/dev/null; then
    cat >> "$BASHRC" << WRAPPER_ALIAS

# Claude Code wrapper for bypassing region checks
alias claude='bash $CLAUDE_WRAPPER'
WRAPPER_ALIAS
    log_ok "Added claude wrapper alias to .bashrc"
fi

generate_clean_tmp

echo ""

# ---------------------------------------------------------------------------
# Step 5: Update Shell Config (PATH + TMPDIR)
# ---------------------------------------------------------------------------
echo "Step 5/7: Updating shell configuration..."

touch "$BASHRC"

# Remove old configuration blocks (if exist)
if grep -q "$SETUP_START" "$BASHRC" 2>/dev/null; then
    log_info "Updating existing PATH/TMPDIR configuration..."
    sed -i "/$SETUP_START/,/$SETUP_END/d" "$BASHRC"
fi

# Add new configuration block
cat >> "$BASHRC" << SETUPBLOCK

# >>> CLAUDE_CODE_SETUP >>>
# Claude Code shared offline packages (added by setup-claude-code.sh)
export PATH="${OFFLINE_PACKAGES}/node_modules/.bin:\$PATH"
export TMPDIR="\$HOME/.claude/tmp"
# Claude Code setup - do not edit above this marker
# <<< CLAUDE_CODE_SETUP <<<
SETUPBLOCK

log_ok "PATH and TMPDIR exports added to .bashrc"
echo ""

# ---------------------------------------------------------------------------
# Step 6: Verification
# ---------------------------------------------------------------------------
echo "Step 6/7: Verifying setup..."

# Export for current session
export PATH="${OFFLINE_PACKAGES}/node_modules/.bin:$PATH"
export TMPDIR="$HOME/.claude/tmp"

# Verify claude command works
if command -v claude >/dev/null 2>&1; then
    CLAUDE_VER=$(claude --version 2>/dev/null || echo "(version check failed)")
    log_ok "claude command available: $CLAUDE_VER"
else
    log_warn "claude command not found in PATH yet. You may need to open a new terminal."
fi

# Verify config files
echo ""
echo "Checking configuration files..."
for f in "$USER_CLAUDE_DIR/settings.json" "$USER_CLAUDE_DIR/config.json" "$HOME/.claude.json"; do
    if [ -f "$f" ]; then
        log_ok "$(basename "$f") exists"
    else
        log_warn "$(basename "$f") missing"
    fi
done

echo ""

# ---------------------------------------------------------------------------
# Step 6b: Install Offline Skills (Optional)
# ---------------------------------------------------------------------------
echo "Step 6b/7: Installing offline skills..."

SKILLS_DIR="${OFFLINE_PACKAGES}/skills"
if [ -d "$SKILLS_DIR" ] && [ -f "$SKILLS_DIR/install-skills.sh" ]; then
    log_info "Found offline skills package"
    echo ""
    echo "Offline skills are plugins that enhance Claude Code's capabilities"
    echo "without requiring internet connection."
    echo ""
    echo "Available skills categories:"
    echo "  - Document Processing: docx, pdf, pptx, xlsx"
    echo "  - Design: frontend-design, algorithmic-art, canvas-design"
    echo "  - Testing: webapp-testing"
    echo "  - Tools: skill-creator"
    echo "  - Plugins: superpowers, everything-claude-code (ECC), gitlab, clangd-lsp, python-lsp"
    echo ""

    # Check for jq dependency (required by install-skills.sh)
    if ! ensure_jq_for_skills "$OFFLINE_PACKAGES"; then
        log_error "jq is unavailable and could not be set up automatically"
        log_info "Please install jq manually and run: bash $SKILLS_DIR/install-skills.sh $SKILLS_DIR/offline-skills"
        SKILLS_DIR=""  # Skip installation
    fi

    if [ -n "$SKILLS_DIR" ]; then
        if confirm "Install offline skills?" y; then
            log_info "Running skills installer..."
            if bash "$SKILLS_DIR/install-skills.sh" "$SKILLS_DIR/offline-skills"; then
                log_ok "Offline skills installed successfully"
            else
                log_error "Skills installation failed!"
                log_info "Check the output above for errors"
                log_info "You can retry with: bash $SKILLS_DIR/install-skills.sh $SKILLS_DIR/offline-skills"
            fi
        else
            log_info "Skills installation skipped"
            log_info "You can install later by running:"
            log_info "  bash $SKILLS_DIR/install-skills.sh $SKILLS_DIR/offline-skills"
        fi
    fi
else
    log_info "No offline skills package found in the bundle"
    log_info "Skills can be downloaded separately if needed"
fi

echo ""

# ---------------------------------------------------------------------------
# Step 7: Summary
# ---------------------------------------------------------------------------
echo "Step 7/7: Setup complete!"
echo ""
echo "============================================================================="
echo "  SETUP SUMMARY"
echo "============================================================================="
echo ""
echo "  Configured:"
if [ "$NEED_NODE" = true ]; then
    echo "    - Node.js environment (>= 18) with automatic mirror detection"
else
    echo "    - Native Claude Code binary (standalone, Node.js NOT required)"
fi
echo "    - Offline packages at: $OFFLINE_PACKAGES"
echo "    - ~/.claude/ directory structure"
echo "    - ~/.claude/settings.json (with placeholder values)"
echo "    - ~/.claude/config.json"
echo "    - ~/.claude.json (onboarding complete)"
echo "    - PATH and TMPDIR in .bashrc"
echo "    - ~/.claude/clean-tmp.sh (cleanup utility)"

# Check if skills are installed
if [ -d "$HOME/.claude/skills" ] && [ "$(ls -A "$HOME/.claude/skills" 2>/dev/null)" ]; then
    echo "    - Offline skills ($(ls -1 "$HOME/.claude/skills" 2>/dev/null | wc -l) skills installed)"
else
    echo "    - Offline skills (not installed - see skills/ directory in the package)"
fi
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
echo "  REGION RESTRICTION BYPASS"
echo "============================================================================="
echo ""
echo "  This script has configured Claude Code to bypass region restrictions:"
echo ""
echo "  ✓ Onboarding flow is skipped (hasCompletedOnboarding: true)"
echo "  ✓ Telemetry is disabled"
echo "  ✓ Auto-updater is disabled"
echo "  ✓ Region check is bypassed"
echo "  ✓ Wrapper script created: ~/.claude/claude-wrapper.sh"
echo ""
echo "  IMPORTANT: You should use 'claude' command directly after setup."
echo "  The wrapper script will automatically set necessary environment variables."
echo ""
echo "  If you still encounter region issues, ensure you have configured:"
echo "    - ANTHROPIC_BASE_URL: Your API endpoint (proxy if needed)"
echo "    - ANTHROPIC_API_KEY: Your API key"
echo ""
echo "============================================================================="
echo "  NEXT STEPS"
echo "============================================================================="
echo ""
echo "  1. Edit ~/.claude/settings.json with your API key and base URL"
echo "  2. Open a new terminal (or run: source ~/.bashrc)"
echo "  3. Verify: claude --version"
echo "  4. Verify: echo \$TMPDIR  (should show ~/.claude/tmp)"
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
echo "  Recommended: Run this periodically to reclaim disk space."
echo ""
echo "============================================================================="
echo "  MIRROR SOURCES"
echo "============================================================================="
echo ""
echo "  The script automatically detected and used the fastest mirror sources."
echo "  You can override these with environment variables:"
echo ""
echo "    export NODE_MIRROR=https://your-node-mirror.com/mirrors/node/"
echo "    export NPM_MIRROR=https://your-npm-registry.com"
echo "    export GITHUB_MIRROR=https://your-github-mirror.com"
echo ""
echo "============================================================================="
echo "  To re-run this script safely (idempotent):"
echo "    bash $0"
echo ""
echo "  To use specific offline packages:"
echo "    bash $0 --offline-path /path/to/packages"
echo ""
echo "  To auto-download from GitHub with mirror detection:"
echo "    bash $0 --auto-download"
echo ""
echo "============================================================================="
