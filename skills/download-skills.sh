#!/usr/bin/env bash
# =============================================================================
# Claude Code Skills Downloader for Offline Deployment
# =============================================================================
# Downloads offline-compatible skills from anthropics/skills repository
#
# Usage: bash download-skills.sh [output_dir]
# Default output: ./skills/
# =============================================================================

set -uo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
OUTPUT_DIR="${1:-${SCRIPT_DIR}/offline-skills}"
GITHUB_REPO="anthropics/skills"
GITHUB_BRANCH="main"
MANIFEST_FILE="${SCRIPT_DIR}/skills-manifest.json"

# Source common utilities
source "${SCRIPT_DIR}/lib/common.sh"

# jq command - will be set by init_jq
JQ_CMD=""

# Check dependencies
check_deps() {
    # Initialize jq first (system or bundled)
    if ! init_jq; then
        log_error "Failed to initialize jq. Please install jq or run: bash download-jq.sh --all"
        exit 1
    fi

    # Check for curl and git
    local deps=("curl" "git")
    for dep in "${deps[@]}"; do
        if ! command -v "$dep" &> /dev/null; then
            log_error "$dep is required but not installed"
            exit 1
        fi
    done
}

# Download a skill or plugin via shallow git clone
# This avoids GitHub API rate limits and is faster for multi-file entries
download_entry() {
    local entry_name="$1"
    local entry_repo="$2"
    local entry_path="$3"
    local entry_files="$4"
    local entry_type="${5:-skill}"
    local output_path="${OUTPUT_DIR}/${entry_name}"

    log_info "Downloading ${entry_type}: ${entry_name} (from ${entry_repo})"
    mkdir -p "$output_path"

    local clone_dir="/tmp/${entry_name}-clone-$$"
    local repo_url="https://github.com/${entry_repo}"

    if ! git clone --depth 1 "$repo_url" "$clone_dir" 2>&1; then
        log_error "  Failed to clone: ${repo_url}"
        rm -rf "$clone_dir"
        return 1
    fi

    local src_base="$clone_dir"
    if [ -n "$entry_path" ]; then
        src_base="$clone_dir/${entry_path}"
        if [ ! -d "$src_base" ]; then
            log_warn "  Path ${entry_path} not found in repo, using root"
            src_base="$clone_dir"
        fi
    fi

    for file in $entry_files; do
        local src="$src_base/$file"
        local dst="$output_path/$file"
        if [ -e "$src" ]; then
            mkdir -p "$(dirname "$dst")"
            cp -r "$src" "$dst" 2>/dev/null || log_warn "  Failed to copy: ${file}"
        else
            log_warn "  Not found in repo: ${file}"
        fi
    done

    # Validate payload: an entry with zero payload files is a broken bundle
    # (e.g. upstream restructure or field mis-parse) — fail loudly instead of
    # silently shipping an empty directory.
    local copied
    copied=$(find "$output_path" -type f -not -path '*/.git/*' 2>/dev/null | wc -l)
    if [ "$copied" -eq 0 ]; then
        log_error "  No payload files copied for ${entry_name} — refusing to ship an empty bundle"
        rm -rf "$clone_dir"
        return 1
    fi

    # For plugins, record the git commit SHA (small file instead of a full .git,
    # which can add tens of MB per plugin to the shipped package)
    if [ "$entry_type" = "plugin" ] && [ -d "$clone_dir/.git" ]; then
        git -C "$clone_dir" rev-parse HEAD > "$output_path/.git-sha" 2>/dev/null || true
    fi

    rm -rf "$clone_dir"
    log_ok "${entry_type} '${entry_name}' downloaded (${copied} files)"
    return 0
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
    skills_count=$($JQ_CMD -r '.skills | length' "$MANIFEST_FILE")
    log_info "Found ${skills_count} entries in manifest"

    local skipped=0
    local failed=0
    local succeeded=0

    # Single-pass jq: extract all skill data at once, then download in parallel
    local tmp_results
    tmp_results=$(mktemp)

    # NOTE: use \x1f (unit separator) instead of tab. Tab is IFS-whitespace, so
    # consecutive empty fields (e.g. path="") would be collapsed by `read`,
    # shifting every subsequent field and silently breaking the download.
    while IFS=$'\x1f' read -r entry_name entry_type entry_repo entry_path entry_files offline_compatible; do
        # Skip offline-incompatible entries
        if [ "$offline_compatible" = "false" ]; then
            log_warn "Skipping '${entry_name}' - offline_compatible=false"
            echo "skipped" >> "$tmp_results"
            continue
        fi

        # Download in parallel
        (
            if download_entry "$entry_name" "$entry_repo" "$entry_path" "$entry_files" "$entry_type"; then
                echo "ok" >> "$tmp_results"
            else
                echo "fail" >> "$tmp_results"
            fi
        ) &
    done < <($JQ_CMD -r '.skills | to_entries[] | [.key, .value.type // "skill", .value.repo, .value.path // "", (.value.files | join(" ")), (if .value.offline_compatible == null then "true" elif .value.offline_compatible == false then "false" else "true" end)] | join("\u001f")' "$MANIFEST_FILE")
    wait

    # grep -c always prints a count (even 0); '|| true' only guards set -u/-e.
    # ('|| echo 0' would append a second line when grep exits non-zero.)
    succeeded=$(grep -c "^ok$" "$tmp_results" 2>/dev/null || true)
    failed=$(grep -c "^fail$" "$tmp_results" 2>/dev/null || true)
    skipped=$(grep -c "^skipped$" "$tmp_results" 2>/dev/null || true)
    succeeded=${succeeded:-0}; failed=${failed:-0}; skipped=${skipped:-0}
    rm -f "$tmp_results"

    # Create index
    create_index

    # Copy manifest
    cp "$MANIFEST_FILE" "$OUTPUT_DIR/"

    log_info "======================================="
    log_ok "Download completed: ${succeeded} succeeded, ${failed} failed, ${skipped} skipped"
    log_info "Output: ${OUTPUT_DIR}"
    log_info "Total size: $(du -sh "$OUTPUT_DIR" | cut -f1)"

    # Fail the whole run when any entry failed, so CI does not ship broken bundles
    if [ "$failed" -gt 0 ]; then
        log_error "${failed} entr(y/ies) failed to download — aborting with error"
        exit 1
    fi
}

# Run main function
main "$@"
