#!/usr/bin/env bash
# =============================================================================
# Claude Code Skills Installer for Offline Deployment
# =============================================================================
# Installs offline-compatible skills to the local Claude Code configuration
#
# Usage: bash install-skills.sh [skills_dir]
# Default: ./offline-skills/
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SKILLS_SOURCE="${1:-${SCRIPT_DIR}/offline-skills}"
CLAUDE_SKILLS_DIR="${HOME}/.claude/skills"
CLAUDE_PLUGINS_DIR="${HOME}/.claude/plugins"
MANIFEST_FILE="${SKILLS_SOURCE}/skills-manifest.json"

# Source common utilities (if available); fall back to local definitions so
# this script also works inside shipped packages that do not include lib/
if [ -f "${SCRIPT_DIR}/lib/common.sh" ]; then
    source "${SCRIPT_DIR}/lib/common.sh"
fi

if ! type log_info >/dev/null 2>&1; then
    RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'; BLUE='\033[0;34m'; NC='\033[0m'
    log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
    log_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
    log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
    log_error(){ echo -e "${RED}[ERROR]${NC} $1" >&2; }
fi

# jq command - will be set by init_jq
JQ_CMD=""

# Minimal jq initializer when lib/common.sh (and its init_jq) is unavailable:
# use system jq, otherwise a bundled jq next to this script (skills/bin/<platform>/jq)
if ! type init_jq >/dev/null 2>&1; then
    init_jq() {
        if command -v jq &> /dev/null; then
            JQ_CMD="jq"
            return 0
        fi
        local os arch rel=""
        os="$(uname -s)"
        arch="$(uname -m)"
        case "$os" in
            Linux*)
                case "$arch" in
                    x86_64|amd64)   rel="linux-amd64/jq" ;;
                    aarch64|arm64)  rel="linux-arm64/jq" ;;
                    armv7l|armhf)   rel="linux-armhf/jq" ;;
                esac
                ;;
            Darwin*)
                case "$arch" in
                    x86_64|amd64)   rel="macos-amd64/jq" ;;
                    arm64)          rel="macos-arm64/jq" ;;
                esac
                ;;
            CYGWIN*|MINGW*|MSYS*)
                rel="windows-amd64/jq.exe"
                ;;
        esac
        if [ -n "$rel" ] && [ -x "${SCRIPT_DIR}/bin/${rel}" ]; then
            JQ_CMD="${SCRIPT_DIR}/bin/${rel}"
            return 0
        fi
        return 1
    }
fi

# Check if running in correct directory
check_source() {
    if [ ! -d "$SKILLS_SOURCE" ]; then
        log_error "Skills source directory not found: ${SKILLS_SOURCE}"
        log_info "Please run download-skills.sh first or specify correct path"
        exit 1
    fi
    
    if [ ! -f "$MANIFEST_FILE" ]; then
        log_warn "Manifest file not found, will install all skills in source directory"
    fi
}

