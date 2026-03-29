# Claude Code Offline Deployment

> [简体中文](../../README.md) | **English** | [繁體中文](README.zh-TW.md) | [Русский](README.ru.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](../../.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.1-green)](../../setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](../../LICENSE)

An intelligent offline deployment solution for Claude Code with automatic mirror detection, region restriction bypass, and multi-language support.

## Features

- ✅ **GitHub Actions Auto-Download**: Automatically download and package the latest Claude Code from npm
- ✅ **Multi-Path Auto-Detection**: Auto-find offline packages without hardcoded paths
- ✅ **Universal Node.js Installation**: Support nvm, apt, or direct binary download
- ✅ **Flexible Deployment**: Offline packages, online download, or direct npm installation
- ✅ **Smart Configuration**: Auto-cleanup old configurations
- ✅ **Built-in Cleanup Tool**: Include TMP directory cleanup script
- ✅ **🆕 Automatic Mirror Detection**: Auto-test and select fastest download source
- ✅ **🆕 Region Restriction Bypass**: Auto-configure to skip first-run region verification
- ✅ **🆕 Uninstall Support**: Complete uninstallation with backup

---

## 🚀 Quick Start (3 Ways)

### Option 1: One-Line Install (Recommended, requires internet)

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

### Option 2: Use Offline Package (No internet needed)

1. Download `claude-offline-packages.tar.gz` from [Releases](https://github.com/DeepTrial/claude-code-offline/releases)
2. Extract and run:

```bash
tar -xzf claude-offline-packages.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh
```

### Option 3: Existing Offline Package

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

---

## ⚠️ Post-Installation Required (Critical)

**You MUST configure API key after installation:**

### 1. Edit Configuration

```bash
nano ~/.claude/settings.json
```

### 2. Update Settings

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com",
    "ANTHROPIC_API_KEY": "sk-your-api-key-here",
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-3-opus-20240229",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-3-sonnet-20240229",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-3-haiku-20240307"
  }
}
```

### 3. Reload Configuration

```bash
source ~/.bashrc
claude --version
```

> 💡 **Tip**: If you cannot directly access Anthropic API, configure a proxy to `ANTHROPIC_BASE_URL`

---

## Detailed Usage Guide

### Table of Contents

- [Automatic Version Updates](#automatic-version-updates)
- [Mirror Source Detection](#mirror-source-detection)
- [Region Restriction Bypass](#region-restriction-bypass)
- [Advanced Usage](#advanced-usage)
- [Uninstall](#uninstall)
- [Troubleshooting](#troubleshooting)

## Automatic Version Updates

This repository includes automatic version checking and update mechanisms:

### GitHub Actions Auto-Build

The workflow automatically:
1. **Daily Check**: Check npm registry for new versions daily at 00:00 UTC
2. **Version Comparison**: Compare npm version with existing GitHub Releases
3. **Smart Build**: Only builds when a new version is detected
4. **Auto-Release**: Creates GitHub Release automatically

### Local Version Checker

Use `check-update.sh` to check and download updates:

```bash
# Interactive check
bash check-update.sh

# Check only
bash check-update.sh --check-only

# Download and install if update available
bash check-update.sh --install
```

## Mirror Source Detection

The script includes intelligent mirror source detection that auto-tests and selects the fastest download source.

### Supported Mirrors

| Type | Default | Mirrors |
|------|---------|---------|
| **Node.js Binary** | `nodejs.org/dist/` | npmmirror, Tencent Cloud |
| **npm Registry** | `registry.npmjs.org/` | `registry.npmmirror.com` |
| **nvm Script** | `raw.githubusercontent.com` | jsDelivr CDN, gitmirror |
| **GitHub API** | `api.github.com` | gitmirror, ghproxy, ghps.cc |

### Custom Mirrors

```bash
export NODE_MIRROR=https://your-mirror.com/node/
export NPM_MIRROR=https://your-registry.com
bash setup-claude-code.sh --auto-download
```

## Region Restriction Bypass

Built-in configurations to bypass Claude Code's first-run region restrictions.

### If Still Encountering Region Issues

Ensure correct API endpoint (using proxy):

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-proxy-api-endpoint.com",
    "ANTHROPIC_API_KEY": "your-api-key"
  }
}
```

## Advanced Usage

### Script Parameters

| Parameter | Description |
|-----------|-------------|
| `--offline-path PATH` | Specify offline package path |
| `--auto-download` | Auto-download from GitHub Release |
| `--force-download` | Force re-download |
| `--skip-mirror-test` | Skip mirror speed test |
| `--uninstall` | Uninstall Claude Code |
| `--help, -h` | Show help |

### Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `NODE_MIRROR` | Custom Node.js mirror | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | Custom npm registry | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | Custom GitHub mirror | `https://hub.gitmirror.com/...` |

## Uninstall

```bash
bash setup-claude-code.sh --uninstall
```

Includes:
- Delete `~/.claude/` directory
- Delete `~/.claude.json`
- Remove configurations from `.bashrc`
- Optional: Delete Node.js and nvm
- Auto-backup before uninstall

## Troubleshooting

### Node.js Installation Failed

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 20
nvm use 20
bash setup-claude-code.sh
```

### Claude Command Not Found

```bash
source ~/.bashrc
# or
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### API Connection Failed

Check:
1. API key is correct
2. Network can access `ANTHROPIC_BASE_URL`
3. Proxy configuration if needed

## License

Same as original Claude Code license.

## Contributing

Issues and Pull Requests are welcome.

---

**Note**: Claude Code and logo are trademarks of Anthropic. This project is not affiliated with Anthropic.
