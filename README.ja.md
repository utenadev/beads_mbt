# beads_mbt - MoonBit 版 Beads

Rust で実装された [beads_rust](https://github.com/Dicklesworthstone/beads_rust) を MoonBit に移植したプロジェクトです。

## 概要

beads は、Git リポジトリ向けのローカルファーストなイシュートラッカーです。このプロジェクトは、Rust 実装を MoonBit 言語に移植することを目的としています。

## インストール

```bash
# リポジトリのクローン
git clone https://github.com/utenadev/beads_mbt.git
cd beads_mbt

# ネイティブバイナリのビルド
moon build cmd/bm --target native
```

ビルドされた実行ファイルは `_build/native/debug/build/cmd/bm/bm.exe` に出力されます。以下の `bm` の例は、バイナリが `PATH` 上で `bm` として利用できる前提です。`PATH` の通ったディレクトリへコピーまたはシンボリックリンクするか、フルパスで実行してください。

## 使い方

### 初期化
```bash
bm init
```

### Issue 作成
```bash
bm create "Issue のタイトル"
bm create "Issue のタイトル" --priority P1 --type bug
```
`--priority` は `0`〜`4` または `P0`〜`P4`、`--type` は
`bug` / `feature` / `task` / `documentation`（`docs` も可）/ `question` / `other`
を受け付けます。

### Issue 一覧表示
```bash
bm list
```

### Issue 詳細表示
```bash
bm show "bd-xxxxxx"
```

### Issue 更新
```bash
bm update "bd-xxxxxx" --title "新しいタイトル"
bm update "bd-xxxxxx" --priority 2
```

### Issue 完了
```bash
bm close "bd-xxxxxx"
```

### 着手可能 Issue 表示
```bash
bm ready
```

### Issue 延期
```bash
bm defer "bd-xxxxxx"
```

### ブロック中 Issue 表示
```bash
bm blocked
```

### Issue 検索
```bash
bm search "検索クエリ"
```

### 依存関係の管理
```bash
bm dep add "bd-xxxxxx" "bd-yyyyyy"
bm dep remove "bd-xxxxxx" "bd-yyyyyy"
bm dep list "bd-xxxxxx"
```
`dep add` は `blocks` 依存を作成し、`dep list` は各依存を種類付きで表示します。
`blocks` 依存の先が closed でない間はブロック扱いとなり、`parent-child`
依存では子が親のブロック状態を継承します。

### ラベルの管理
```bash
bm label add "bd-xxxxxx" "bug"
bm label remove "bd-xxxxxx" "bug"
bm label list "bd-xxxxxx"
bm label list-all
```

### コメントの管理
```bash
bm comments add "bd-xxxxxx" "コメント本文"
bm comments list "bd-xxxxxx"
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

### クイックコマンド（just）

ローカル開発向けのタスクは [just](https://github.com/casey/just) レシピにまとめています。

```bash
just                # check + test
just fmt            # フォーマット
just fmt-check      # フォーマット確認
just check          # 型チェック（警告をエラー扱い）
just test           # テスト実行
just test-update    # スナップショット更新
just run            # moon 経由で CLI を実行
just info           # 型定義ファイル生成
just info-check     # 型定義ファイルが最新か確認
just e2e            # E2E テスト実行（隔離ワークスペース）
just ci             # ローカル CI 相当（fmt-check + info-check + check + test）
just clean          # ビルド成果物の削除
just release-check  # リリース前チェック
```

### ビルドコマンド
```bash
# ビルド
moon build cmd/bm --target native

# 実行
moon run cmd/bm -- <command>

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
3. **検索の大文字小文字**: `bm search` が畳み込むのは ASCII のみで、アクセント付き文字はそのまま一致させる必要があります（beads_rust は非 ASCII も畳み込みます）

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
