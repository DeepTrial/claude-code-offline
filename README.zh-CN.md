# Claude Code 离线部署方案

> 中文 | [English](README.md)

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

## 目录

- [快速开始](#快速开始)
- [特性](#特性)
- [镜像源自动检测](#镜像源自动检测)
- [地区限制绕过](#地区限制绕过)
- [使用方法](#使用方法)
- [卸载功能](#卸载功能)
- [脚本参数](#脚本参数)
- [环境变量](#环境变量)
- [GitHub Actions 工作流](#github-actions-工作流)
- [配置说明](#配置说明)
- [故障排除](#故障排除)

## 自动版本更新

本仓库包含自动版本检查和更新机制：

### GitHub Actions 自动构建

工作流自动执行：
1. **每日检查**：每天 UTC 00:00 检查 npm registry 新版本
2. **版本对比**：对比 npm 版本与现有 GitHub Release
3. **智能构建**：仅检测到新版本时才构建
4. **自动发布**：自动创建 GitHub Release

### 定时任务

| 触发器 | 定时 | 动作 |
|--------|------|------|
| 每日检查 | `0 0 * * *` | 检查 npm 新版本，有新版本则构建 |
| 每周重建 | `0 0 * * 1` | 每周一完整重建 |
| 手动触发 | `workflow_dispatch` | 手动触发，支持强制重建 |

### 本地版本检查器

使用 `check-update.sh` 脚本检查和下载更新：

```bash
# 交互式检查更新
bash check-update.sh

# 仅检查版本
bash check-update.sh --check-only

# 有更新则下载
bash check-update.sh --download

# 有更新则下载并安装
bash check-update.sh --install
```

### 强制重建

如需重建已有版本：

1. 进入 GitHub Actions → "Download Claude Code Offline Packages"
2. 点击 "Run workflow"
3. 勾选 "Force rebuild even if version exists"
4. 点击 "Run workflow"

## 快速开始

```bash
# 方式 1: 自动下载（带镜像检测，需要网络）
bash setup-claude-code.sh --auto-download

# 方式 2: 使用指定离线包
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages

# 方式 3: 交互式模式（自动检测或提示）
bash setup-claude-code.sh
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

### 自动检测过程

1. 脚本会测试所有可用的镜像源连接速度
2. 自动选择延迟最低的镜像源
3. 如果某个源无法访问，自动尝试下一个
4. 下载过程中失败会自动切换到备用源

### 自定义镜像源

可以通过环境变量覆盖默认镜像源：

```bash
# 自定义 Node.js 镜像
export NODE_MIRROR=https://your-mirror.com/node/

# 自定义 npm registry
export NPM_MIRROR=https://your-registry.com

# 自定义 GitHub 镜像
export GITHUB_MIRROR=https://your-github-proxy.com

# 然后运行脚本
bash setup-claude-code.sh --auto-download
```

### 跳过镜像检测

如果网络环境稳定，可以跳过镜像检测加速脚本启动：

```bash
bash setup-claude-code.sh --auto-download --skip-mirror-test
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

### Wrapper 脚本

脚本会创建一个包装脚本 `~/.claude/claude-wrapper.sh`，自动设置必要的环境变量。

在 `.bashrc` 中添加了 alias，使用 `claude` 命令时会自动调用 wrapper。

### 如果仍遇到地区问题

确保正确配置 API 端点（使用代理）：

```json
// ~/.claude/settings.json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-proxy-api-endpoint.com",
    "ANTHROPIC_API_KEY": "your-api-key"
  }
}
```

或使用支持 Claude API 的第三方服务。

## 使用方法

### 方式 1: GitHub Actions 自动下载（推荐）

1. **Fork 本仓库**到你的 GitHub 账户

2. **手动触发工作流**:
   - 进入 GitHub 仓库页面
   - 点击 "Actions" 标签
   - 选择 "Download Claude Code Offline Packages"
   - 点击 "Run workflow"

3. **下载构建产物**:
   - 工作流完成后，在 "Artifacts" 部分下载 `claude-offline-packages`

4. **在目标机器上运行**:
   ```bash
   # 解压下载的包
   tar -xzf claude-offline-packages.tar.gz
   
   # 运行安装脚本
   cd claude-offline-packages
   bash setup-claude-code.sh
   ```

### 方式 2: 自动下载模式

如果目标机器有互联网连接，可以直接让脚本从 GitHub Release 下载：

```bash
bash setup-claude-code.sh --auto-download
```

### 方式 3: 指定离线包路径

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

### 方式 4: 直接 npm 安装

如果目标机器有互联网连接且有 Node.js >= 18：

```bash
bash setup-claude-code.sh
# 选择选项 3: Install Claude Code directly via npm
```

## 卸载功能

如果已经安装了 Claude Code，可以使用卸载功能完全移除：

```bash
# 卸载 Claude Code
bash setup-claude-code.sh --uninstall
```

### 卸载内容包括

- ✅ 删除 `~/.claude/` 配置目录
- ✅ 删除 `~/.claude.json` 配置文件
- ✅ 从 `.bashrc` 中移除所有相关配置（PATH、TMPDIR、NVM、Node.js）
- ✅ 可选：删除下载的离线包
- ✅ 可选：删除 Node.js（如果安装到 `~/.local/node`）
- ✅ 可选：删除 nvm（如果由本脚本安装）
- ✅ 卸载前自动备份配置（可选）

### 安装前检测

运行安装脚本时，会自动检测是否已有安装：

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

## 脚本参数

| 参数 | 说明 |
|------|------|
| `--offline-path PATH` | 指定离线包路径 |
| `--auto-download` | 自动从 GitHub Release 下载 |
| `--force-download` | 强制重新下载，即使本地已有包 |
| `--skip-mirror-test` | 跳过镜像速度测试 |
| `--uninstall` | 卸载 Claude Code 及所有配置 |
| `--help, -h` | 显示帮助信息 |

## 环境变量

| 变量 | 说明 | 示例 |
|------|------|------|
| `NODE_MIRROR` | 自定义 Node.js 镜像源 | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | 自定义 npm registry | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | 自定义 GitHub API 镜像 | `https://hub.gitmirror.com/https://api.github.com` |

## GitHub Actions 工作流

工作流配置在 `.github/workflows/download-claude-packages.yml`，功能包括：

- 每周一自动检查更新（cron 定时任务）
- 手动触发支持
- 自动下载 Claude Code npm 包
- 打包并上传到 GitHub Release
- 生成 SHA256 校验文件
- 尝试下载 VSCode 扩展

### 触发方式

1. **手动触发**:
   ```
   GitHub 页面 → Actions → Download Claude Code Offline Packages → Run workflow
   ```

2. **定时触发**:
   - 每周一 UTC 00:00 自动运行

3. **发布触发**:
   - 创建新 Release 时自动运行

## 配置说明

安装完成后，需要编辑配置文件添加你的 API 密钥：

```bash
nano ~/.claude/settings.json
```

替换以下占位符：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://api.anthropic.com",  // 或你的代理地址
    "ANTHROPIC_API_KEY": "sk-...",                       // 你的 API 密钥
    "ANTHROPIC_DEFAULT_OPUS_MODEL": "claude-3-opus-...",
    "ANTHROPIC_DEFAULT_SONNET_MODEL": "claude-3-sonnet-...",
    "ANTHROPIC_DEFAULT_HAIKU_MODEL": "claude-3-haiku-..."
  }
}
```

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

### 离线包下载失败

```bash
# 检查网络连接
curl -I https://api.github.com

# 使用代理
export https_proxy=http://proxy.example.com:8080
bash setup-claude-code.sh --auto-download
```

### Claude 命令找不到

```bash
# 重新加载 shell 配置
source ~/.bashrc

# 或手动添加 PATH
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

## 许可证

与原 Claude Code 许可证一致。

## 贡献

欢迎提交 Issue 和 Pull Request 来改进这个项目。

---

**注意**: Claude Code 和 Claude 标志是 Anthropic 的商标。本项目与 Anthropic 无关。
