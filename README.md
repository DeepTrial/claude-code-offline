# Claude Code Offline Deployment

> [中文文档](README.zh-CN.md) | English

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.1-green)](setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)

An intelligent offline deployment solution for Claude Code with automatic mirror detection, region restriction bypass, and multi-language support.

## Features

- ✅ **GitHub Actions Auto-Download**: Automatically download the latest Claude Code from npm and package it
- ✅ **Multi-Path Auto-Detection**: Automatically find offline packages without hardcoded paths
- ✅ **Universal Node.js Installation**: Support nvm, apt, or direct binary download for Node.js
- ✅ **Flexible Deployment**: Support offline packages, online download, or direct npm installation
- ✅ **Smart Configuration Management**: Auto-clean old configurations, keep .bashrc tidy
- ✅ **Built-in Cleanup Tool**: Include TMP directory cleanup script
- ✅ **🆕 Automatic Mirror Detection**: Auto-test and select the fastest download sources (Node.js, npm, GitHub)
- ✅ **🆕 Region Restriction Bypass**: Auto-configure to skip first-run region verification
- ✅ **🆕 Uninstall Support**: Complete uninstallation with backup functionality

## Table of Contents

- [Quick Start](#quick-start)
- [Features](#features)
- [Automatic Version Updates](#automatic-version-updates)
- [Mirror Source Detection](#mirror-source-detection)
- [Region Restriction Bypass](#region-restriction-bypass)
- [Usage](#usage)
- [Uninstall](#uninstall)
- [Script Parameters](#script-parameters)
- [Environment Variables](#environment-variables)
- [GitHub Actions Workflow](#github-actions-workflow)
- [Configuration](#configuration)
- [Troubleshooting](#troubleshooting)

## Automatic Version Updates

The repository includes automatic version checking and update mechanisms:

### GitHub Actions Auto-Build

The workflow automatically:
1. **Daily Check**: Checks npm registry daily for new versions at 00:00 UTC
2. **Version Comparison**: Compares npm version with existing GitHub Releases
3. **Smart Build**: Only builds when a new version is detected
4. **Auto-Release**: Creates a new GitHub Release with the new version

### Schedule

| Trigger | Schedule | Action |
|---------|----------|--------|
| Daily Check | `0 0 * * *` | Check npm for new versions, build if newer |
| Weekly Rebuild | `0 0 * * 1` | Full rebuild every Monday |
| Manual | `workflow_dispatch` | Manual trigger with force rebuild option |

### Local Version Checker

Use the included `check-update.sh` script to check and download updates:

```bash
# Check for updates interactively
bash check-update.sh

# Only check versions
bash check-update.sh --check-only

# Download if update available
bash check-update.sh --download

# Download and install if update available
bash check-update.sh --install
```

### Force Rebuild

If you need to rebuild an existing version:

1. Go to GitHub Actions → "Download Claude Code Offline Packages"
2. Click "Run workflow"
3. Check "Force rebuild even if version exists"
4. Click "Run workflow"

## Quick Start

```bash
# Option 1: Auto-download with mirror detection (requires internet)
bash setup-claude-code.sh --auto-download

# Option 2: Use specific offline packages
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages

# Option 3: Interactive mode (auto-detect or prompt)
bash setup-claude-code.sh
```

## Mirror Source Detection

The script includes an intelligent mirror source detection system that automatically tests and selects the fastest download source:

### Supported Mirror Sources

| Type | Default Source | Mirror Sources |
|------|----------------|----------------|
| **Node.js Binary** | `nodejs.org/dist/` | Taobao (npmmirror), Tencent Cloud |
| **npm Registry** | `registry.npmjs.org/` | `registry.npmmirror.com` |
| **nvm Install Script** | `raw.githubusercontent.com` | jsDelivr CDN, gitmirror |
| **GitHub API** | `api.github.com` | gitmirror, ghproxy, ghps.cc |

### How It Works

1. The script tests connection speed to all available mirror sources
2. Automatically selects the fastest mirror source
3. If a source is unreachable, automatically tries the next one
4. Failed downloads automatically switch to backup sources

### Custom Mirror Sources

Override default sources using environment variables:

```bash
# Custom Node.js mirror
export NODE_MIRROR=https://your-mirror.com/node/

# Custom npm registry
export NPM_MIRROR=https://your-registry.com

# Custom GitHub mirror
export GITHUB_MIRROR=https://your-github-proxy.com

# Run the script
bash setup-claude-code.sh --auto-download
```

### Skip Mirror Detection

If your network environment is stable, you can skip mirror detection to speed up script startup:

```bash
bash setup-claude-code.sh --auto-download --skip-mirror-test
```

## Region Restriction Bypass

The script includes built-in configurations to bypass Claude Code's first-run region restrictions:

### Auto-Configuration Items

| Configuration | Purpose |
|---------------|---------|
| `hasCompletedOnboarding: true` | Mark onboarding flow as completed |
| `skipOnboarding: true` | Skip first-run onboarding |
| `hasAcceptedTerms: true` | Mark terms of service as accepted |
| `telemetry.enabled: false` | Disable telemetry |
| `DISABLE_AUTOUPDATER=1` | Disable auto-updater |
| `CLAUDE_CODE_SKIP_FIRST_RUN=1` | Skip first-run checks |
| `regionCheck.bypassed: true` | Mark region check as bypassed |

### Wrapper Script

A wrapper script `~/.claude/claude-wrapper.sh` is created to automatically set necessary environment variables.

An alias is added to `.bashrc` so that when you use the `claude` command, it automatically calls the wrapper.

### If You Still Encounter Region Issues

Ensure you correctly configure the API endpoint (using a proxy):

```json
// ~/.claude/settings.json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-proxy-api-endpoint.com",
    "ANTHROPIC_API_KEY": "your-api-key"
  }
}
```

Or use a third-party service that supports Claude API.

## Usage

### Option 1: GitHub Actions Auto-Download (Recommended)

1. **Fork this repository** to your GitHub account

2. **Manually trigger the workflow**:
   - Go to the GitHub repository page
   - Click the "Actions" tab
   - Select "Download Claude Code Offline Packages"
   - Click "Run workflow"

3. **Download the artifact**:
   - After the workflow completes, download `claude-offline-packages` from the "Artifacts" section

4. **Run on target machine**:
   ```bash
   # Extract the downloaded package
   tar -xzf claude-offline-packages.tar.gz
   
   # Run the installation script
   cd claude-offline-packages
   bash setup-claude-code.sh
   ```

### Option 2: Auto-Download Mode

If the target machine has internet access, you can let the script download directly from GitHub Release:

```bash
bash setup-claude-code.sh --auto-download
```

### Option 3: Specify Offline Package Path

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

### Option 4: Direct npm Installation

If the target machine has internet access and Node.js >= 18:

```bash
bash setup-claude-code.sh
# Select option 3: Install Claude Code directly via npm
```

## Uninstall

If you have already installed Claude Code, you can use the uninstall feature to completely remove it:

```bash
# Uninstall Claude Code
bash setup-claude-code.sh --uninstall
```

### Uninstall Contents

- ✅ Delete `~/.claude/` configuration directory
- ✅ Delete `~/.claude.json` configuration file
- ✅ Remove all related configurations from `.bashrc` (PATH, TMPDIR, NVM, Node.js)
- ✅ Optional: Delete downloaded offline packages
- ✅ Optional: Delete Node.js (if installed to `~/.local/node`)
- ✅ Optional: Delete nvm (if installed by this script)
- ✅ Auto-backup configuration before uninstall (optional)

### Pre-Installation Detection

When running the installation script, it automatically detects if there is an existing installation:

```
[WARN] Detected existing Claude Code installation:
  - Claude binary: /home/user/.local/bin/claude
  - Config directory: /home/user/.claude
  - Config file: /home/user/.claude.json

Options:
  1) Reinstall / Update (backup existing config and reinstall)
  2) Uninstall (completely remove Claude Code)
  3) Continue anyway (may cause conflicts)
  4) Exit
```

## Script Parameters

| Parameter | Description |
|-----------|-------------|
| `--offline-path PATH` | Specify path to offline packages |
| `--auto-download` | Automatically download packages from GitHub |
| `--force-download` | Force re-download even if packages exist |
| `--skip-mirror-test` | Skip mirror speed test |
| `--uninstall` | Uninstall Claude Code and all configurations |
| `--help, -h` | Show help message |

## Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NODE_MIRROR` | Custom Node.js mirror source | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | Custom npm registry | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | Custom GitHub API mirror | `https://hub.gitmirror.com/https://api.github.com` |

## GitHub Actions Workflow

The workflow is configured in `.github/workflows/download-claude-packages.yml` and includes:

- Automatic update check every Monday (cron schedule)
- Manual trigger support
- Automatic download of Claude Code npm package
- Package and upload to GitHub Release
- Generate SHA256 checksum file
- Attempt to download VSCode extension

### Trigger Methods

1. **Manual Trigger**:
   ```
   GitHub Page → Actions → Download Claude Code Offline Packages → Run workflow
   ```

2. **Scheduled Trigger**:
   - Automatically runs every Monday at UTC 00:00

3. **Release Trigger**:
   - Automatically runs when creating a new Release

## Configuration

After installation, you need to edit the configuration file to add your API key:

```bash
nano ~/.claude/settings.json
```

Replace the placeholders:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com",  // Or your proxy address
    "ANTHROPIC_API_KEY": "sk-...",                       // Your API key
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-3-opus-...",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-3-sonnet-...",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-3-haiku-..."
  }
}
```

## Troubleshooting

### Node.js Installation Failed

```bash
# Manually install nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 20
nvm use 20

# Re-run the script
bash setup-claude-code.sh
```

### Offline Package Download Failed

```bash
# Check network connection
curl -I https://api.github.com

# Use proxy
export https_proxy=http://proxy.example.com:8080
bash setup-claude-code.sh --auto-download
```

### Claude Command Not Found

```bash
# Reload shell configuration
source ~/.bashrc

# Or manually add PATH
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

## License

Same as the original Claude Code license.

## Contributing

Issues and Pull Requests are welcome to improve this project.

---

**Note**: Claude Code and the Claude logo are trademarks of Anthropic. This project is not affiliated with Anthropic.
