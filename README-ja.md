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

### 依存関係管理

```bash
# 依存関係追加（issueA が issueB に依存）
moon run cmd/main -- dep add "bd-abc123" "bd-def456"

# 依存関係一覧
moon run cmd/main -- dep list "bd-abc123"

# 依存関係削除
moon run cmd/main -- dep remove "bd-abc123" "bd-def456"
```

### ヘルプ表示

```bash
moon run cmd/main -- --help
```

### バージョン表示

```bash
moon run cmd/main -- --version
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
| `dep add` | 依存関係追加 | ✅ |
| `dep remove` | 依存関係削除 | ✅ |
| `dep list` | 依存関係一覧 | ✅ |
| `--help` | ヘルプ表示 | ✅ |
| `--version` | バージョン表示 | ✅ |
| `sync` | JSONL sync | ❌ |

## E2E テスト

12 件の E2E テストを実装済み。全てのコマンドをカバレッジ：

```bash
# ローカルで実行
bash scripts/e2e_test.sh

# 結果例
========================================
Passed: 12
Failed: 0
========================================
[INFO] All tests passed!
```

## CI/CD

GitHub Actions で自動テストを実行。3 プラットフォーム対応：

- ✅ Linux (ubuntu-latest)
- ✅ macOS (macos-latest)
- ✅ Windows (windows-latest)

各プッシュ時に自動的に：
1. 全プラットフォームでビルド
2. E2E テスト実行（12 件）
3. バイナリをアーティファクトとして保存

## 移植のポイント

### 1. MoonBit の構文と型システム

MoonBit は関数型言語のため、Rust とは異なるアプローチが必要でした。

**課題:**
- 構造体の初期化構文 (`Struct::{ field: value }`)
- 列挙型の定義 (`enum` vs `type`)
- 配列操作 (`Array::push` は Unit を返す)

**対応:**
```moonbit
// 構造体初期化
Issue::{
  id: id,
  title: title,
  status: Status::Open
}

// 列挙型
enum Status {
  Open
  InProgress
  Closed
  Deferred
}
```

### 2. エラー処理

Rust の `Result` と似ていますが、`try/catch/noraise` パターンが必要です。

**課題:**
- sqlite3 の API が `raise SqliteError` を返す
- `try` 式を `if` や `while` で使う際の構文

**対応:**
```moonbit
// try/catch/noraise パターン
let stmt = try storage.conn.prepare("SELECT ...") catch { 
  _ => return Result::Err("prepare failed") 
}

// if 文での使用
let result = if (try stmt.step() catch { _ => return Result::Err("step failed") }) {
  // ...
} else {
  // ...
}

// match 式での使用
match @lib.open(db_path) {
  Result::Ok(storage) => { /* ... */ }
  Result::Err(e) => { println("error: " + e) }
}
```

### 3. パッケージシステム

**課題:**
- `moon.pkg.json` でのインポート/エクスポート宣言が必要
- 同じパッケージ内のファイル間でも明示的なエクスポートが必要

**対応:**
```json
{
  "import": [
    "moonbit-community/sqlite3"
  ],
  "export": [
    "open",
    "close",
    "insert_issue",
    "get_issue_by_id",
    "list_issues"
  ]
}
```

### 4. SQLite バインディング

`moonbit-community/sqlite3` ライブラリを使用。

**課題:**
- `execute` メソッドが存在しない（`prepare` → `step` → `finalize` のパターンが必要）
- NULL 値のバインド方法（`Option::None` は使えない）

**対応:**
```moonbit
// 正しいパターン
let stmt = try storage.conn.prepare("INSERT INTO ... VALUES (?);") catch { ... }
try stmt.bind(index=1, value) catch { ... }
try stmt.step_once() catch { ... }
try stmt.finalize() catch { ... }

// NULL 値は空文字列で代用
description: if description == "" { Option::None } else { Option::Some(description) }
```

### 5. コマンドライン引数

**課題:**
- `@sys.command_line_args()` が利用できない
- `moonbitlang/x/sys` パッケージのインストールが必要

**対応:**
- 現在はハードコードされた引数配列でテスト
- 将来的には `@xsys.command_line_args()` を使用予定

```moonbit
// 現在のテスト方法
let argv : Array[String] = ["beads", "init"]

// 将来的な実装
let argv = @xsys.command_line_args()
```

### 6. 文字列操作

**課題:**
- 複数行文字列リテラルの構文 (`#|...|#`)
- 数値から文字列への変換 (`Int.to_string()`)

**対応:**
```moonbit
// 複数行文字列
fn usage_text() -> String {
  "beads - Local-first issue tracker\n\nUsage:\n  beads <command>\n"
}

// 数値変換
println("Priority: P" + issue.priority.to_string())
```

## プロジェクト構造

```
beads_mbt/
├── cmd/
│   └── main/
│       ├── main.mbt          # CLI エントリーポイント
│       ├── cli.mbt           # コマンドラインパーサー
│       └── moon.pkg          # パッケージ設定
├── lib/
│   ├── model.mbt             # データモデル
│   ├── storage.mbt           # SQLite ストレージ層
│   ├── util.mbt              # ユーティリティ
│   └── moon.pkg.json         # パッケージ設定
├── moon.mod.json             # モジュール設定
└── README-ja.md              # このファイル
```

## 開発者向けメモ

### ビルドコマンド

```bash
# ビルド
moon build cmd/main --target native

# 実行
moon run cmd/main

# テスト
moon test lib

# フォーマット
moon fmt

# 情報生成
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

### テスト方法

`cmd/main/main.mbt` の `argv` を書き換えてテスト：

```moonbit
let argv : Array[String] = ["beads", "init"]
let argv : Array[String] = ["beads", "create", "Test issue"]
let argv : Array[String] = ["beads", "list"]
// ...
```

## 既知の制限事項

1. **コマンドライン引数**: `moon run` 時は `--` 以降に引数を渡す
2. **JSONL sync**: 未実装
3. **Labels/Comments**: 未実装
4. **エラーメッセージ**: 英語のみ

## 今後の課題

1. **JSONL sync**: データベースと JSONL の同期
2. **Labels**: ラベル管理
3. **Comments**: コメント機能
4. **ブロック関係の可視化**: `ready` コマンドでブロックされた Issue を除外
5. **テストカバレッジ向上**: 単体テストの追加

## ライセンス

MIT

## 参考

- [MoonBit 公式サイト](https://www.moonbitlang.com/)
- [MoonBit ドキュメント](https://docs.moonbitlang.com/)
- [beads_rust (元プロジェクト)](https://github.com/Dicklesworthstone/beads_rust)
- [sqlite3.mbt (SQLite バインディング)](https://github.com/myfreess/sqlite3.mbt)
- [actrun (MoonBit CLI 実装例)](https://github.com/mizchi/actrun)
