#!/usr/bin/env bash
# =============================================================================
# Claude Code Offline Upgrader
# =============================================================================
# Upgrades an existing offline installation (created by setup-claude-code.sh)
# to a newer offline package — no internet required.
#
# The upgrade is done IN PLACE: the new package replaces the current package
# directory, so the PATH entries in ~/.bashrc keep working unchanged.
# A backup of the old package is kept under ~/.claude/backups/ for rollback.
#
# Usage:
#   bash update-offline.sh <new-package.tar.gz | new-package-dir> [options]
#
# Options:
#   --update-skills    Re-install previously installed skills from the new
#                      bundle (default behavior)
#   --skills a,b,c     After upgrading, install exactly these skills/plugins
#   --skip-skills      Do not touch skills at all
#   --target DIR       Package directory to upgrade (default: auto-detect
#                      from the PATH block in ~/.bashrc)
#   --force            Upgrade even if the version looks identical
#   --rollback [DIR]   Restore a previous backup (default: most recent)
#   --list-backups     List available backups and exit
#   --yes, -y          Non-interactive (assume yes)
#   -h, --help         Show this help
#
# Examples:
#   bash update-offline.sh claude-offline-packages-linux-x86_64.tar.gz
#   bash update-offline.sh ./claude-offline-packages --skills docx,pdf,superpowers
#   bash update-offline.sh --rollback
# =============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source common utilities (if available); fall back to local definitions
if [ -f "${SCRIPT_DIR}/skills/lib/common.sh" ]; then
    source "${SCRIPT_DIR}/skills/lib/common.sh"
fi
if ! type log_info >/dev/null 2>&1; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
    log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
    log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
    log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
    log_error(){ echo -e "${RED}[ERROR]${NC} $1" >&2; }
fi

USER_CLAUDE_DIR="${HOME}/.claude"
BACKUP_DIR="${USER_CLAUDE_DIR}/backups"
BASHRC="${HOME}/.bashrc"
SETUP_START="# >>> CLAUDE_CODE_SETUP >>>"

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

die() { log_error "$1"; exit 1; }

confirm_default_yes() {
    local prompt="$1"
    if [ "$ASSUME_YES" = true ] || [ ! -t 0 ]; then
        echo "$prompt [Y/n]: y (auto)"
        return 0
    fi
    read -p "$prompt [Y/n]: " -n 1 -r answer || answer=""
    echo
    [ -z "$answer" ] || [[ "$answer" =~ ^[Yy]$ ]]
}

# Read a "version" field from a package-info.json without requiring jq
read_pkg_version() {
    local info_file="$1/package-info.json"
    [ -f "$info_file" ] || { echo "unknown"; return; }
    if command -v jq >/dev/null 2>&1; then
        jq -r '.version // "unknown"' "$info_file" 2>/dev/null || echo "unknown"
    else
        grep -o '"version"[[:space:]]*:[[:space:]]*"[^"]*"' "$info_file" 2>/dev/null \
            | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || echo "unknown"
    fi
}

# Locate the currently installed package directory from the PATH block that
# setup-claude-code.sh wrote into ~/.bashrc:
#   export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
detect_current_package_dir() {
    [ -f "$BASHRC" ] || return 1
    local bin_path
    bin_path=$(sed -n "/^export PATH=\"\(.*\)\/node_modules\/\.bin:.*\"$/p" "$BASHRC" | head -1 \
        | sed 's/^export PATH="//; s/\/node_modules\/\.bin:.*$//')
    if [ -n "$bin_path" ] && [ -d "$bin_path/node_modules/@anthropic-ai/claude-code" ]; then
        echo "$bin_path"
        return 0
    fi
    return 1
}

# Validate that a directory really is an offline package
validate_package_dir() {
    local dir="$1"
    [ -d "$dir/node_modules/@anthropic-ai/claude-code" ] || return 1
    [ -f "$dir/package-info.json" ] || return 1
    return 0
}

list_backups() {
    echo "Available backups in ${BACKUP_DIR}:"
    if [ -d "$BACKUP_DIR" ]; then
        ls -1dt "$BACKUP_DIR"/claude-offline-packages-* 2>/dev/null | while read -r b; do
            echo "  $(basename "$b")  (version: $(read_pkg_version "$b"))"
        done || true
    fi
}

# ---------------------------------------------------------------------------
# Argument parsing
# ---------------------------------------------------------------------------
NEW_PACKAGE=""
TARGET_DIR=""
SKILLS_MODE="update"   # update | only | skip
SKILLS_CSV=""
FORCE=false
ROLLBACK=false
ROLLBACK_DIR=""
LIST_BACKUPS=false
ASSUME_YES=false

