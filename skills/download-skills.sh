#!/usr/bin/env bash
# =============================================================================
# Claude Code Skills Downloader for Offline Deployment
# =============================================================================
# Downloads offline-compatible skills from anthropics/skills repository
#
# Usage: bash download-skills.sh [output_dir]
# Default output: ./skills/
# =============================================================================

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/offline-skills}"
GITHUB_REPO="anthropics/skills"
GITHUB_BRANCH="main"
MANIFEST_FILE="${SCRIPT_DIR}/skills-manifest.json"

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
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check dependencies
check_deps() {
    local deps=("curl" "jq" "git")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep is required but not installed"
            exit 1
        fi
    done
}

# Download a single skill (from anthropics/skills format)
download_skill() {
    local skill_name="$1"
    local skill_repo="$2"
    local skill_path="$3"
    local skill_files="$4"
    local output_path="${OUTPUT_DIR}/${skill_name}"
    local branch="${GITHUB_BRANCH}"

    log_info "Downloading skill: ${skill_name} (from ${skill_repo})"

    mkdir -p "$output_path"

    # Build base path for raw files
    local base_path="$skill_path"
    if [ -n "$base_path" ]; then
        base_path="${base_path}/"
    fi

    # Download each file/directory
    for file in $skill_files; do
        if [[ "$file" == */ ]]; then
            # It's a directory - need to get contents
            log_info "  Downloading directory: ${file}"
            local dir_path="${base_path}${file%/}"
            download_directory "$skill_repo" "$branch" "$dir_path" "$output_path/$file"
        else
            # It's a file
            local file_url="https://raw.githubusercontent.com/${skill_repo}/${branch}/${base_path}${file}"
            log_info "  Downloading: ${file}"
            if curl -fsSL "$file_url" -o "$output_path/$file" 2>/dev/null; then
                : # Success
            else
                log_warn "  Failed to download: ${file}"
            fi
        fi
    done

    log_ok "Skill '${skill_name}' downloaded"
}

# Download a plugin (full repo clone)
download_plugin() {
    local plugin_name="$1"
    local plugin_repo="$2"
    local plugin_path="$3"
    local plugin_files="$4"
    local output_path="${OUTPUT_DIR}/${plugin_name}"

    log_info "Downloading plugin: ${plugin_name} (from ${plugin_repo})"

    # Clone repo with shallow depth
    local clone_dir="/tmp/${plugin_name}-clone"
    local repo_url="https://github.com/${plugin_repo}"

    log_info "  Cloning repository: ${repo_url}"

    if git clone --depth 1 "$repo_url" "$clone_dir" 2>/dev/null; then
        # Remove .git directory to reduce size
        rm -rf "$clone_dir/.git"

        # Create output directory
        mkdir -p "$output_path"

        # If path is specified, only copy that subdirectory
        if [ -n "$plugin_path" ] && [ "$plugin_path" != "" ]; then
            local src_dir="$clone_dir/${plugin_path}"
            if [ -d "$src_dir" ]; then
                log_info "  Extracting path: ${plugin_path}"
                cp -r "$src_dir"/* "$output_path/" 2>/dev/null || true
            else
                log_warn "  Path ${plugin_path} not found in repo, copying root"
                cp -r "$clone_dir"/* "$output_path/" 2>/dev/null || true
            fi
        else
            # Copy specific files/directories from plugin_files
            for file in $plugin_files; do
                local src_item="$clone_dir/${file%/}"
                if [[ "$file" == */ ]]; then
                    # It's a directory
                    if [ -d "$src_item" ]; then
                        log_info "  Copying directory: ${file}"
                        mkdir -p "$output_path/${file}"
                        cp -r "$src_item"/* "$output_path/${file}/" 2>/dev/null || true
                    else
                        log_warn "  Directory not found: ${file}"
                    fi
                else
                    # It's a file
                    if [ -f "$src_item" ]; then
                        log_info "  Copying file: ${file}"
                        cp "$src_item" "$output_path/${file}" 2>/dev/null || true
                    else
                        log_warn "  File not found: ${file}"
                    fi
                fi
            done
        fi

        # Cleanup clone directory
        rm -rf "$clone_dir"
        log_ok "Plugin '${plugin_name}' downloaded"
    else
        log_error "  Failed to clone repository: ${repo_url}"
        rm -rf "$clone_dir"
        return 1
    fi
}

# Download directory contents
download_directory() {
    local repo="$1"
    local branch="$2"
    local repo_path="$3"
    local local_path="$4"

    mkdir -p "$local_path"

    # Get directory listing from GitHub API
    local api_url="https://api.github.com/repos/${repo}/contents/${repo_path}?ref=${branch}"
    local response
    
    response=$(curl -s "$api_url")
    
    # Check if response is an array
    if ! echo "$response" | jq -e 'if type == "array" then true else false end' > /dev/null 2>&1; then
        log_warn "  Failed to list directory: ${repo_path}"
        return 1
    fi
    
    # Download each item
    echo "$response" | jq -r '.[] | @base64' | while read -r item; do
        local item_name
        local item_type
        local item_download_url
        local item_path
        
        item_name=$(echo "$item" | base64 -d | jq -r '.name')
        item_type=$(echo "$item" | base64 -d | jq -r '.type')
        item_download_url=$(echo "$item" | base64 -d | jq -r '.download_url // empty')
        item_path=$(echo "$item" | base64 -d | jq -r '.path')
        
        if [ "$item_type" == "file" ] && [ -n "$item_download_url" ]; then
            curl -fsSL "$item_download_url" -o "$local_path/$item_name" 2>/dev/null || \
                log_warn "    Failed: ${item_name}"
        elif [ "$item_type" == "dir" ]; then
            download_directory "$repo" "$branch" "$item_path" "$local_path/$item_name"
        fi
    done
}

# Create skills index
create_index() {
    local index_file="${OUTPUT_DIR}/SKILLS-INDEX.md"
    
    log_info "Creating skills index..."
    
    cat > "$index_file" << 'EOF'
# Claude Code Offline Skills Index

This directory contains offline-compatible skills for Claude Code.

## Installation

To install these skills, run:

```bash
bash install-skills.sh
```

Or manually copy to:
- Linux/macOS: `~/.claude/skills/`
- Windows: `%USERPROFILE%\.claude\skills\`

## Available Skills

EOF

    # Add each skill to index
    for skill_dir in "$OUTPUT_DIR"/*/; do
        if [ -d "$skill_dir" ] && [ -f "$skill_dir/SKILL.md" ]; then
            local skill_name
            skill_name=$(basename "$skill_dir")
            local description
            description=$(grep -m1 "^description:" "$skill_dir/SKILL.md" 2>/dev/null | cut -d'"' -f2 || echo "No description")
            
            echo "- **${skill_name}**: ${description}" >> "$index_file"
        fi
    done
    
    cat >> "$index_file" << 'EOF'

