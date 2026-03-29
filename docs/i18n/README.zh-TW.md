# Claude Code 離線部署方案

> [简体中文](../../README.md) | [English](README.en.md) | **繁體中文** | [Русский](README.ru.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](../../.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.1-green)](../../setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](../../LICENSE)

一個智能的 Claude Code 離線部署方案，支援自動鏡像源檢測、地區限制繞過和多語言支援。

## 特性

- ✅ **GitHub Actions 自動下載**: 自動從 npm 下載最新 Claude Code 並打包
- ✅ **多路徑自動檢測**: 自動查找離線包，無需硬編碼路徑
- ✅ **通用 Node.js 安裝**: 支援 nvm、apt 或直接下載二進制文件安裝 Node.js
- ✅ **靈活的部署方式**: 支援離線包、在線下載或直接 npm 安裝
- ✅ **智能配置管理**: 自動清理舊配置，保持 .bashrc 整潔
- ✅ **內置清理工具**: 包含 TMP 目錄清理腳本
- ✅ **🆕 鏡像源自動檢測**: 自動測試並選擇最快的下載源
- ✅ **🆕 地區限制繞過**: 自動配置跳過首次啟動的地區驗證
- ✅ **🆕 卸載功能**: 完整的卸載功能，支援備份

---

## 🚀 快速開始（3 種方式）

### 方式 1：一行命令安裝（推薦，需要網絡）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

### 方式 2：使用離線包安裝（無需網絡）

1. 從 [Releases](https://github.com/DeepTrial/claude-code-offline/releases) 下載 `claude-offline-packages.tar.gz`
2. 解壓並運行：

```bash
tar -xzf claude-offline-packages.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh
```

### 方式 3：本地已有離線包

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

---

## ⚠️ 安裝後必做（關鍵步驟）

安裝完成後，**必須配置 API 密鑰**才能使用：

### 1. 編輯配置文件

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

### 3. 重新加載配置

```bash
source ~/.bashrc
claude --version
```

> 💡 **提示**：如果你所在地區無法直接訪問 Anthropic API，需要配置代理地址到 `ANTHROPIC_BASE_URL`

---

## 詳細使用指南

### 目錄

- [自動版本更新](#自動版本更新)
- [鏡像源自動檢測](#鏡像源自動檢測)
- [地區限制繞過](#地區限制繞過)
- [高級用法](#高級用法)
- [卸載方法](#卸載方法)
- [故障排除](#故障排除)

## 自動版本更新

本倉庫包含自動版本檢查和更新機制：

### GitHub Actions 自動構建

工作流自動執行：
1. **每日檢查**：每天 UTC 00:00 檢查 npm registry 新版本
2. **版本對比**：對比 npm 版本與現有 GitHub Release
3. **智能構建**：僅檢測到新版本時才構建
4. **自動發布**：自動創建 GitHub Release

### 本地版本檢查器

使用 `check-update.sh` 腳本檢查和下載更新：

```bash
# 交互式檢查更新
bash check-update.sh

# 僅檢查版本
bash check-update.sh --check-only

# 有更新則下載並安裝
bash check-update.sh --install
```

## 鏡像源自動檢測

腳本內置智能鏡像源檢測系統，自動測試並選擇最快的下載源：

### 支援的鏡像源

| 類型 | 默認源 | 國內鏡像源 |
|------|--------|-----------|
| **Node.js 二進制** | `nodejs.org/dist/` | 淘寶(npmmirror)、騰訊雲 |
| **npm registry** | `registry.npmjs.org/` | `registry.npmmirror.com` |
| **nvm 安裝腳本** | `raw.githubusercontent.com` | jsDelivr CDN、gitmirror |
| **GitHub API** | `api.github.com` | gitmirror、ghproxy、ghps.cc |

### 自定義鏡像源

```bash
# 自定義 Node.js 鏡像
export NODE_MIRROR=https://your-mirror.com/node/

# 自定義 npm registry
export NPM_MIRROR=https://your-registry.com

# 然後運行腳本
bash setup-claude-code.sh --auto-download
```

## 地區限制繞過

腳本已內置配置來自動繞過 Claude Code 的首次啟動地區限制。

### 如果仍遇到地區問題

確保正確配置 API 端點（使用代理）：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-proxy-api-endpoint.com",
    "ANTHROPIC_API_KEY": "your-api-key"
  }
}
```

## 高級用法

### 腳本參數

| 參數 | 說明 |
|------|------|
| `--offline-path PATH` | 指定離線包路徑 |
| `--auto-download` | 自動從 GitHub Release 下載 |
| `--force-download` | 強制重新下載 |
| `--skip-mirror-test` | 跳過鏡像速度測試 |
| `--uninstall` | 卸載 Claude Code |
| `--help, -h` | 顯示幫助 |

### 環境變量

| 變量 | 說明 | 示例 |
|------|------|------|
| `NODE_MIRROR` | 自定義 Node.js 鏡像源 | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | 自定義 npm registry | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | 自定義 GitHub API 鏡像 | `https://hub.gitmirror.com/...` |

## 卸載方法

```bash
bash setup-claude-code.sh --uninstall
```

卸載內容包括：
- ✅ 刪除 `~/.claude/` 配置目錄
- ✅ 刪除 `~/.claude.json` 配置文件
- ✅ 從 `.bashrc` 中移除所有相關配置
- ✅ 可選：刪除 Node.js 和 nvm
- ✅ 卸載前自動備份配置

## 故障排除

### Node.js 安裝失敗

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 20
nvm use 20
bash setup-claude-code.sh
```

### Claude 命令找不到

```bash
source ~/.bashrc
# 或
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### API 連接失敗

檢查：
1. API 密鑰是否正確
2. 網絡是否可以訪問配置的 `ANTHROPIC_BASE_URL`
3. 是否需要配置代理

## 許可證

與原 Claude Code 許可證一致。

## 貢獻

歡迎提交 Issue 和 Pull Request 來改進這個項目。

---

**注意**: Claude Code 和 Claude 標誌是 Anthropic 的商標。本項目與 Anthropic 無關。