while [[ $# -gt 0 ]]; do
    case "$1" in
        --update-skills) SKILLS_MODE="update"; shift ;;
        --skills)        SKILLS_MODE="only"; SKILLS_CSV="${2:?--skills requires a comma-separated list}"; shift 2 ;;
        --skills=*)      SKILLS_MODE="only"; SKILLS_CSV="${1#*=}"; shift ;;
        --skip-skills)   SKILLS_MODE="skip"; shift ;;
        --target)        TARGET_DIR="${2:?--target requires a directory}"; shift 2 ;;
        --target=*)      TARGET_DIR="${1#*=}"; shift ;;
        --force)         FORCE=true; shift ;;
        --rollback)
            ROLLBACK=true; shift
            # Optional backup directory argument (only if it does not start with --)
            if [[ $# -gt 0 && "$1" != --* ]]; then ROLLBACK_DIR="$1"; shift; fi
            ;;
        --list-backups)  LIST_BACKUPS=true; shift ;;
        --yes|-y)        ASSUME_YES=true; shift ;;
        --help|-h)
            sed -n '2,40p' "$0"
            exit 0 ;;
        -*)
            die "Unknown option: $1 (see --help)" ;;
        *)
            [ -z "$NEW_PACKAGE" ] && NEW_PACKAGE="$1" || die "Unexpected argument: $1"
            shift ;;
    esac
done

echo "============================================================================="
echo "  Claude Code Offline Upgrader"
echo "============================================================================="
echo ""

# ---------------------------------------------------------------------------
# Mode: list backups
# ---------------------------------------------------------------------------
if [ "$LIST_BACKUPS" = true ]; then
    list_backups
    exit 0
fi

# ---------------------------------------------------------------------------
# Resolve the target (current installation) directory
# ---------------------------------------------------------------------------
if [ -z "$TARGET_DIR" ]; then
    if ! TARGET_DIR=$(detect_current_package_dir); then
        die "Could not auto-detect the current package directory from ~/.bashrc.
Re-run with --target /path/to/claude-offline-packages"
    fi
fi
TARGET_DIR="$(cd "$TARGET_DIR" && pwd)"
validate_package_dir "$TARGET_DIR" \
    || die "Target does not look like an offline package: $TARGET_DIR"

CURRENT_VERSION=$(read_pkg_version "$TARGET_DIR")
log_info "Current package: $TARGET_DIR"
log_info "Current version: $CURRENT_VERSION"

# ---------------------------------------------------------------------------
# Mode: rollback
# ---------------------------------------------------------------------------
if [ "$ROLLBACK" = true ]; then
    if [ -z "$ROLLBACK_DIR" ]; then
        ROLLBACK_DIR=$(ls -1dt "$BACKUP_DIR"/claude-offline-packages-* 2>/dev/null | head -1 || true)
        [ -n "$ROLLBACK_DIR" ] || die "No backups found in $BACKUP_DIR"
        log_info "Using most recent backup: $ROLLBACK_DIR"
    fi
    validate_package_dir "$ROLLBACK_DIR" \
        || die "Backup does not look like an offline package: $ROLLBACK_DIR"
    BACKUP_VERSION=$(read_pkg_version "$ROLLBACK_DIR")
    echo ""
    log_warn "This will RESTORE version $BACKUP_VERSION over the current $CURRENT_VERSION"
    confirm_default_yes "Continue with rollback?" || { log_info "Rollback cancelled"; exit 0; }

    FAILED_DIR="${BACKUP_DIR}/.rollback-failed-$(date +%Y%m%d%H%M%S)"
    if ! mv "$TARGET_DIR" "$FAILED_DIR" 2>/dev/null; then
        # mv can fail on some platforms (e.g. file handles held open) —
        # fall back to copy+remove, same as the upgrade path
        cp -a "$TARGET_DIR" "$FAILED_DIR"
        rm -rf "$TARGET_DIR"
    fi
    if cp -a "$ROLLBACK_DIR" "$TARGET_DIR"; then
        rm -rf "$FAILED_DIR"
        log_ok "Restored $BACKUP_VERSION to $TARGET_DIR"
    else
        rm -rf "$TARGET_DIR" 2>/dev/null || true
        mv "$FAILED_DIR" "$TARGET_DIR" 2>/dev/null || cp -a "$FAILED_DIR" "$TARGET_DIR"
        die "Rollback copy failed; original installation was restored"
    fi

    # Re-run the restored package's own setup to repair configs/launcher
    if [ -f "$TARGET_DIR/setup-claude-code.sh" ]; then
        log_info "Re-running setup for the restored version..."
        SKIP_SKILLS_INSTALL=1 bash "$TARGET_DIR/setup-claude-code.sh" \
            --offline-path "$TARGET_DIR" --yes || \
            log_warn "Setup script reported errors; please review the output above"
    fi
    echo ""
    log_ok "Rollback complete: now on version $(read_pkg_version "$TARGET_DIR")"
    exit 0
