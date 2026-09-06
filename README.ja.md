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
```json
{
  "deps": {
    "moonbit-community/sqlite3": "0.1.3",
    "moonbitlang/x": "0.4.41"
  }
}
```

## 既知の問題
1. **JSONL sync**: 未実装
2. **依存関係**: 未実装
3. **ラベル/コメント**: 未実装
4. **エラーメッセージ**: 英語のみ

## 今後の作業
1. **JSONL sync**: データベースから JSONL への同期
2. **依存関係**: ブロック関係管理
3. **ラベル/コメント**: 未実装
3. **テスト**: 包括的なテストスイート
4. **ドキュメント**: 既存ドキュメントの拡充

## ライセンス
MIT

## 参考資料
- [beads_rust](https://github.com/Dicklesworthstone/beads_rust) - 元となった Rust 実装
- [MoonBit Documentation](https://docs.moonbitlang.com/)
- [actrun (MoonBit CLI 実装例)](https://github.com/mizchi/actrun)

## 移植ノート
詳細な移植ノートについては [TECH.ja.md](TECH.ja.md) を参照してください。