# Install a skill or plugin
install_skill() {
    local skill_name="$1"
    local skill_type="${2:-skill}"
    local source_path="${SKILLS_SOURCE}/${skill_name}"

    if [ "$skill_type" = "plugin" ]; then
        # Get marketplace name from manifest (repo field)
        local marketplace_name=""
        if [ -f "$MANIFEST_FILE" ]; then
            marketplace_name=$($JQ_CMD -r ".skills[\"${skill_name}\"].repo // empty" "$MANIFEST_FILE" 2>/dev/null)
        fi

        # Fallback to skill_name if repo not found
        if [ -z "$marketplace_name" ]; then
            marketplace_name="$skill_name"
        fi

        # Create marketplace directory structure
        local marketplace_dir="${CLAUDE_PLUGINS_DIR}/marketplaces/${marketplace_name}"
        local cache_dir="${CLAUDE_PLUGINS_DIR}/cache/${marketplace_name}/${skill_name}"

        log_info "Installing plugin: ${skill_name} (marketplace: ${marketplace_name})"

        # Create marketplace directory if it doesn't exist
        mkdir -p "$marketplace_dir"

        # Create cache directory for this plugin
        mkdir -p "$cache_dir"

        # Copy plugin files to cache directory
        if cp -r "$source_path"/* "$cache_dir/" 2>/dev/null; then
            log_ok "  Plugin files installed to: ${cache_dir}"
        else
            log_warn "  Failed to copy plugin files"
            return 1
        fi

        # Get git commit SHA if available
        local git_sha="unknown"
        if [ -d "$cache_dir/.git" ]; then
            git_sha=$(cd "$cache_dir" && git rev-parse HEAD 2>/dev/null || echo "unknown")
            log_info "  Git commit SHA: ${git_sha}"
        fi

        # Get version from package.json if available
        local version="1.0.0"
        if [ -f "$cache_dir/package.json" ]; then
            version=$($JQ_CMD -r '.version // "1.0.0"' "$cache_dir/package.json" 2>/dev/null || echo "1.0.0")
            log_info "  Version: ${version}"
        fi

        # Register plugin in installed_plugins.json
        register_plugin "$marketplace_name" "$skill_name" "$version" "$git_sha" "$cache_dir"

        # Register marketplace in known_marketplaces.json
        register_marketplace "$marketplace_name" "$marketplace_dir"

        # Copy rules directory separately (plugins cannot distribute rules automatically)
        # Rules should go directly to ~/.claude/rules/<language>/ (not under plugin name)
        if [ -d "$cache_dir/rules" ]; then
            log_info "  Copying rules..."
            # Copy each language subdirectory (common, typescript, python, golang, etc.)
            for rule_dir in "$cache_dir/rules"/*/; do
                if [ -d "$rule_dir" ]; then
                    local rule_subdir
                    rule_subdir=$(basename "$rule_dir")
                    mkdir -p "${HOME}/.claude/rules/${rule_subdir}"
                    cp -r "$rule_dir"/* "${HOME}/.claude/rules/${rule_subdir}/" 2>/dev/null || true
                    log_ok "    Rules: ${rule_subdir}"
                fi
            done
        fi
    else
        local target_path="${CLAUDE_SKILLS_DIR}/${skill_name}"
        log_info "Installing skill: ${skill_name}"

        # Create target directory
        mkdir -p "$target_path"

        # Copy skill files
        if cp -r "$source_path"/* "$target_path/" 2>/dev/null; then
            log_ok "  Installed to: ${target_path}"
        else
            log_warn "  Failed to copy some files"
            return 1
        fi
    fi

    return 0
}

# Register a plugin in installed_plugins.json
register_plugin() {
    local marketplace_name="$1"
    local plugin_name="$2"
    local version="$3"
    local git_sha="$4"
    local install_path="$5"

    local plugins_file="${CLAUDE_PLUGINS_DIR}/installed_plugins.json"
    local plugin_key="${plugin_name}@${marketplace_name}"
    local installed_at=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    log_info "  Registering plugin: ${plugin_key}"

    # Create installed_plugins.json if it doesn't exist
    if [ ! -f "$plugins_file" ]; then
        cat > "$plugins_file" << EOF
{
  "version": 2,
  "plugins": {}
}
EOF
    fi

    # Create temporary file for jq update
    local tmp_file=$(mktemp)

    # Add plugin entry
    $JQ_CMD --arg key "$plugin_key" \
       --arg marketplace "$marketplace_name" \
       --arg plugin "$plugin_name" \
       --arg version "$version" \
       --arg sha "$git_sha" \
       --arg path "$install_path" \
       --arg time "$installed_at" \
       '.plugins[$key] = [{
         "scope": "user",
         "installPath": $path,
         "version": $version,
         "installedAt": $time,
         "lastUpdated": $time,
         "gitCommitSha": $sha,
         "marketplace": $marketplace
       }]' "$plugins_file" > "$tmp_file" && mv "$tmp_file" "$plugins_file"

    log_ok "  Plugin registered in installed_plugins.json"
}

# Register marketplace in known_marketplaces.json
register_marketplace() {
    local marketplace_name="$1"
    local marketplace_dir="$2"
    local marketplaces_file="${CLAUDE_PLUGINS_DIR}/known_marketplaces.json"

    log_info "Registering marketplace: ${marketplace_name}"

    # Create known_marketplaces.json if it doesn't exist
    if [ ! -f "$marketplaces_file" ]; then
        cat > "$marketplaces_file" << EOF
{}
EOF
    fi

    # Create temporary file for jq update
    local tmp_file=$(mktemp)

    # Add marketplace entry
    $JQ_CMD --arg name "$marketplace_name" \
       --arg path "$marketplace_dir" \
       --arg time "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
       '.[$name] = {
         "source": {
           "source": "local",
           "path": $path
         },
         "installLocation": $path,
         "lastUpdated": $time
       }' "$marketplaces_file" > "$tmp_file" && mv "$tmp_file" "$marketplaces_file"

    log_ok "Marketplace registered in known_marketplaces.json"
}

# Install all skills and plugins
install_all_skills() {
    local skills_installed=0
    local plugins_installed=0
    local failed=0

    log_info "Installing skills to: ${CLAUDE_SKILLS_DIR}"
    log_info "Installing plugins to: ${CLAUDE_PLUGINS_DIR}"

    # Ensure target directories exist
    mkdir -p "$CLAUDE_SKILLS_DIR"
    mkdir -p "$CLAUDE_PLUGINS_DIR"

    # Get list of skills from manifest or directory
    if [ -f "$MANIFEST_FILE" ]; then
        # Use manifest - single-pass jq to reduce process overhead
        while IFS=$'\t' read -r skill_name skill_type offline_compatible; do
            # Skip offline-incompatible entries
            if [ "$offline_compatible" = "false" ]; then
                log_warn "Skipping '${skill_name}' - offline_compatible=false"
                continue
            fi

            if [ -d "${SKILLS_SOURCE}/${skill_name}" ]; then
                if install_skill "$skill_name" "$skill_type"; then
                    if [ "$skill_type" = "plugin" ]; then
                        ((plugins_installed++)) || true
                    else
                        ((skills_installed++)) || true
                    fi
                else
                    ((failed++)) || true
                fi
            else
                log_warn "Skill directory not found: ${skill_name}"
                ((failed++)) || true
            fi
        done < <($JQ_CMD -r '.skills | to_entries[] | [.key, .value.type // "skill", (if .value.offline_compatible == null then "true" elif .value.offline_compatible == false then "false" else "true" end)] | @tsv' "$MANIFEST_FILE")
    else
        # Use directory listing - install as skills by default
        for skill_dir in "$SKILLS_SOURCE"/*/; do
            if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
                local skill_name
                skill_name=$(basename "$skill_dir")
                if install_skill "$skill_name" "skill"; then
                    ((skills_installed++)) || true
                else
                    ((failed++)) || true
                fi
            fi
        done
    fi

    log_info "============================="
    log_ok "Installed: ${skills_installed} skills, ${plugins_installed} plugins"
    if [ $failed -gt 0 ]; then
        log_warn "Failed: ${failed} entries"
    fi
}