fi

# ---------------------------------------------------------------------------
# Mode: upgrade — resolve and validate the new package
# ---------------------------------------------------------------------------
[ -n "$NEW_PACKAGE" ] || die "No new package given. Usage: bash update-offline.sh <package.tar.gz|dir> [options]"

STAGING_DIR=""
cleanup_staging() {
    # must always succeed: a failing EXIT trap would mask the script's exit code
    if [ -n "$STAGING_DIR" ]; then rm -rf "$STAGING_DIR"; fi
    return 0
}
trap cleanup_staging EXIT

if [ -d "$NEW_PACKAGE" ]; then
    NEW_PKG_DIR="$(cd "$NEW_PACKAGE" && pwd)"
    # If the directory contains a single top-level claude-offline-packages*
    # folder (freshly extracted archive layout), descend into it
    if [ ! -d "$NEW_PKG_DIR/node_modules" ]; then
        nested=$(ls -1d "$NEW_PKG_DIR"/claude-offline-packages* 2>/dev/null | head -1 || true)
        [ -n "$nested" ] && NEW_PKG_DIR="$nested"
    fi
elif [ -f "$NEW_PACKAGE" ]; then
    # Verify checksum when a .sha256 sits next to the archive
    if [ -f "${NEW_PACKAGE}.sha256" ] && command -v sha256sum >/dev/null 2>&1; then
        log_info "Verifying checksum..."
        (cd "$(dirname "$NEW_PACKAGE")" && sha256sum -c "$(basename "${NEW_PACKAGE}.sha256")") \
            || die "Checksum verification FAILED — refusing to install a corrupted package"
        log_ok "Checksum verified"
    else
        log_warn "No .sha256 next to the archive (or sha256sum missing) — skipping checksum verification"
    fi

    log_info "Extracting $NEW_PACKAGE ..."
    STAGING_DIR=$(mktemp -d)
    case "$NEW_PACKAGE" in
        *.tar.gz|*.tgz) tar -xzf "$NEW_PACKAGE" -C "$STAGING_DIR" ;;
        *.zip)
            if command -v unzip >/dev/null 2>&1; then
                unzip -q "$NEW_PACKAGE" -d "$STAGING_DIR"
            else
                die "unzip is required to extract .zip packages"
            fi ;;
        *) die "Unsupported archive format: $NEW_PACKAGE" ;;
    esac
    NEW_PKG_DIR=$(ls -1d "$STAGING_DIR"/claude-offline-packages* 2>/dev/null | head -1 || true)
    [ -n "$NEW_PKG_DIR" ] || die "Archive does not contain a claude-offline-packages* directory"
else
    die "New package not found: $NEW_PACKAGE"
fi

validate_package_dir "$NEW_PKG_DIR" \
    || die "New package is invalid (missing node_modules/@anthropic-ai/claude-code or package-info.json)"

NEW_VERSION=$(read_pkg_version "$NEW_PKG_DIR")
NEW_PLATFORM=$(grep -o '"platform"[[:space:]]*:[[:space:]]*"[^"]*"' "$NEW_PKG_DIR/package-info.json" 2>/dev/null \
    | head -1 | sed 's/.*"\([^"]*\)"$/\1/' || true)
log_info "New package:   $NEW_PKG_DIR"
log_info "New version:   $NEW_VERSION ${NEW_PLATFORM:+($NEW_PLATFORM)}"

# Architecture sanity check: do not install a foreign-arch native binary
MACHINE=$(uname -m)
case "$NEW_PLATFORM" in
    *arm64*)
        case "$MACHINE" in
            aarch64|arm64) ;;
            *) die "This package targets ARM64 but this machine is $MACHINE. Download the x64 package instead." ;;
        esac ;;
esac

if [ "$NEW_VERSION" = "$CURRENT_VERSION" ] && [ "$FORCE" != true ]; then
    log_warn "The new package has the SAME version as the current installation ($CURRENT_VERSION)"
    confirm_default_yes "Upgrade anyway?" || { log_info "Upgrade cancelled"; exit 0; }
fi

echo ""
log_warn "This will upgrade Claude Code: $CURRENT_VERSION -> $NEW_VERSION"
log_info "The old package will be backed up to: $BACKUP_DIR"
confirm_default_yes "Continue with upgrade?" || { log_info "Upgrade cancelled"; exit 0; }

