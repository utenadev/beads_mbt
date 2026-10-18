# beads_mbt - MoonBit 版 Beads

Rust で実装された [beads_rust](https://github.com/Dicklesworthstone/beads_rust) を MoonBit に移植したプロジェクトです。

## 概要

beads は、Git リポジトリ向けのローカルファーストなイシュートラッカーです。このプロジェクトは、Rust 実装を MoonBit 言語に移植することを目的としています。

## インストール

```bash
# リポジトリのクローン
git clone https://github.com/utenadev/beads_mbt.git
cd beads_mbt

# ビルド
moon build cmd/main --target native
```

## クイックコマンド

```bash
just           # check + test
just fmt       # フォーマット
just fmt-check # フォーマット確認
just check     # 型チェック
just test      # テスト実行
just test-update  # スナップショット更新
just run       # メイン実行
just info      # 型定義ファイル生成
just e2e       # E2Eテスト実行
just ci        # ローカルCI
just ci-all    # 全ターゲットCI
just release-check-all  # リリース前チェック
```

## 使い方

### 初期化
```bash
moon run cmd/main -- init
```

### Issue 作成
```bash
moon run cmd/main -- create "Issue のタイトル"
```

### Issue 一覧表示
```bash
moon run cmd/main -- list
```

### Issue 詳細表示
```bash
moon run cmd/main -- show "bd-xxxxxx"
```

### Issue 更新
```bash
moon run cmd/main -- update "bd-xxxxxx" --title "新しいタイトル"
```

### Issue 完了
```bash
moon run cmd/main -- close "bd-xxxxxx"
```

### 着手可能 Issue 表示
```bash
moon run cmd/main -- ready
```

### Issue 延期
```bash
moon run cmd/main -- defer "bd-xxxxxx"
```

### ブロック中 Issue 表示
```bash
moon run cmd/main -- blocked
```

### Issue 検索
```bash
moon run cmd/main -- search "検索クエリ"
```

### 依存関係の管理
```bash
moon run cmd/main -- dep add "bd-xxxxxx" "bd-yyyyyy"
moon run cmd/main -- dep remove "bd-xxxxxx" "bd-yyyyyy"
moon run cmd/main -- dep list "bd-xxxxxx"
```

### ラベルの管理
```bash
moon run cmd/main -- label add "bd-xxxxxx" "bug"
moon run cmd/main -- label remove "bd-xxxxxx" "bug"
moon run cmd/main -- label list "bd-xxxxxx"
moon run cmd/main -- label list-all
```

### コメントの管理
```bash
moon run cmd/main -- comments add "bd-xxxxxx" "コメント本文"
moon run cmd/main -- comments list "bd-xxxxxx"
```

## 実装済み機能

| コマンド | 機能 | 状態 |
|---------|------|------|
| `init` | SQLite DB 初期化 | ✅ |
| `create` | Issue 作成 | ✅ |
| `list` | Issue 一覧表示 | ✅ |
| `show` | Issue 詳細表示 | ✅ |
| `update` | Issue 更新（タイトル、優先度） | ✅ |
| `close` | Issue 完了 | ✅ |
| `ready` | 着手可能 Issue 表示 | ✅ |
| `defer` | Issue 延期 | ✅ |
| `blocked` | ブロック中 Issue 表示 | ✅ |
| `search` | Issue 検索 | ✅ |
| `dep` | 依存関係の管理（add/remove/list） | ✅ |
| `label` | ラベルの管理（add/remove/list/list-all） | ✅ |
| `comments` | コメントの管理（add/list） | ✅ |
| `sync` | JSONL sync | ❌ |

## 開発者向け

### ビルドコマンド
```bash
# ビルド
moon build cmd/main --target native

# 実行
moon run cmd/main -- <command>

# テスト
moon test

# フォーマット
moon fmt

# インターフェース生成
moon info
```

### 依存関係
```
// moon.mod
import {
  "moonbit-community/sqlite3@0.2.3",
  "moonbitlang/x@0.5.5",
}
```

MoonBit ツールチェーン `moon` 0.1.20261012（`moonc` v0.10.15）でビルド・テストしています。

## 既知の問題
1. **JSONL sync**: 未実装（`sync` はプレースホルダーメッセージを表示）
2. **エラーメッセージ**: 英語のみ

## 今後の作業
1. **JSONL sync**: データベースから JSONL への同期
2. **テスト**: 包括的なテストスイート
3. **ドキュメント**: 既存ドキュメントの拡充

## ライセンス
MIT（[LICENSE](LICENSE) を参照）

## 参考資料
- [beads_rust](https://github.com/Dicklesworthstone/beads_rust) - 元となった Rust 実装
- [MoonBit Documentation](https://docs.moonbitlang.com/)
- [actrun (MoonBit CLI 実装例)](https://github.com/mizchi/actrun)

## 移植ノート
詳細な移植ノートについては [TECH.ja.md](TECH.ja.md) を参照してください。