# Claude Code Offline Deployment

> [简体中文](../../README.md) | **English** | [繁體中文](README.zh-TW.md) | [Русский](README.ru.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](../../.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.2-green)](../../setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](../../LICENSE)

An automated offline deployment solution for Claude Code: it pulls the latest Claude Code from npm every day, builds **dual-platform offline packages for Linux and Windows**, and publishes them to GitHub Releases after **automated installation testing**. Supports automatic mirror detection, region restriction bypass, fully offline installation, and environments without Node.js.

## ✨ Features

- ✅ **Daily automated builds**: GitHub Actions checks npm for new versions every day, then builds and publishes automatically
- ✅ **Dual-platform packages**: Linux x64 (`tar.gz`) + Windows x64 (`zip`, native PowerShell installer)
- ✅ **Test gate**: before release, every package goes through a full installation + launch verification in clean environments (a Node-less Ubuntu container / a Windows runner) — **no release unless tests pass**
- ✅ **No Node.js required**: claude-code 2.x is a standalone native binary; Node.js is optional when a native binary is detected
- ✅ **Network-resilient**: a 5-second pre-flight check before going online, timeouts on all npm/curl calls, and immediate errors with troubleshooting advice — no more "hanging forever"
- ✅ **Unattended installation**: `--yes` / `--non-interactive` modes for scripts and CI
- ✅ **Automatic mirror detection**: speed-tests and picks the fastest Node.js / npm / GitHub mirror
- ✅ **Region restriction bypass**: auto-configures skipping the first-run region verification
- ✅ **20 offline Skills/Plugins**: document processing, design, testing, LSP, multi-agent frameworks, and more
- ✅ **Full uninstall**: thorough uninstallation with configuration backup
- ✅ **All historical releases kept**: Releases are no longer auto-cleaned — roll back anytime

---

## 🚀 Quick Start

### Linux / macOS / WSL

**Option 1: One-line install (requires internet)**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

**Option 2: Offline package install (no internet needed)**

```bash
# After downloading claude-offline-packages.tar.gz from Releases:
tar -xzf claude-offline-packages.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh --yes
```

**Option 3: Existing local offline package**

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

### Windows (native)