# ---------------------------------------------------------------------------
# Smoke-test the new binary before swapping (best effort)
# ---------------------------------------------------------------------------
NEW_BIN="$NEW_PKG_DIR/node_modules/@anthropic-ai/claude-code/bin/claude.exe"
if [ -f "$NEW_BIN" ]; then
    chmod +x "$NEW_BIN" 2>/dev/null || true
    if BIN_VER=$("$NEW_BIN" --version 2>&1); then
        log_ok "New binary self-test passed: $BIN_VER"
    else
        log_warn "New binary could not be executed here (foreign arch or missing libs); continuing anyway"
    fi
fi

# ---------------------------------------------------------------------------
# Backup + in-place swap
# ---------------------------------------------------------------------------
mkdir -p "$BACKUP_DIR"
BACKUP_PATH="${BACKUP_DIR}/claude-offline-packages-${CURRENT_VERSION}-$(date +%Y%m%d%H%M%S)"

log_info "Backing up current package..."
# mv is instant on the same filesystem; fall back to cp -a across filesystems
if ! mv "$TARGET_DIR" "$BACKUP_PATH" 2>/dev/null; then
    cp -a "$TARGET_DIR" "$BACKUP_PATH"
    rm -rf "$TARGET_DIR"
fi
log_ok "Backup saved: $BACKUP_PATH"

log_info "Installing new package into place..."
if ! cp -a "$NEW_PKG_DIR" "$TARGET_DIR"; then
    log_error "Copy failed — restoring the previous installation"
    rm -rf "$TARGET_DIR"
    mv "$BACKUP_PATH" "$TARGET_DIR"
    die "Upgrade aborted; previous installation restored"
fi

# Fix permissions (archives extracted under Windows tools may lose exec bits)
chmod -R +x "$TARGET_DIR/node_modules/.bin/" 2>/dev/null || true
chmod +x "$TARGET_DIR/setup-claude-code.sh" 2>/dev/null || true
chmod +x "$TARGET_DIR/update-offline.sh" 2>/dev/null || true

# ---------------------------------------------------------------------------
# Re-run the new package's setup (repairs launcher, configs, PATH block)
# ---------------------------------------------------------------------------
if [ -f "$TARGET_DIR/setup-claude-code.sh" ]; then
    log_info "Re-running setup for the new version..."
    if ! SKIP_SKILLS_INSTALL=1 bash "$TARGET_DIR/setup-claude-code.sh" \
            --offline-path "$TARGET_DIR" --yes; then
        log_error "Setup script failed — rolling back"
        rm -rf "$TARGET_DIR"
        mv "$BACKUP_PATH" "$TARGET_DIR"
        die "Upgrade rolled back; previous installation restored"
    fi
else
    log_warn "No setup-claude-code.sh in the new package; skipping reconfiguration"
fi

# ---------------------------------------------------------------------------
# Skills
# ---------------------------------------------------------------------------
case "$SKILLS_MODE" in
    skip)
        log_info "Skipping skills (--skip-skills)"
        ;;
    update|only)
        SKILLS_INSTALLER="$TARGET_DIR/skills/install-skills.sh"
        SKILLS_SRC="$TARGET_DIR/skills/offline-skills"
        if [ -f "$SKILLS_INSTALLER" ] && [ -d "$SKILLS_SRC" ]; then
            if [ "$SKILLS_MODE" = "update" ]; then
                log_info "Updating previously installed skills from the new bundle..."
                bash "$SKILLS_INSTALLER" "$SKILLS_SRC" --update --yes || \
                    log_warn "Skill update reported errors (see above)"
            else
                log_info "Installing selected skills: $SKILLS_CSV"
                bash "$SKILLS_INSTALLER" "$SKILLS_SRC" --only "$SKILLS_CSV" --yes || \
                    log_warn "Skill installation reported errors (see above)"
            fi
        else
            log_warn "The new package contains no offline skills bundle; skills left untouched"
        fi
        ;;
esac

# ---------------------------------------------------------------------------
# Summary
# ---------------------------------------------------------------------------
echo ""
echo "============================================================================="
echo "  UPGRADE COMPLETE"
echo "============================================================================="
echo ""
echo "  Version:  $CURRENT_VERSION -> $(read_pkg_version "$TARGET_DIR")"
echo "  Location: $TARGET_DIR"
echo "  Backup:   $BACKUP_PATH"
echo ""
echo "  Open a NEW terminal (or run: source ~/.bashrc), then verify with:"
echo "    claude --version"
echo ""
echo "  To roll back:"
echo "    bash $TARGET_DIR/update-offline.sh --rollback"
echo ""
