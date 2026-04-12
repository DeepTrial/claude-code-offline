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
MANIFEST_FILE="${SKILLS_SOURCE}/skills-manifest.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

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
    echo -e "${RED}[ERROR]${NC} $1" >&2
}

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

# Install a skill
install_skill() {
    local skill_name="$1"
    local source_path="${SKILLS_SOURCE}/${skill_name}"
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
    
    return 0
}

# Install all skills
install_all_skills() {
    local installed=0
    local failed=0
    
    log_info "Installing skills to: ${CLAUDE_SKILLS_DIR}"
    
    # Ensure target directory exists
    mkdir -p "$CLAUDE_SKILLS_DIR"
    
    # Get list of skills from manifest or directory
    local skills_list=()
    
    if [ -f "$MANIFEST_FILE" ]; then
        # Use manifest
        while IFS= read -r skill_name; do
            skills_list+=("$skill_name")
        done < <(jq -r '.skills | keys[]' "$MANIFEST_FILE")
    else
        # Use directory listing
        for skill_dir in "$SKILLS_SOURCE"/*/; do
            if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
                skills_list+=("$(basename "$skill_dir")")
            fi
        done
    fi
    
    # Install each skill
    for skill_name in "${skills_list[@]}"; do
        if [ -d "${SKILLS_SOURCE}/${skill_name}" ]; then
            if install_skill "$skill_name"; then
                ((installed++)) || true
            else
                ((failed++)) || true
            fi
        else
            log_warn "Skill directory not found: ${skill_name}"
            ((failed++)) || true
        fi
    done
    
    log_info "============================="
    log_ok "Installed: ${installed} skills"
    if [ $failed -gt 0 ]; then
        log_warn "Failed: ${failed} skills"
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
  "version": "1.0.0",
  "installed_at": "$(date -u +"%Y-%m-%dT%H:%M:%SZ")",
  "source": "offline-package",
  "skills_dir": "${CLAUDE_SKILLS_DIR}",
  "note": "These are offline-compatible skills. Some features may require additional dependencies."
}
EOF
    
    log_ok "Configuration saved: ${config_file}"
}

# Print usage information
print_usage() {
    log_info "Claude Code Offline Skills"
    log_info "=========================="
    log_info "Installed skills are available at: ${CLAUDE_SKILLS_DIR}"
    log_info ""
    log_info "To use a skill, simply mention it in Claude Code:"
    log_info "  Example: 'Create a Word document with...'"
    log_info "  Example: 'Design a frontend for...'"
    log_info ""
    log_info "Available skills categories:"
    
    if [ -f "$MANIFEST_FILE" ]; then
        echo ""
        echo "  Document Processing:"
        jq -r '.skills | to_entries[] | select(.value.category == "document") | "    - \(.key): \(.value.description)"' "$MANIFEST_FILE"
        
        echo ""
        echo "  Design & Development:"
        jq -r '.skills | to_entries[] | select(.value.category == "design") | "    - \(.key): \(.value.description)"' "$MANIFEST_FILE"
        
        echo ""
        echo "  Testing:"
        jq -r '.skills | to_entries[] | select(.value.category == "testing") | "    - \(.key): \(.value.description)"' "$MANIFEST_FILE"
        
        echo ""
        echo "  Tools:"
        jq -r '.skills | to_entries[] | select(.value.category == "tool") | "    - \(.key): \(.value.description)"' "$MANIFEST_FILE"
        
        echo ""
        echo "  Enterprise:"
        jq -r '.skills | to_entries[] | select(.value.category == "enterprise") | "    - \(.key): \(.value.description)"' "$MANIFEST_FILE"
    fi
}

# Main function
main() {
    log_info "Claude Code Skills Installer"
    log_info "============================"
    
    check_source
    
    # Ask for confirmation
    if [ -t 0 ]; then
        echo ""
        log_info "This will install offline skills to: ${CLAUDE_SKILLS_DIR}"
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
    
    log_info "============================"
    log_ok "Installation completed!"
    echo ""
    print_usage
}

# Show help
if [ "${1:-}" == "--help" ] || [ "${1:-}" == "-h" ]; then
    echo "Claude Code Skills Installer"
    echo ""
    echo "Usage: bash install-skills.sh [skills_dir]"
    echo ""
    echo "Arguments:"
    echo "  skills_dir    Directory containing offline skills (default: ./offline-skills/)"
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