## Usage

After installation, Claude Code will automatically detect and use these skills.

## Custom Skills

You can add your own skills by creating a new directory with a `SKILL.md` file.

See: https://github.com/anthropics/skills/tree/main/template
EOF

    log_ok "Index created: ${index_file}"
}

# Main function
main() {
    log_info "Claude Code Skills & Plugins Downloader"
    log_info "======================================="

    check_deps

    # Check manifest file
    if [ ! -f "$MANIFEST_FILE" ]; then
        log_error "Manifest file not found: ${MANIFEST_FILE}"
        exit 1
    fi

    # Create output directory
    mkdir -p "$OUTPUT_DIR"
    log_info "Output directory: ${OUTPUT_DIR}"

    # Parse manifest and download skills/plugins
    local skills_count
    skills_count=$(jq -r '.skills | length' "$MANIFEST_FILE")
    log_info "Found ${skills_count} entries in manifest"

    # Download each skill/plugin
    jq -r '.skills | keys[]' "$MANIFEST_FILE" | while read -r entry_name; do
        local entry_type
        local entry_repo
        local entry_path
        local entry_files
        local offline_compatible

        entry_type=$(jq -r ".skills.${entry_name}.type // \"skill\"" "$MANIFEST_FILE")
        entry_repo=$(jq -r ".skills.${entry_name}.repo" "$MANIFEST_FILE")
        entry_path=$(jq -r ".skills.${entry_name}.path // \"\"" "$MANIFEST_FILE")
        entry_files=$(jq -r ".skills.${entry_name}.files | join(\" \")" "$MANIFEST_FILE")
        offline_compatible=$(jq -r ".skills.${entry_name}.offline_compatible // true" "$MANIFEST_FILE")

        # Skip offline-incompatible entries
        if [ "$offline_compatible" = "false" ]; then
            log_warn "Skipping '${entry_name}' - offline_compatible=false"
            continue
        fi

        # Download based on type
        if [ "$entry_type" = "plugin" ]; then
            download_plugin "$entry_name" "$entry_repo" "$entry_path" "$entry_files"
        else
            download_skill "$entry_name" "$entry_repo" "$entry_path" "$entry_files"
        fi
    done

    # Create index
    create_index

    # Copy manifest
    cp "$MANIFEST_FILE" "$OUTPUT_DIR/"

    log_info "======================================="
    log_ok "All skills/plugins downloaded to: ${OUTPUT_DIR}"
    log_info "Total size: $(du -sh "$OUTPUT_DIR" | cut -f1)"
}

# Run main function
main "$@"
