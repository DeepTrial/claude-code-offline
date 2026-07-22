# Claude Code オフライン展開ソリューション

> [简体中文](../../README.md) | [English](README.en.md) | [繁體中文](README.zh-TW.md) | [Русский](README.ru.md) | **日本語** | [한국어](README.ko.md)

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](../../.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.2-green)](../../setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](../../LICENSE)
[![Codex Offline](https://img.shields.io/badge/sister%20project-Codex%20Offline-blueviolet)](https://github.com/DeepTrial/codex-offline)

自動化された Claude Code オフライン展開ソリューション:毎日 npm から最新版の Claude Code を取得し、**Linux と Windows のデュアルプラットフォーム向けオフラインパッケージ**をビルドして、**自動インストールテスト**に合格した後に GitHub Releases へ公開します。ミラーソースの自動検出、地域制限の回避、完全オフラインインストール、Node.js なしの環境をサポートします。

## ✨ 特徴

- ✅ **毎日の自動ビルド**:GitHub Actions が毎日 npm の新バージョンをチェックし、自動でビルド・公開
- ✅ **デュアルプラットフォームパッケージ**:Linux x64(`tar.gz`)+ Windows x64(`zip`、ネイティブ PowerShell インストーラー)
- ✅ **テストゲート**:各パッケージは公開前にクリーンな環境(Node なしの Ubuntu コンテナ / Windows runner)で完全なインストール + 起動検証を実施。**テストに合格しなければリリースしない**
- ✅ **Node.js 不要**:claude-code 2.x は独立したネイティブバイナリ。ネイティブバイナリが検出された場合、Node.js はオプション
- ✅ **ネットワーク障害への耐性**:オンライン処理の前に 5 秒の事前チェック、npm/curl はすべてタイムアウト付き、失敗時は即座にエラーを報告し対処方法を提示。もう「フリーズ」しない
- ✅ **無人インストール**:`--yes` / `--non-interactive` モード。スクリプトや CI に最適
- ✅ **ミラーソース自動検出**:自動で速度測定し、最速の Node.js / npm / GitHub ミラーを選択
- ✅ **地域制限の回避**:初回起動時の地域検証をスキップするよう自動設定
- ✅ **20 個のオフライン Skills/Plugins**:ドキュメント処理、デザイン、テスト、LSP、マルチエージェントフレームワークなど
- ✅ **完全なアンインストール機能**:設定のバックアップ付きで徹底的にアンインストール
- ✅ **過去のバージョンをすべて保持**:Releases は自動クリーンアップされないため、いつでもロールバック可能

---

## 🚀 クイックスタート

### Linux / macOS / WSL

**方法 1:ワンラインインストール(ネットワーク必要)**

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

**方法 2:オフラインパッケージでインストール(ネットワーク不要)**

```bash
# Releases から claude-offline-packages-linux.tar.gz をダウンロードした後:
tar -xzf claude-offline-packages-linux.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh --yes
```

**方法 3:ローカルに既存のオフラインパッケージがある場合**

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

### Windows(ネイティブ)

1. [Releases](https://github.com/DeepTrial/claude-code-offline/releases) から `claude-offline-packages-windows.zip` をダウンロードして展開
2. `setup-claude-code.bat` をダブルクリックするか、PowerShell で実行:

```powershell
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -NonInteractive
```

インストーラーはネイティブの `claude.exe` を検証し、設定を生成し、`bin` ディレクトリをユーザー PATH に書き込みます(冪等)。`-OfflinePath` / `-AutoDownload` / `-NonInteractive` / `-Uninstall` / `-ConfigOnly` パラメータをサポートします。

---

## ⚠️ インストール後の必須作業(重要なステップ)

**使用するには、必ず自分の API キーを設定してください:**

```bash
# Linux/macOS/WSL
nano ~/.claude/settings.json

# Windows ではメモ帳で %USERPROFILE%\.claude\settings.json を開く
```

プレースホルダー値を置き換えます:

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-api-endpoint.com",
    "ANTHROPIC_API_KEY": "sk-your-api-key-here"
  }
}
```

その後、**新しいターミナルを開いて**(または `source ~/.bashrc` を実行して)確認します:

```bash
claude --version
```

> 💡 Anthropic API に直接接続できない地域では、`ANTHROPIC_BASE_URL` にプロキシ/中継アドレスを設定してください。

---

## 📦 Release の内容

| ファイル | プラットフォーム | 説明 |
|----------|------------------|------|
| `claude-offline-packages-linux.tar.gz` | Linux x64 / WSL | 完全なオフラインパッケージ(skills、jq、VSCode 拡張機能を含む) |
| `claude-offline-packages-windows.zip` | Windows x64 | ネイティブ Windows パッケージ(skills、jq.exe、PS1 インストーラーを含む) |
| `*.sha256` | - | チェックサムファイル:`sha256sum -c <file>.sha256` |

過去の Release は**すべて保持**されており、いつでも旧バージョンをダウンロードしてロールバックできます。

---

## 🔄 自動化パイプライン

```
check-version → build-offline-packages (linux) ─┐
              → build-windows-package (windows) ┴→ test-release-package → create-release
                                                  (ubuntu + windows 両環境でテスト)  (添付 4 ファイル)
```

- **毎日のチェック**:UTC 00:00 に npm の最新バージョンと既存の Release を比較し、新バージョンがある場合のみビルド
- **毎週の再ビルド**:毎週月曜 UTC 01:00 に完全再ビルド
- **手動トリガー**:Actions → `Download Claude Code Offline Packages` → Run workflow(バージョン指定/強制再ビルドが可能)
- **テストゲート**:テストジョブは、クリーンな ubuntu:22.04 コンテナ(Node なし)と windows-latest の両方で、構造チェック、`claude --version` アサーション、完全な非対話インストールを実行し、すべて合格した場合のみ公開

ローカルでの手動更新チェック:

```bash
bash check-update.sh              # 対話モード
bash check-update.sh --check-only # チェックのみ
bash check-update.sh --install    # ダウンロードしてインストール
```

---

## 🧩 組み込みオフライン Skills と Plugins(20 個)

ビルド時に `skills/skills-manifest.json` に従って自動ダウンロードされ、インストーラーの実行後に `~/.claude/` にインストールされます:

| カテゴリ | 内容 |
|----------|------|
| **ドキュメント処理** | docx、pdf、pptx、xlsx |
| **デザイン** | frontend-design、algorithmic-art、canvas-design、theme-factory、web-artifacts-builder |
| **テスト** | webapp-testing(Playwright) |
| **ツール** | skill-creator |
| **エンタープライズ** | brand-guidelines、internal-comms、doc-coauthoring |
| **プラグイン** | superpowers(TDD/デバッグ/プランニングのワークフローフレームワーク)、everything-claude-code(ECC:67 agents、278 skills、94 コマンド)、gitlab(セルフホストインスタンスを指定可能)、clangd-lsp、python-lsp、context7* |

> \* context7 はパッケージに含まれていますが、`offline_compatible=false` とマークされています(ドキュメントの取得にはネットワークが必要)。clangd-lsp / python-lsp は設定のみを含み、マシン上に別途 clangd / pyright が必要です。

---

## 🖥️ プラットフォームサポート

デフォルトでは **linux-x64** と **win32-x64** が自動ビルドされます。インストーラーはネイティブバイナリを検出した場合 Node.js をスキップします。Node.js ≥ 18(22 推奨)が必要になるのは、Node wrapper へフォールバックする場合のみです。

その他のプラットフォーム(linux-arm64、darwin、musl)は、リポジトリをフォークして workflow 内のプラットフォームパッケージ名を変更して自分でビルドするか、Release ページの説明に従って `npm pack` で手動組み立てしてください。

---

## 🛠️ 高度な使い方

### インストールスクリプトのパラメータ(bash)

| パラメータ | 説明 |
|------------|------|
| `--offline-path PATH` | オフラインパッケージのパスを指定 |
| `--auto-download` | GitHub Release から自動ダウンロード |
| `--force-download` | 強制的に再ダウンロード |
| `--skip-mirror-test` | ミラー速度測定をスキップ |
| `--yes, -y` | すべてのプロンプトに自動で yes(完全無人) |
| `--non-interactive` | 非対話モード。自動的にデフォルトの回答を採用 |
| `--config-only` | 設定ファイルのみ生成 |
| `--skills-only` | オフライン skills のみインストール |
| `--uninstall` | Claude Code と設定をアンインストール |
| `--help, -h` | ヘルプ |

### 環境変数(カスタムミラー)

| 変数 | 説明 | 例 |
|------|------|-----|
| `NODE_MIRROR` | Node.js ミラー | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | npm registry | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | GitHub API ミラー | `https://hub.gitmirror.com/https://api.github.com` |

---

## 🧪 インストールパッケージのテスト

CI で使用しているテストスクリプトは、ローカルでも実行できます:

```bash
# Linux パッケージ:構造チェック + バージョンアサーション + Node なしクリーンコンテナでのエンドツーエンドインストール
bash tests/test-linux-package.sh /path/to/claude-offline-packages 2.1.215
```

```powershell
# Windows パッケージ:バイナリチェック + インストーラー + settings.json + PATH レジストリアサーション
powershell -NoProfile -File tests\test-windows-package.ps1 `
  -PackageDir .\claude-offline-packages-windows -ExpectedVersion 2.1.215
```

---

## 🗑️ アンインストール

```bash
# Linux/macOS/WSL
bash setup-claude-code.sh --uninstall
```

```powershell
# Windows
powershell -NoProfile -ExecutionPolicy Bypass -File .\setup-claude-code.ps1 -Uninstall
```

アンインストール前に設定が自動でバックアップされ、設定ディレクトリ、`.claude.json`、shell/PATH 設定の完全なクリーンアップが行われます。

---

## 🔧 トラブルシューティング

### ネットワークエラー(もうフリーズしない)

インストーラーはオンライン処理の前に必ず 5 秒の接続事前チェックを行い、失敗時は**即座にエラーを報告**して対処方法を提示します:

- **`Network appears UNAVAILABLE`** — ネットワーク/プロキシ(`HTTPS_PROXY`)を確認するか、ミラーを変更してください:`NPM_MIRROR=https://registry.npmmirror.com bash setup-claude-code.sh --auto-download`
- **`npm registry UNREACHABLE / GitHub UNREACHABLE`** — 該当ホストへの 5 秒プローブがタイムアウト。そのホストを必要とするステップのみスキップまたは中止され、純粋なオフラインステップは継続します
- **`'npm ...' timed out after Ns`** — npm が内蔵タイムアウトを超過。通常は registry がブロックされているかプロキシが必要です。`NPM_MIRROR=...` で再試行してください

### Node.js がない環境

claude-code 2.x は Bun でコンパイルされた独立したネイティブバイナリです。利用可能なバイナリが検出されると、インストーラーは `Native binary detected, Node.js optional` と表示して Node のインストールをスキップします。Node がなくても正常に使用できます。

### Windows で tar.gz を展開した後に claude が起動しない(WSL のシナリオ)

Windows の展開ツール(エクスプローラー、7z など)は **symlink を破棄する**ため、Linux パッケージの `.bin/claude` が失われます。このインストーラーは自己修復します:実行のたびに `.bin/claude` を**実体のランチャースクリプト**として再構築するため、WSL で `setup-claude-code.sh` を再実行するだけで直ります。ネイティブ Windows で使う場合は `claude-offline-packages-windows.zip` を直接ダウンロードしてください。

### claude コマンドが見つからない

```bash
source ~/.bashrc   # または新しいターミナルを開く
# 手動で PATH を設定:
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### API 接続失敗

1. `ANTHROPIC_API_KEY` が正しいか確認
2. 設定した `ANTHROPIC_BASE_URL` にネットワークからアクセスできるか確認
3. プロキシが必要かどうか確認

---

## ライセンス

オリジナルの Claude Code ライセンスに準拠します。

## コントリビューション

このプロジェクトを改善するための Issue や Pull Request を歓迎します。

---

**注意**: Claude Code と Claude のロゴは Anthropic の商標です。本プロジェクトは Anthropic とは関係ありません。
