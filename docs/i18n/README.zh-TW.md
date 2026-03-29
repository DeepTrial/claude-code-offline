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
- ✅ **🆕 鏡像源自動檢測**: 自動測試並選擇最快的下載源（Node.js、npm、GitHub）
- ✅ **🆕 地區限制繞過**: 自動配置跳過首次啟動的地區驗證
- ✅ **🆕 卸載功能**: 完整的卸載功能，支援備份

## 目錄

- [快速開始](#快速開始)
- [特性](#特性)
- [鏡像源自動檢測](#鏡像源自動檢測)
- [地區限制繞過](#地區限制繞過)
- [使用方法](#使用方法)
- [卸載功能](#卸載功能)
- [腳本參數](#腳本參數)
- [環境變量](#環境變量)
- [GitHub Actions 工作流](#github-actions-工作流)
- [配置說明](#配置說明)
- [故障排除](#故障排除)

## 快速開始

```bash
# 方式 1: 自動下載（帶鏡像檢測，需要網絡）
bash setup-claude-code.sh --auto-download

# 方式 2: 使用指定離線包
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages

# 方式 3: 交互式模式（自動檢測或提示）
bash setup-claude-code.sh
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

## 地區限制繞過

腳本已內置配置來自動繞過 Claude Code 的首次啟動地區限制。如需使用，請確保配置正確的 API 端點（使用代理）。

## 使用方法

### 方式 1: GitHub Actions 自動下載（推薦）

1. **Fork 本倉庫**到你的 GitHub 賬戶
2. **手動觸發工作流**: Actions → Download Claude Code Offline Packages → Run workflow
3. **下載構建產物**並在目標機器上運行

### 方式 2-4

參見主文檔的詳細說明。

## 卸載功能

```bash
bash setup-claude-code.sh --uninstall
```

## 完整文檔

請參閱 [简体中文文檔](../../README.md) 或 [English Documentation](README.en.md) 獲取完整信息。

---

**注意**: Claude Code 和 Claude 標誌是 Anthropic 的商標。本項目與 Anthropic 無關。
