# Claude Code オフライン展開ソリューション

> [简体中文](../../README.md) | [English](README.en.md) | [繁體中文](README.zh-TW.md) | [Русский](README.ru.md) | **日本語** | [한국어](README.ko.md)

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](../../.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.1-green)](../../setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](../../LICENSE)

自動ミラー検出、地域制限バイパス、多言語サポートを備えたインテリジェントな Claude Code オフライン展開ソリューションです。

## 機能

- ✅ **GitHub Actions 自動ダウンロード**: npm から最新の Claude Code を自動的にダウンロードしてパッケージ化
- ✅ **マルチパス自動検出**: ハードコードされたパスなしでオフラインパッケージを自動検索
- ✅ **ユニバーサル Node.js インストール**: nvm、apt、または直接バイナリダウンロードをサポート
- ✅ **フレキシブルな展開方法**: オフラインパッケージ、オンラインダウンロード、または直接 npm インストール
- ✅ **インテリジェントな設定管理**: 古い設定を自動的にクリーンアップ
- ✅ **ビルトインクリーニングツール**: TMP ディレクトリクリーニングスクリプトを含む
- ✅ **🆕 ミラー自動検出**: 最も高速なダウンロードソースを自動的にテストして選択
- ✅ **🆕 地域制限バイパス**: 初回起動時の地域確認をスキップする自動設定
- ✅ **🆕 アンインストール機能**: バックアップサポート付きの完全なアンインストール

---

## 🚀 クイックスタート（3 つの方法）

### 方法 1：ワンラインインストール（推奨、インターネットが必要）

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/DeepTrial/claude-code-offline/main/setup-claude-code.sh) --auto-download
```

### 方法 2：オフラインパッケージを使用（インターネット不要）

1. [Releases](https://github.com/DeepTrial/claude-code-offline/releases) から `claude-offline-packages.tar.gz` をダウンロード
2. 解凍して実行：

```bash
tar -xzf claude-offline-packages.tar.gz
cd claude-offline-packages
bash setup-claude-code.sh
```

### 方法 3：既存のオフラインパッケージ

```bash
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages
```

---

## ⚠️ インストール後の必須作業（重要）

**インストール後、API キーを設定する必要があります：**

### 1. 設定ファイルの編集

```bash
nano ~/.claude/settings.json
```

### 2. 設定の更新

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

### 3. 設定の再読み込み

```bash
source ~/.bashrc
claude --version
```

> 💡 **ヒント**: Anthropic API に直接アクセスできない場合は、プロキシを `ANTHROPIC_BASE_URL` に設定してください

---

## 詳細な使用ガイド

### 目次

- [自動バージョン更新](#自動バージョン更新)
- [ミラー検出](#ミラー検出)
- [地域制限バイパス](#地域制限バイパス)
- [高度な使用方法](#高度な使用方法)
- [アンインストール](#アンインストール)
- [トラブルシューティング](#トラブルシューティング)

## 自動バージョン更新

このリポジトリには自動バージョン確認と更新メカニズムが含まれています：

### GitHub Actions 自動ビルド

ワークフローは自動的に：
1. **毎日の確認**: 毎日 UTC 00:00 に npm レジストリで新しいバージョンを確認
2. **バージョン比較**: npm バージョンと既存の GitHub Releases を比較
3. **スマートビルド**: 新しいバージョンが検出された場合のみビルド
4. **自動リリース**: GitHub Release を自動的に作成

### ローカルバージョンチェッカー

`check-update.sh` を使用して更新を確認およびダウンロード：

```bash
# インタラクティブ確認
bash check-update.sh

# 確認のみ
bash check-update.sh --check-only

# 更新が利用可能な場合はダウンロードしてインストール
bash check-update.sh --install
```

## ミラー検出

スクリプトには、自動的にテストして最も高速なダウンロードソースを選択するインテリジェントなミラー検出システムが組み込まれています。

### サポートされているミラー

| タイプ | デフォルト | ミラー |
|--------|------------|--------|
| **Node.js バイナリ** | `nodejs.org/dist/` | npmmirror, Tencent Cloud |
| **npm レジストリ** | `registry.npmjs.org/` | `registry.npmmirror.com` |
| **nvm スクリプト** | `raw.githubusercontent.com` | jsDelivr CDN, gitmirror |
| **GitHub API** | `api.github.com` | gitmirror, ghproxy, ghps.cc |

### カスタムミラー

```bash
export NODE_MIRROR=https://your-mirror.com/node/
export NPM_MIRROR=https://your-registry.com
bash setup-claude-code.sh --auto-download
```

## 地域制限バイパス

Claude Code の初回起動時の地域制限を自動的にバイパスする組み込み設定です。

### それでも地域の問題が発生する場合

正しい API エンドポイント（プロキシを使用）を確認：

```json
{
  "env": {
    "ANTHROPIC_BASE_URL": "https://your-proxy-api-endpoint.com",
    "ANTHROPIC_API_KEY": "your-api-key"
  }
}
```

## 高度な使用方法

### スクリプトパラメータ

| パラメータ | 説明 |
|------------|------|
| `--offline-path PATH` | オフラインパッケージパスを指定 |
| `--auto-download` | GitHub Release から自動ダウンロード |
| `--force-download` | 強制的に再ダウンロード |
| `--skip-mirror-test` | ミラースピードテストをスキップ |
| `--uninstall` | Claude Code をアンインストール |
| `--help, -h` | ヘルプを表示 |

### 環境変数

| 変数 | 説明 | 例 |
|------|------|-----|
| `NODE_MIRROR` | カスタム Node.js ミラー | `https://npmmirror.com/mirrors/node/` |
| `NPM_MIRROR` | カスタム npm レジストリ | `https://registry.npmmirror.com` |
| `GITHUB_MIRROR` | カスタム GitHub ミラー | `https://hub.gitmirror.com/...` |

## アンインストール

```bash
bash setup-claude-code.sh --uninstall
```

含まれるもの：
- `~/.claude/` ディレクトリの削除
- `~/.claude.json` の削除
- `.bashrc` からの設定削除
- オプション：Node.js と nvm の削除
- アンインストール前の自動バックアップ

## トラブルシューティング

### Node.js インストール失敗

```bash
curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.7/install.sh | bash
source ~/.nvm/nvm.sh
nvm install 20
nvm use 20
bash setup-claude-code.sh
```

### Claude コマンドが見つからない

```bash
source ~/.bashrc
# または
export PATH="/path/to/claude-offline-packages/node_modules/.bin:$PATH"
```

### API 接続失敗

確認事項：
1. API キーが正しい
2. ネットワークが `ANTHROPIC_BASE_URL` にアクセスできる
3. プロキシ設定が必要か

## ライセンス

オリジナルの Claude Code と同じライセンス。

## 貢献

Issues と Pull Requests を歓迎します。

---

**注意**: Claude Code およびロゴは Anthropic の商標です。このプロジェクトは Anthropic と提携していません。