1. Download `claude-offline-packages-windows.zip` from [Releases](https://github.com/DeepTrial/claude-code-offline/releases) and extract it
2. Double-click `setup-claude-code.bat`, or run in PowerShell:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -NonInteractive
```

The installer verifies the native `claude.exe`, generates the configuration, and writes the `bin` directory into the user PATH (idempotent). It supports the `-OfflinePath` / `-AutoDownload` / `-NonInteractive` / `-Uninstall` / `-ConfigOnly` parameters.

---

## ⚠️ Required After Installation (Critical)

**You MUST configure your own API key before use:**

```bash
# Linux/macOS/WSL
nano ~/.claude/settings.json

# On Windows, open %USERPROFILE%\.claude\settings.json with Notepad
```

Replace the placeholder values:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-api-endpoint.com",
    "ANTHROPIC_API_KEY": "sk-your-api-key-here"
  }
}
```

Then **open a new terminal** (or run `source ~/.bashrc`) and verify:

```bash
claude --version
```

> 💡 In regions without direct access to the Anthropic API, set `ANTHROPIC_BASE_URL` to your proxy/relay address.

---

## 📦 Release Contents

| File | Platform | Description |
|------|----------|-------------|
| `claude-offline-packages.tar.gz` | Linux x64 / WSL | Full offline package (includes skills, jq, VSCode extensions) |
| `claude-offline-packages-windows.zip` | Windows x64 | Native Windows package (includes skills, jq.exe, PS1 installer) |
| `*.sha256` | - | Checksum files: `sha256sum -c <file>.sha256` |

All historical Releases are **kept** — download any old version to roll back at any time.

---

## 🔄 Automation Pipeline

```
check-version → build-offline-packages (linux) ─┐
              → build-windows-package (windows) ┴→ test-release-package → create-release
                                                  (tested on ubuntu + windows)  (4 attachments)
```

- **Daily check**: at UTC 00:00, compares the latest npm version with existing Releases; builds only when a new version exists
- **Weekly rebuild**: full rebuild every Monday at UTC 01:00
- **Manual trigger**: Actions → `Download Claude Code Offline Packages` → Run workflow (optionally specify a version / force a rebuild)
- **Test gate**: the test job runs structural checks, a `claude --version` assertion, and a full non-interactive installation on both a clean ubuntu:22.04 container (no Node) and windows-latest; the release is published only when everything passes

Local manual update check:

```bash
bash check-update.sh              # interactive
bash check-update.sh --check-only # check only
bash check-update.sh --install    # download and install
```

---

## 🧩 Built-in Offline Skills & Plugins (20)

Downloaded automatically at build time according to `skills/skills-manifest.json`, and installed into `~/.claude/` when the installer runs:

| Category | Contents |
|----------|----------|
| **Document processing** | docx, pdf, pptx, xlsx |
| **Design** | frontend-design, algorithmic-art, canvas-design, theme-factory, web-artifacts-builder |
| **Testing** | webapp-testing (Playwright) |
| **Tools** | skill-creator |
| **Enterprise** | brand-guidelines, internal-comms, doc-coauthoring |
| **Plugins** | superpowers (TDD / debugging / planning workflow framework), everything-claude-code (ECC: 67 agents, 278 skills, 94 commands), gitlab (can point to a self-hosted instance), clangd-lsp, python-lsp, context7* |

> \* context7 is packaged but marked `offline_compatible=false` (fetching documentation requires internet access). clangd-lsp / python-lsp contain configuration only and require clangd / pyright to be installed separately on the machine.

---

## 🖥️ Platform Support

**linux-x64** and **win32-x64** are built automatically by default. The installer skips Node.js when a native binary is detected; Node.js ≥ 18 (22 recommended) is required only when falling back to the Node wrapper.

For other platforms (linux-arm64, darwin, musl), fork the repository and modify the platform package names in the workflow to build them yourself, or follow the notes on the Release page to assemble a package manually with `npm pack`.

---

## 🛠️ Advanced Usage

### Installer script parameters (bash)

| Parameter | Description |
|-----------|-------------|
| `--offline-path PATH` | Specify the offline package path |
| `--auto-download` | Auto-download from GitHub Release |
| `--force-download` | Force re-download |
| `--skip-mirror-test` | Skip the mirror speed test |
| `--yes, -y` | Answer yes to all prompts (fully unattended) |
| `--non-interactive` | Non-interactive mode; automatically uses default answers |
| `--config-only` | Only generate configuration files |
| `--skills-only` | Only install offline skills |
| `--uninstall` | Uninstall Claude Code and its configuration |
| `--help, -h` | Help |

### Environment variables (custom mirrors)

| Variable | Description | Example |
|----------|-------------|---------|
| `NODE_MIRROR` | Node.js mirror | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | npm registry | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | GitHub API mirror | `https://hub.gitmirror.com/https://api.github.com` |

---

## 🧪 Testing the Packages

The test scripts used by CI can also be run locally:

```bash
# Linux package: structural checks + version assertion + end-to-end install in a clean Node-less container
bash tests/test-linux-package.sh /path/to/claude-offline-packages 2.1.215
```

```powershell
# Windows package: binary checks + installer + settings.json + PATH registry assertions
powershell -NoProfile -File tests\test-windows-package.ps1 `
  -PackageDir .\claude-offline-packages-windows -ExpectedVersion 2.1.215
```

---

## 🗑️ Uninstall

```bash
# Linux/macOS/WSL
bash setup-claude-code.sh --uninstall
```

```powershell
# Windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -Uninstall
```

The configuration is automatically backed up before uninstallation, including the config directory, `.claude.json`, and a full cleanup of shell/PATH settings.

---

## 🔧 Troubleshooting

### Network errors (no more hanging)

The installer runs a 5-second connectivity pre-check before any online step, and on failure it **reports immediately** with advice:

- **`Network appears UNAVAILABLE`** — check your network/proxy (`HTTPS_PROXY`), or switch mirrors: `NPM_MIRROR=https://registry.npmmirror.com bash setup-claude-code.sh --auto-download`
- **`npm registry UNREACHABLE / GitHub UNREACHABLE`** — the 5-second probe to that host timed out; steps requiring that host are skipped or aborted, while purely offline steps continue
- **`'npm ...' timed out after Ns`** — npm exceeded its built-in timeout; this usually means the registry is blocked or a proxy is needed — retry with `NPM_MIRROR=...`

### No Node.js environment

claude-code 2.x is a standalone native binary compiled with Bun. When a usable binary is detected, the installer prints `Native binary detected, Node.js optional` and skips the Node installation — everything works without Node.

### claude won't start after extracting the tar.gz on Windows (WSL scenario)

Windows extraction tools (Explorer, 7z, etc.) **drop symlinks**, which loses the Linux package's `.bin/claude`. This installer self-heals: every run rebuilds `.bin/claude` as a **real launcher script** — just re-run `setup-claude-code.sh` in WSL. For native Windows usage, download `claude-offline-packages-windows.zip` directly.

### Claude command not found

```bash
source ~/.bashrc   # or open a new terminal
# Manual PATH:
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### API connection failure

1. Check that `ANTHROPIC_API_KEY` is correct
2. Check that the network can reach the configured `ANTHROPIC_BASE_URL`
3. Confirm whether a proxy is required

---

## License

Same as the original Claude Code license.

## Contributing

Issues and Pull Requests are welcome to improve this project.

---

**Note**: Claude Code and the Claude logo are trademarks of Anthropic. This project is not affiliated with Anthropic.
