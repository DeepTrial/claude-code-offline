# Claude Code オフライン展開ソリューション

> [简体中文](../../README.md) | [English](README.en.md) | [繁體中文](README.zh-TW.md) | [Русский](README.ru.md) | **日本語** | [한국어](README.ko.md)

[![GitHub Actions](https://img.shields.io/badge/GitHub%20Actions-Enabled-blue)](../../.github/workflows/download-claude-packages.yml)
[![Version](https://img.shields.io/badge/version-2.1-green)](../../setup-claude-code.sh)
[![License](https://img.shields.io/badge/license-MIT-yellow)](../../LICENSE)

自動ミラー検出、地域制限バイパス、多言語サポートを備えたインテリジェントな Claude Code オフライン展開ソリューション。

## 機能

- ✅ **GitHub Actions 自動ダウンロード**: npm から最新の Claude Code を自動的にダウンロードしてパッケージ化
- ✅ **マルチパス自動検出**: 自動的にオフラインパッケージを検索し、ハードコードされたパスは不要
- ✅ **ユニバーサル Node.js インストール**: nvm、apt、または直接バイナリダウンロードをサポート
- ✅ **フレキシブルな展開方法**: オフラインパッケージ、オンラインダウンロード、または直接 npm インストール
- ✅ **インテリジェントな設定管理**: 古い設定を自動的にクリーンアップ
- ✅ **🆕 ミラー自動検出**: 最も高速なダウンロードソースを自動的にテストして選択
- ✅ **🆕 地域制限バイパス**: 初回起動時の地域確認をスキップする自動設定
- ✅ **🆕 アンインストール機能**: バックアップサポート付きの完全なアンインストール

## クイックスタート

```bash
# 方法 1: 自動ダウンロード（ミラー検出付き、インターネットが必要）
bash setup-claude-code.sh --auto-download

# 方法 2: 特定のオフラインパッケージを使用
bash setup-claude-code.sh --offline-path /path/to/claude-offline-packages

# 方法 3: インタラクティブモード
bash setup-claude-code.sh
```

## ミラー自動検出

スクリプトには、自動的にテストして最も高速なダウンロードソースを選択するインテリジェントなミラー検出システムが組み込まれています。

### サポートされているミラー

| タイプ | デフォルトソース | ミラー |
|--------|----------------|--------|
| **Node.js バイナリ** | `nodejs.org/dist/` | npmmirror、Tencent Cloud |
| **npm registry** | `registry.npmjs.org/` | `registry.npmmirror.com` |
| **nvm インストールスクリプト** | `raw.githubusercontent.com` | jsDelivr CDN、gitmirror |
| **GitHub API** | `api.github.com` | gitmirror、ghproxy、ghps.cc |

## 地域制限バイパス

スクリプトには、Claude Code の初回起動時の地域制限を自動的にバイパスする組み込み設定があります。

## 完全なドキュメント

詳細については、以下のドキュメントを参照してください：
- [简体中文](../../README.md)
- [English](README.en.md)

## ライセンス

オリジナルの Claude Code と同じライセンス。

---

**注意**: Claude Code および Claude ロゴは Anthropic の商標です。このプロジェクトは Anthropic と提携していません。
