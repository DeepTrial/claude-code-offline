# Claude Code 离线部署方案

> **简体中文** | [English](docs/i18n/README.en.md) | [繁體中文](docs/i18n/README.zh-TW.md) | [Русский](docs/i18n/README.ru.md) | [日本語](docs/i18n/README.ja.md) | [한국어](docs/i18n/README.ko.md)

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.1-green)](setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](LICENSE)

一个智能的 Claude Code 离线部署方案，支持自动镜像源检测、地区限制绕过和多语言支持。

## 特性

- ✅ **GitHub Actions 自动下载**: 自动从 npm 下载最新 Claude Code 并打包
- ✅ **多路径自动检测**: 自动查找离线包，无需硬编码路径
- ✅ **通用 Node.js 安装**: 支持 nvm、apt 或直接下载二进制文件安装 Node.js
- ✅ **灵活的部署方式**: 支持离线包、在线下载或直接 npm 安装
- ✅ **智能配置管理**: 自动清理旧配置，保持 .bashrc 整洁
- ✅ **内置清理工具**: 包含 TMP 目录清理脚本
- ✅ **🆕 镜像源自动检测**: 自动测试并选择最快的下载源（Node.js、npm、GitHub）
- ✅ **🆕 地区限制绕过**: 自动配置跳过首次启动的地区验证
- ✅ **🆕 卸载功能**: 完整的卸载功能，支持备份
- ✅ **🆕 离线 Skills 支持**: 内置 14 个离线可用的 Claude Code 插件（文档处理、设计、测试等）

---

## 🚀 快速开始（3 种方式）

### 方式 1：一行命令安装（推荐，需要网络）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

### 方式 2：使用离线包安装（无需网络）

1. 从 [Releases](https://github.com/DeepTrial/claude-code-offline/releases) 下载 `claude-offline-packages.tar.gz`
2. 解压并运行：

```bash
tar -xzf claude-offline-packages.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh
```

### 方式 3：本地已有离线包

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

---

## ⚠️ 安装后必做（关键步骤）

安装完成后，**必须配置 API 密钥**才能使用：

### 1. 编辑配置文件

```bash
nano ~/.claude/settings.json
```

### 2. 修改以下配置

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

### 3. 重新加载配置

```bash
source ~/.bashrc
claude --version
```

> 💡 **提示**：如果你所在地区无法直接访问 Anthropic API，需要配置代理地址到 `ANTHROPIC_BASE_URL`

---

## 详细使用指南

### 目录

- [自动版本更新](#自动版本更新)
- [镜像源自动检测](#镜像源自动检测)
- [地区限制绕过](#地区限制绕过)
- [高级用法](#高级用法)
- [卸载方法](#卸载方法)
- [故障排除](#故障排除)

## 自动版本更新

本仓库包含自动版本检查和更新机制：

### GitHub Actions 自动构建

工作流自动执行：
1. **每日检查**：每天 UTC 00:00 检查 npm registry 新版本
2. **版本对比**：对比 npm 版本与现有 GitHub Release
3. **智能构建**：仅检测到新版本时才构建
4. **自动发布**：自动创建 GitHub Release

### 本地版本检查器

使用 `check-update.sh` 脚本检查和下载更新：

```bash
# 交互式检查更新
bash check-update.sh

# 仅检查版本
bash check-update.sh --check-only

# 有更新则下载并安装
bash check-update.sh --install
```

## 镜像源自动检测

脚本内置智能镜像源检测系统，自动测试并选择最快的下载源：

### 支持的镜像源

| 类型 | 默认源 | 国内镜像源 |
|------|--------|-----------|
| **Node.js 二进制** | `nodejs.org/dist/` | 淘宝(npmmirror)、腾讯云 |
| **npm registry** | `registry.npmjs.org/` | `registry.npmmirror.com` |
| **nvm 安装脚本** | `raw.githubusercontent.com` | jsDelivr CDN、gitmirror |
| **GitHub API** | `api.github.com` | gitmirror、ghproxy、ghps.cc |

### 自定义镜像源

```bash
# 自定义 Node.js 镜像
export NODE_MIRROR=https://your-mirror.com/node/

# 自定义 npm registry
export NPM_MIRROR=https://your-registry.com

# 然后运行脚本
bash setup-claude-code.sh --auto-download
```

## 地区限制绕过

脚本已内置配置来自动绕过 Claude Code 的首次启动地区限制：

### 自动配置项

| 配置 | 作用 |
|------|------|
| `hasCompletedOnboarding: true` | 标记引导流程已完成 |
| `skipOnboarding: true` | 跳过首次启动引导 |
| `hasAcceptedTerms: true` | 标记已接受服务条款 |
| `telemetry.enabled: false` | 禁用遥测 |
| `DISABLE_AUTOUPDATER=1` | 禁用自动更新 |
| `CLAUDE_CODE_SKIP_FIRST_RUN=1` | 跳过首次运行检查 |
| `regionCheck.bypassed: true` | 标记地区检查已绕过 |

### 如果仍遇到地区问题

确保正确配置 API 端点（使用代理）：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-proxy-api-endpoint.com",
    "ANTHROPIC_API_KEY": "your-api-key"
  }
}
```

## 高级用法

### 脚本参数

| 参数 | 说明 |
|------|------|
| `--offline-path PATH` | 指定离线包路径 |
| `--auto-download` | 自动从 GitHub Release 下载 |
| `--force-download` | 强制重新下载，即使本地已有包 |
| `--skip-mirror-test` | 跳过镜像速度测试 |
| `--uninstall` | 卸载 Claude Code 及所有配置 |
| `--help, -h` | 显示帮助信息 |

### 环境变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `NODE_MIRROR` | 自定义 Node.js 镜像源 | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | 自定义 npm registry | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | 自定义 GitHub API 镜像 | `https://hub.gitmirror.com/https://api.github.com` |

### GitHub Actions 触发方式

1. **手动触发**:
   ```
   GitHub 页面 → Actions → Download Claude Code Offline Packages → Run workflow
   ```

2. **定时触发**:
   - 每天 UTC 00:00 自动检查新版本
   - 每周一 UTC 00:00 完整重建

## 卸载方法

```bash
# 卸载 Claude Code
bash setup-claude-code.sh --uninstall
```

卸载内容包括：
- ✅ 删除 `~/.claude/` 配置目录
- ✅ 删除 `~/.claude.json` 配置文件
- ✅ 从 `.bashrc` 中移除所有相关配置
- ✅ 可选：删除 Node.js 和 nvm（如果由本脚本安装）
- ✅ 卸载前自动备份配置

## 故障排除

### Node.js 安装失败

```bash
# 手动安装 nvm
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 20
nvm use 20

# 重新运行脚本
bash setup-claude-code.sh
```

### Claude 命令找不到

```bash
# 重新加载 shell 配置
source ~/.bashrc

# 或手动添加 PATH
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### API 连接失败

如果配置后仍无法使用，检查：
1. API 密钥是否正确
2. 网络是否可以访问配置的 `ANTHROPIC_BASE_URL`
3. 是否需要配置代理

## 许可证

与原 Claude Code 许可证一致。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

---

**注意**: Claude Code 和 Claude 标志是 Anthropic 的商标。本项目与 Anthropic 无关。
