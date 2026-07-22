# Claude Code 離線部署方案

> [简体中文](../../README.md) | [English](README.en.md) | **繁體中文** | [Русский](README.ru.md) | [日本語](README.ja.md) | [한국어](README.ko.md)

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](../../.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/npm/v/@anthropic-ai/claude-code?label=version&color=green)](https://www.npmjs.com/package/@anthropic-ai/claude-code)
[![License](https://img.shields.io/badge/license-MIT-yellow)](../../LICENSE)
[![Codex Offline](https://img.shields.io/badge/sister%20project-Codex%20Offline-blueviolet)](https://github.com/DeepTrial/codex-offline)

自動化的 Claude Code 離線部署方案:每天自動從 npm 拉取最新版 Claude Code,建置 **Linux 與 Windows 雙平台離線套件**,經過**自動化安裝測試**後發佈到 GitHub Releases。支援鏡像來源自動偵測、地區限制繞過、純離線安裝與無 Node.js 環境。

## ✨ 功能特色

- ✅ **每日自動建置**:GitHub Actions 每天檢查 npm 新版本,自動建置並發佈
- ✅ **雙平台安裝套件**:Linux x64(`tar.gz`)+ Windows x64(`zip`,原生 PowerShell 安裝程式)
- ✅ **測試門禁**:每個套件發佈前都在乾淨環境(無 Node 的 ubuntu 容器 / Windows runner)中執行完整安裝 + 啟動驗證,**測試不通過就不發版**
- ✅ **無需 Node.js**:claude-code 2.x 是獨立原生二進位檔案,偵測到原生二進位檔案時 Node.js 為選裝
- ✅ **抗網路抖動**:連網前 5 秒預檢、npm/curl 全部帶逾時、失敗立即報錯並給出排查建議,不再「卡死」
- ✅ **無人值守安裝**:`--yes` / `--non-interactive` 模式,適合腳本與 CI
- ✅ **鏡像來源自動偵測**:自動測速選擇最快的 Node.js / npm / GitHub 鏡像
- ✅ **地區限制繞過**:自動設定跳過首次啟動的地區驗證
- ✅ **20 個離線 Skills/Plugins**:文件處理、設計、測試、LSP、多智慧體框架等
- ✅ **完整解除安裝功能**:支援設定備份的徹底解除安裝
- ✅ **歷史版本全部保留**:Releases 不再自動清理,可隨時回退

---

## 🚀 快速開始

### Linux / macOS / WSL

**方式 1:一行指令安裝(需要網路)**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

**方式 2:離線套件安裝(無需網路)**

```bash
# 從 Releases 下載 claude-offline-packages-linux.tar.gz 後:
tar -xzf claude-offline-packages-linux.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh --yes
```

**方式 3:本機已有離線套件**

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

### Windows(原生)

1. 從 [Releases](https://github.com/DeepTrial/claude-code-offline/releases) 下載 `claude-offline-packages-windows.zip` 並解壓縮
2. 按兩下 `setup-claude-code.bat`,或在 PowerShell 中執行:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -NonInteractive
```

安裝程式會驗證原生 `claude.exe`、產生設定,並把 `bin` 目錄寫入使用者 PATH(冪等)。支援 `-OfflinePath` / `-AutoDownload` / `-NonInteractive` / `-Uninstall` / `-ConfigOnly` 參數。

---

## ⚠️ 安裝後必做(關鍵步驟)

**必須設定自己的 API 金鑰才能使用:**

```bash
# Linux/macOS/WSL
nano ~/.claude/settings.json

# Windows 用記事本開啟 %USERPROFILE%\.claude\settings.json
```

替換佔位值:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-api-endpoint.com",
    "ANTHROPIC_API_KEY": "sk-your-api-key-here"
  }
}
```

然後**開啟新終端機**(或 `source ~/.bashrc`),驗證:

```bash
claude --version
```

> 💡 無法直接連線 Anthropic API 的地區,把 `ANTHROPIC_BASE_URL` 設定為你的代理/中轉位址。

---

## 📦 Release 內容

| 檔案 | 平台 | 說明 |
|------|------|------|
| `claude-offline-packages-linux.tar.gz` | Linux x64 / WSL | 完整離線套件(含 skills、jq、VSCode 擴充功能) |
| `claude-offline-packages-windows.zip` | Windows x64 | 原生 Windows 套件(含 skills、jq.exe、PS1 安裝程式) |
| `*.sha256` | - | 校驗檔案:`sha256sum -c <file>.sha256` |

歷史 Release **全部保留**,可隨時下載舊版本回退。

---

## 🔄 自動化流水線

```
check-version → build-offline-packages (linux) ─┐
              → build-windows-package (windows) ┴→ test-release-package → create-release
                                                  (ubuntu + windows 雙端測試)   (4 個附件)
```

- **每日檢查**:UTC 00:00 比對 npm 最新版與現有 Release,有新版本才建置
- **每週重建**:每週一 UTC 01:00 完整重建
- **手動觸發**:Actions → `Download Claude Code Offline Packages` → Run workflow(可指定版本/強制重建)
- **測試門禁**:測試 job 在乾淨 ubuntu:22.04 容器(無 Node)和 windows-latest 上分別執行結構校驗、`claude --version` 斷言、完整非互動安裝,全部通過才會發佈

本機手動檢查更新:

```bash
bash check-update.sh              # 互動式
bash check-update.sh --check-only # 僅檢查
bash check-update.sh --install    # 下載並安裝
```

---

## 🧩 內建離線 Skills 與 Plugins(20 個)

建置時按 `skills/skills-manifest.json` 自動下載,安裝程式執行後裝入 `~/.claude/`:

| 分類 | 內容 |
|------|------|
| **文件處理** | docx、pdf、pptx、xlsx |
| **設計** | frontend-design、algorithmic-art、canvas-design、theme-factory、web-artifacts-builder |
| **測試** | webapp-testing(Playwright) |
| **工具** | skill-creator |
| **企業** | brand-guidelines、internal-comms、doc-coauthoring |
| **外掛** | superpowers(TDD/除錯/規劃工作流程框架)、everything-claude-code(ECC:67 agents、278 skills、94 指令)、gitlab(可指向自建實例)、clangd-lsp、python-lsp、context7* |

> \* context7 已打包但標記為 `offline_compatible=false`(拉取文件需要連網)。clangd-lsp / python-lsp 僅含設定,需本機另有 clangd / pyright。

---

## 🖥️ 平台支援

預設自動建置 **linux-x64** 與 **win32-x64**。安裝程式在偵測到原生二進位檔案時跳過 Node.js;僅當需要回退到 Node wrapper 時才要求 Node.js ≥ 18(建議 22)。

其他平台(linux-arm64、darwin、musl)可 fork 後修改 workflow 中的平台套件名稱自行建置,或參考 Release 頁面說明用 `npm pack` 手工組包。

---

## 🛠️ 進階用法

### 安裝腳本參數(bash)

| 參數 | 說明 |
|------|------|
| `--offline-path PATH` | 指定離線套件路徑 |
| `--auto-download` | 自動從 GitHub Release 下載 |
| `--force-download` | 強制重新下載 |
| `--skip-mirror-test` | 跳過鏡像測速 |
| `--yes, -y` | 所有提示自動 yes(完全無人值守) |
| `--non-interactive` | 非互動模式,自動採用預設答案 |
| `--config-only` | 只產生設定檔 |
| `--skills-only` | 只安裝離線 skills |
| `--uninstall` | 解除安裝 Claude Code 及設定 |
| `--help, -h` | 說明 |

### 環境變數(自訂鏡像)

| 變數 | 說明 | 範例 |
|------|------|------|
| `NODE_MIRROR` | Node.js 鏡像 | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | npm registry | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | GitHub API 鏡像 | `https://hub.gitmirror.com/https://api.github.com` |

---

## 🧪 測試安裝套件

CI 使用的測試腳本同樣可在本機執行:

```bash
# Linux 套件:結構校驗 + 版本斷言 + 無 Node 乾淨容器端到端安裝
bash tests/test-linux-package.sh /path/to/claude-offline-packages 2.1.215
```

```powershell
# Windows 套件:二進位校驗 + 安裝程式 + settings.json + PATH 登錄檔斷言
powershell -NoProfile -File tests\test-windows-package.ps1 `
  -PackageDir .\claude-offline-packages-windows -ExpectedVersion 2.1.215
```

---

## 🗑️ 解除安裝

```bash
# Linux/macOS/WSL
bash setup-claude-code.sh --uninstall
```

```powershell
# Windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -Uninstall
```

解除安裝前會自動備份設定,包含設定目錄、`.claude.json`、shell/PATH 設定的完整清理。

---

## 🔧 疑難排解

### 網路錯誤(不再卡死)

安裝程式在任何連網步驟前都會做 5 秒連通性預檢,失敗會**立即報錯**並給出建議:

- **`Network appears UNAVAILABLE`** — 檢查網路/代理(`HTTPS_PROXY`),或換鏡像:`NPM_MIRROR=https://registry.npmmirror.com bash setup-claude-code.sh --auto-download`
- **`npm registry UNREACHABLE / GitHub UNREACHABLE`** — 對應主機 5 秒探測逾時;僅需要該主機的步驟會跳過或中止,純離線步驟繼續
- **`'npm ...' timed out after Ns`** — npm 超過內建逾時,通常是 registry 被封鎖或需要代理,用 `NPM_MIRROR=...` 重試

### 無 Node.js 環境

claude-code 2.x 是 Bun 編譯的獨立原生二進位檔案。偵測到可用二進位檔案時安裝程式會印出 `Native binary detected, Node.js optional` 並跳過 Node 安裝——沒有 Node 也能正常使用。

### 在 Windows 上解壓縮 tar.gz 後 claude 無法啟動(WSL 情境)

Windows 解壓縮工具(檔案總管、7z 等)會**捨棄 symlink**,導致 Linux 套件的 `.bin/claude` 遺失。本安裝程式已自癒:每次執行都會把 `.bin/claude` 重建為**實體 launcher 腳本**,在 WSL 裡重跑一次 `setup-claude-code.sh` 即可。原生 Windows 使用請直接下載 `claude-offline-packages-windows.zip`。

### 找不到 Claude 指令

```bash
source ~/.bashrc   # 或開啟新終端機
# 手動 PATH:
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### API 連線失敗

1. 檢查 `ANTHROPIC_API_KEY` 是否正確
2. 檢查網路能否存取設定的 `ANTHROPIC_BASE_URL`
3. 確認是否需要代理

---

## 授權條款

與原 Claude Code 授權條款一致。

## 貢獻

歡迎提交 Issue 和 Pull Request 來改進這個專案。

---

**注意**:Claude Code 和 Claude 標誌是 Anthropic 的商標。本專案與 Anthropic 無關。
