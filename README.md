# Claude Code 离线部署方案

> **简体中文** | [English](docs/i18n/README.en.md) | [繁體中文](docs/i18n/README.zh-TW.md) | [Русский](docs/i18n/README.ru.md) | [日本語](docs/i18n/README.ja.md) | [한국어](docs/i18n/README.ko.md)

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.2-green)](setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)

自动化的 Claude Code 离线部署方案：每天自动从 npm 拉取最新版 Claude Code，构建 **Linux 与 Windows 双平台离线包**，经过**自动化安装测试**后发布到 GitHub Releases。支持镜像源自动检测、地区限制绕过、纯离线安装和无 Node.js 环境。

## ✨ 特性

- ✅ **每日自动构建**：GitHub Actions 每天检查 npm 新版本，自动构建并发布
- ✅ **双平台安装包**：Linux x64(`tar.gz`)+ Windows x64(`zip`，原生 PowerShell 安装器）
- ✅ **测试门禁**：每个包发布前都在干净环境（无 Node 的 ubuntu 容器 / Windows runner）中跑完整安装 + 启动验证，**测试不过不发版**
- ✅ **无需 Node.js**:claude-code 2.x 是独立原生二进制，检测到原生二进制时 Node.js 可选装
- ✅ **抗网络抖动**：联网前 5 秒预检、npm/curl 全部带超时、失败即时报错并给出排查建议，不再"卡死"
- ✅ **无人值守安装**:`--yes` / `--non-interactive` 模式，适合脚本和 CI
- ✅ **镜像源自动检测**：自动测速选择最快的 Node.js / npm / GitHub 镜像
- ✅ **地区限制绕过**：自动配置跳过首次启动的地区验证
- ✅ **20 个离线 Skills/Plugins**：文档处理、设计、测试、LSP、多智能体框架等
- ✅ **完整卸载功能**：支持配置备份的彻底卸载
- ✅ **历史版本全部保留**:Releases 不再自动清理，可随时回退

---

## 🚀 快速开始

### Linux / macOS / WSL

**方式 1：一行命令安装（需要网络）**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

**方式 2：离线包安装（无需网络）**

```bash
# 从 Releases 下载 claude-offline-packages-linux.tar.gz 后：
tar -xzf claude-offline-packages-linux.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh --yes
```

**方式 3：本地已有离线包**

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

### Windows（原生）

1. 从 [Releases](https://github.com/DeepTrial/claude-code-offline/releases) 下载 `claude-offline-packages-windows.zip` 并解压
2. 双击 `setup-claude-code.bat`，或在 PowerShell 中运行：

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -NonInteractive
```

安装器会校验原生 `claude.exe`、生成配置、并把 `bin` 目录写入用户 PATH（幂等）。支持 `-OfflinePath` / `-AutoDownload` / `-NonInteractive` / `-Uninstall` / `-ConfigOnly` 参数。

---

## ⚠️ 安装后必做（关键步骤）

**必须配置自己的 API 密钥才能使用：**

```bash
# Linux/macOS/WSL
nano ~/.claude/settings.json

# Windows 用记事本打开 %USERPROFILE%\.claude\settings.json
```

替换占位值：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-api-endpoint.com",
    "ANTHROPIC_API_KEY": "sk-your-api-key-here"
  }
}
```

然后**打开新终端**（或 `source ~/.bashrc`)，验证：

```bash
claude --version
```

> 💡 无法直连 Anthropic API 的地区，把 `ANTHROPIC_BASE_URL` 配置为你的代理/中转地址。

---

## 📦 Release 内容

| 文件 | 平台 | 说明 |
|------|------|------|
| `claude-offline-packages-linux.tar.gz` | Linux x64 / WSL | 完整离线包（含 skills、jq、VSCode 扩展） |
| `claude-offline-packages-windows.zip` | Windows x64 | 原生 Windows 包（含 skills、jq.exe、PS1 安装器） |
| `*.sha256` | - | 校验文件：`sha256sum -c <file>.sha256` |

历史 Release **全部保留**，可随时下载旧版本回退。

---

## 🔄 自动化流水线

```
check-version → build-offline-packages (linux) ─┐
              → build-windows-package (windows) ┴→ test-release-package → create-release
                                                    (ubuntu + windows 双端)   (4 个附件)
```

- **每日检查**:UTC 00:00 对比 npm 最新版与现有 Release，有新版本才构建
- **每周重建**：每周一 UTC 01:00 完整重建
- **手动触发**:Actions → `Download Claude Code Offline Packages` → Run workflow（可指定版本/强制重建）
- **测试门禁**：测试 job 在干净 ubuntu:22.04 容器（无 Node）和 windows-latest 上分别执行结构校验、`claude --version` 断言、完整非交互安装，全部通过才会发布

本地手动检查更新：

```bash
bash check-update.sh              # 交互式
bash check-update.sh --check-only # 仅检查
bash check-update.sh --install    # 下载并安装
```

---

## 🧩 内置离线 Skills 与 Plugins(20 个）

构建时按 `skills/skills-manifest.json` 自动下载，安装器运行后装入 `~/.claude/`:

| 分类 | 内容 |
|------|------|
| **文档处理** | docx、pdf、pptx、xlsx |
| **设计** | frontend-design、algorithmic-art、canvas-design、theme-factory、web-artifacts-builder |
| **测试** | webapp-testing(Playwright) |
| **工具** | skill-creator |
| **企业** | brand-guidelines、internal-comms、doc-coauthoring |
| **插件** | superpowers(TDD/调试/规划工作流框架）、everything-claude-code(ECC:67 agents、278 skills、94 命令）、gitlab（可指向自建实例）、clangd-lsp、python-lsp、context7* |

> \* context7 已打包但标记为 `offline_compatible=false`（拉取文档需要联网）。clangd-lsp / python-lsp 仅含配置，需本机另有 clangd / pyright。

---

## 🖥️ 平台支持

默认自动构建 **linux-x64** 与 **win32-x64**。安装器在检测到原生二进制时跳过 Node.js；仅当需要回退到 Node wrapper 时才要求 Node.js ≥ 18（推荐 22)。

其他平台（linux-arm64、darwin、musl）可 fork 后修改 workflow 中的平台包名自行构建，或参考 Release 页面说明用 `npm pack` 手工组包。

---

## 🛠️ 高级用法

### 安装脚本参数（bash)

| 参数 | 说明 |
|------|------|
| `--offline-path PATH` | 指定离线包路径 |
| `--auto-download` | 自动从 GitHub Release 下载 |
| `--force-download` | 强制重新下载 |
| `--skip-mirror-test` | 跳过镜像测速 |
| `--yes, -y` | 所有提示自动 yes（完全无人值守） |
| `--non-interactive` | 非交互模式，自动采用默认答案 |
| `--config-only` | 只生成配置文件 |
| `--skills-only` | 只安装离线 skills |
| `--uninstall` | 卸载 Claude Code 及配置 |
| `--help, -h` | 帮助 |

### 环境变量（自定义镜像）

| 变量 | 说明 | 示例 |
|------|------|------|
| `NODE_MIRROR` | Node.js 镜像 | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | npm registry | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | GitHub API 镜像 | `https://hub.gitmirror.com/https://api.github.com` |

---

## 🧪 测试安装包

CI 使用的测试脚本同样可本地运行：

```bash
# Linux 包：结构校验 + 版本断言 + 无 Node 干净容器端到端安装
bash tests/test-linux-package.sh /path/to/claude-offline-packages 2.1.215
```

```powershell
# Windows 包：二进制校验 + 安装器 + settings.json + PATH 注册表断言
powershell -NoProfile -File tests\test-windows-package.ps1 `
  -PackageDir .\claude-offline-packages-windows -ExpectedVersion 2.1.215
```

---

## 🗑️ 卸载

```bash
# Linux/macOS/WSL
bash setup-claude-code.sh --uninstall
```

```powershell
# Windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -Uninstall
```

卸载前会自动备份配置，包含配置目录、`.claude.json`、shell/PATH 配置的完整清理。

---

## 🔧 故障排除

### 网络错误（不再卡死）

安装器在任何联网步骤前都会做 5 秒连通性预检，失败会**立即报错**并给出建议：

- **`Network appears UNAVAILABLE`** — 检查网络/代理（`HTTPS_PROXY`)，或换镜像：`NPM_MIRROR=https://registry.npmmirror.com bash setup-claude-code.sh --auto-download`
- **`npm registry UNREACHABLE / GitHub UNREACHABLE`** — 对应主机 5 秒探测超时；仅需要该主机的步骤会跳过或中止，纯离线步骤继续
- **`'npm ...' timed out after Ns`** — npm 超过内置超时，通常是 registry 被墙或需要代理，用 `NPM_MIRROR=...` 重试

### 无 Node.js 环境

claude-code 2.x 是 Bun 编译的独立原生二进制。检测到可用二进制时安装器会打印 `Native binary detected, Node.js optional` 并跳过 Node 安装——没有 Node 也能正常使用。

### 在 Windows 上解压 tar.gz 后 claude 无法启动（WSL 场景）

Windows 解压工具（资源管理器、7z 等）会**丢弃 symlink**，导致 Linux 包的 `.bin/claude` 丢失。本安装器已自愈：每次运行都会把 `.bin/claude` 重建为**实体 launcher 脚本**，在 WSL 里重跑一次 `setup-claude-code.sh` 即可。原生 Windows 使用请直接下载 `claude-offline-packages-windows.zip`。

### Claude 命令找不到

```bash
source ~/.bashrc   # 或打开新终端
# 手动 PATH:
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### API 连接失败

1. 检查 `ANTHROPIC_API_KEY` 是否正确
2. 检查网络能否访问配置的 `ANTHROPIC_BASE_URL`
3. 确认是否需要代理

---

## 许可证

与原 Claude Code 许可证一致。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

---

**注意**: Claude Code 和 Claude 标志是 Anthropic 的商标。本项目与 Anthropic 无关。
