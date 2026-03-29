#!/usr/bin/env bash
# =============================================================================
# Claude Code Version Checker and Update Script
# =============================================================================
# This script checks for new versions of Claude Code and optionally downloads
# the latest offline package from GitHub Releases.
#
# Usage: bash check-update.sh [--check-only] [--download] [--install]
# =============================================================================

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
GITHUB_REPO="DeepTrial/claude-code-offline"
NPM_PACKAGE="@anthropic-ai/claude-code"

# Helper functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_ok() {
    echo -e "${GREEN}[OK]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Get current installed version
get_current_version() {
    if command -v claude >/dev/null 2>&1; then
        claude --version 2>/dev/null | sed 's/claude version //i' || echo "unknown"
    else
        echo "not_installed"
    fi
}

# Get latest version from npm
get_npm_version() {
    curl -s "https://registry.npmjs.org/${NPM_PACKAGE}" | jq -r '.["dist-tags"].latest' 2>/dev/null || echo ""
}

# Get latest version from GitHub Release
get_github_version() {
    curl -s "https://api.github.com/repos/${GITHUB_REPO}/releases/latest" | jq -r '.tag_name' 2>/dev/null | sed 's/^v//' || echo ""
}

# Compare versions
# Returns: 0 if equal, 1 if v1 > v2, 2 if v1 < v2
compare_versions() {
    local v1="$1"
    local v2="$2"
    
    if [ "$v1" = "$v2" ]; then
        return 0
    fi
    
    # Use sort -V for version comparison
    local higher=$(printf "%s\n%s" "$v1" "$v2" | sort -V | tail -1)
    
    if [ "$higher" = "$v1" ]; then
        return 1  # v1 > v2
    else
        return 2  # v1 < v2
    fi
}

# Download latest release
download_latest() {
    local version="$1"
    local download_url="https://github.com/${GITHUB_REPO}/releases/download/v${version}/claude-offline-packages.tar.gz"
    local output_file="claude-offline-packages-v${version}.tar.gz"
    
    log_info "Downloading Claude Code v${version}..."
    log_info "URL: ${download_url}"
    
    if command -v wget >/dev/null 2>&1; then
        wget --progress=bar:force -O "$output_file" "$download_url"
    elif command -v curl >/dev/null 2>&1; then
        curl -fsSL --progress-bar -o "$output_file" "$download_url"
    else
        log_error "Neither wget nor curl is available"
        return 1
    fi
    
    log_ok "Downloaded to: $output_file"
    
    # Verify checksum if available
    local checksum_url="https://github.com/${GITHUB_REPO}/releases/download/v${version}/claude-offline-packages.tar.gz.sha256"
    local checksum_file="${output_file}.sha256"
    
    if curl -fsSL -o "$checksum_file" "$checksum_url" 2>/dev/null; then
        log_info "Verifying checksum..."
        if sha256sum -c "$checksum_file" 2>/dev/null; then
            log_ok "Checksum verified"
        else
            log_warn "Checksum verification failed"
        fi
    fi
    
    echo "$output_file"
}

# Install downloaded package
install_package() {
    local package_file="$1"
    
    log_info "Installing package: $package_file"
    
    # Extract
    local extract_dir=$(mktemp -d)
    tar -xzf "$package_file" -C "$extract_dir"
    
    # Run setup
    if [ -f "$extract_dir/claude-offline-packages/setup-claude-code.sh" ]; then
        bash "$extract_dir/claude-offline-packages/setup-claude-code.sh"
    else
        log_error "Setup script not found in package"
        return 1
    fi
    
    # Cleanup
    rm -rf "$extract_dir"
}

# Main check function
check_updates() {
    echo "============================================================================="
    echo "  Claude Code Version Checker"
    echo "============================================================================="
    echo ""
    
    log_info "Checking for updates..."
    
    # Get versions
    local current_version=$(get_current_version)
    local npm_version=$(get_npm_version)
    local github_version=$(get_github_version)
    
    echo ""
    echo "Version Information:"
    echo "  Current installed: ${current_version}"
    echo "  Latest (npm):      ${npm_version:-Unable to check}"
    echo "  Latest (GitHub):   ${github_version:-Unable to check}"
    echo ""
    
    # Check if update available
    if [ "$current_version" = "not_installed" ]; then
        log_warn "Claude Code is not installed"
        
        if [ -n "$github_version" ]; then
            echo ""
            read -p "Download and install latest version (v${github_version})? [Y/n]: " -n 1 -r
            echo
            if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                local downloaded_file=$(download_latest "$github_version")
                install_package "$downloaded_file"
            fi
        fi
        return
    fi
    
    if [ -n "$npm_version" ] && [ "$npm_version" != "$current_version" ]; then
        compare_versions "$npm_version" "$current_version"
        local cmp_result=$?
        
        if [ $cmp_result -eq 2 ]; then
            log_warn "New version available: v${npm_version} (current: v${current_version})"
            
            if [ -n "$github_version" ] && [ "$github_version" = "$npm_version" ]; then
                echo ""
                echo "Options:"
                echo "  1) Download offline package from GitHub Releases"
                echo "  2) Install directly via npm"
                echo "  3) Skip for now"
                echo ""
                read -p "Select option [1-3]: " -r choice
                
                case $choice in
                    1)
                        local downloaded_file=$(download_latest "$github_version")
                        read -p "Install downloaded package? [Y/n]: " -n 1 -r
                        echo
                        if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                            install_package "$downloaded_file"
                        fi
                        ;;
                    2)
                        log_info "Installing via npm..."
                        npm install -g "${NPM_PACKAGE}@${npm_version}"
                        log_ok "Installation complete"
                        ;;
                    3|*)
                        log_info "Update skipped"
                        ;;
                esac
            else
                echo ""
                log_info "GitHub release not yet available for v${npm_version}"
                read -p "Install directly via npm? [Y/n]: " -n 1 -r
                echo
                if [[ ! $REPLY =~ ^[Nn]$ ]]; then
                    npm install -g "${NPM_PACKAGE}@${npm_version}"
                    log_ok "Installation complete"
                fi
            fi
        else
            log_ok "You have the latest version (v${current_version})"
        fi
    else
        log_ok "You have the latest version (v${current_version})"
    fi
}

# Parse arguments
CHECK_ONLY=false
AUTO_DOWNLOAD=false
AUTO_INSTALL=false

while [[ $# -gt 0 ]]; do
    case $1 in
        --check-only)
            CHECK_ONLY=true
            shift
            ;;
        --download)
            AUTO_DOWNLOAD=true
            shift
            ;;
        --install)
            AUTO_DOWNLOAD=true
            AUTO_INSTALL=true
            shift
            ;;
        --help|-h)
            echo "Usage: $0 [OPTIONS]"
            echo ""
            echo "Options:"
            echo "  --check-only   Only check for updates, don't download or install"
            echo "  --download     Download latest version if available"
            echo "  --install      Download and install latest version"
            echo "  --help, -h     Show this help message"
            echo ""
            echo "Examples:"
            echo "  $0                    # Interactive mode"
            echo "  $0 --check-only       # Just check versions"
            echo "  $0 --download         # Download if update available"
            echo "  $0 --install          # Download and install if update available"
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            exit 1
            ;;
    esac
done

# Run check
check_updates