# Check dependencies for document skills
check_doc_dependencies() {
    log_info "Checking dependencies for document processing skills..."
    
    local deps_missing=()
    
    # Check for docx dependencies
    if ! command -v pandoc &> /dev/null; then
        deps_missing+=("pandoc (for docx skill)")
    fi
    
    if ! command -v libreoffice &> /dev/null && ! command -v soffice &> /dev/null; then
        deps_missing+=("LibreOffice (for docx skill)")
    fi
    
    # Check for pdf dependencies
    if ! python3 -c "import pypdf" 2>/dev/null; then
        deps_missing+=("pypdf Python package (for pdf skill)")
    fi
    
    # Check for pptx dependencies
    if ! python3 -c "import pptx" 2>/dev/null; then
        deps_missing+=("python-pptx Python package (for pptx skill)")
    fi
    
    # Check for xlsx dependencies
    if ! python3 -c "import openpyxl" 2>/dev/null; then
        deps_missing+=("openpyxl Python package (for xlsx skill)")
    fi
    
    # Check for testing dependencies
    if ! command -v playwright &> /dev/null; then
        deps_missing+=("playwright (for webapp-testing skill)")
    fi
    
    if [ ${#deps_missing[@]} -gt 0 ]; then
        log_warn "Some optional dependencies are missing:"
        for dep in "${deps_missing[@]}"; do
            echo "  - ${dep}"
        done
        echo ""
        log_info "You can install these dependencies later if needed."
        log_info "Document skills will work with limited functionality without them."
    else
        log_ok "All document processing dependencies are available"
    fi
}

# Create skills configuration
create_skills_config() {
    local config_file="${HOME}/.claude/skills-config.json"
    
    log_info "Creating skills configuration..."
    
    cat > "$config_file" << EOF
{
  "version": "2.0.0",
  "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source": "offline-package",
  "skills_dir": "${CLAUDE_SKILLS_DIR}",
  "plugins_dir": "${CLAUDE_PLUGINS_DIR}",
  "note": "These are offline-compatible skills and plugins. Some features may require additional dependencies."
}
EOF
    
    log_ok "Configuration saved: ${config_file}"
}

# Print usage information
print_usage() {
    log_info "Claude Code Offline Skills & Plugins"
    log_info "====================================="
    log_info "Installed skills are available at: ${CLAUDE_SKILLS_DIR}"
    log_info "Installed plugins are available at: ${CLAUDE_PLUGINS_DIR}"
    log_info ""
    log_info "To use a skill, simply mention it in Claude Code:"
    log_info "  Example: 'Create a Word document with...'"
    log_info "  Example: 'Design a frontend for...'"
    log_info ""
    log_info "Plugins are automatically loaded by Claude Code."
    log_info ""
    log_info "Available categories:"

    if [ -f "$MANIFEST_FILE" ]; then
        echo ""
        echo "  Document Processing:"
        $JQ_CMD -r '.skills | to_entries[] | select(.value.category == "document" and .value.type != "plugin") | "    - \(.key): \(.value.description)"' "$MANIFEST_FILE" 2>/dev/null || true

        echo ""
        echo "  Design & Development:"
        $JQ_CMD -r '.skills | to_entries[] | select(.value.category == "design" and .value.type != "plugin") | "    - \(.key): \(.value.description)"' "$MANIFEST_FILE" 2>/dev/null || true

        echo ""
        echo "  Testing:"
        $JQ_CMD -r '.skills | to_entries[] | select(.value.category == "testing" and .value.type != "plugin") | "    - \(.key): \(.value.description)"' "$MANIFEST_FILE" 2>/dev/null || true

        echo ""
        echo "  Tools:"
        $JQ_CMD -r '.skills | to_entries[] | select(.value.category == "tool" and .value.type != "plugin") | "    - \(.key): \(.value.description)"' "$MANIFEST_FILE" 2>/dev/null || true

        echo ""
        echo "  Enterprise:"
        $JQ_CMD -r '.skills | to_entries[] | select(.value.category == "enterprise" and .value.type != "plugin") | "    - \(.key): \(.value.description)"' "$MANIFEST_FILE" 2>/dev/null || true

        echo ""
        echo "  Plugins:"
        $JQ_CMD -r '.skills | to_entries[] | select(.value.type == "plugin" and .value.offline_compatible != false) | "    - \(.key): \(.value.description)"' "$MANIFEST_FILE" 2>/dev/null || true

        echo ""
        echo "=== Plugin Setup Notes ==="
        echo ""
        echo "  oh-my-claudecode: Run '/setup' inside Claude Code after installation"
        echo "  everything-claude-code: Run '/ecc:plan' to verify installation"
        echo ""
        echo "  For detailed plugin usage, see:"
        echo "    - https://github.com/Yeachan-Heo/oh-my-claudecode"
        echo "    - https://github.com/affaan-m/everything-claude-code"
    fi
}

# Main function
main() {
    log_info "Claude Code Skills & Plugins Installer"
    log_info "======================================="

    # Initialize jq (system or bundled)
    if ! init_jq; then
        log_error "Failed to initialize jq. Please install jq or run: bash download-jq.sh --all"
        exit 1
    fi

    check_source

    # Ask for confirmation
    if [ -t 0 ]; then
        echo ""
        log_info "This will install offline skills to: ${CLAUDE_SKILLS_DIR}"
        log_info "This will install offline plugins to: ${CLAUDE_PLUGINS_DIR}"
        read -p "Continue? [Y/n]: " -n 1 -r
        echo ""
        if [[ ! $REPLY =~ ^[Yy]$ ]] && [ -n "$REPLY" ]; then
            log_info "Installation cancelled"
            exit 0
        fi
    fi

    install_all_skills
    check_doc_dependencies
    create_skills_config

    log_info "======================================="
    log_ok "Installation completed!"
    echo ""
    print_usage
}

# Show help
if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    echo "Claude Code Skills & Plugins Installer"
    echo ""
    echo "Usage: bash install-skills.sh [skills_dir]"
    echo ""
    echo "Arguments:"
    echo "  skills_dir    Directory containing offline skills and plugins (default: ./offline-skills/)"
    echo ""
    echo "Options:"
    echo "  -h, --help    Show this help message"
    echo ""
    echo "Examples:"
    echo "  bash install-skills.sh                    # Install from default location"
    echo "  bash install-skills.sh /path/to/skills    # Install from custom location"
    exit 0
fi

# Run main function
main "$@"
