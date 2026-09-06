# 移植ノート: beads_rust → beads_mbt

このドキュメントは、[beads_rust](https://github.com/Dicklesworthstone/beads_rust) の MoonBit への移植時に遭遇した技術的課題と解決策を記録しています。

## 1. MoonBit の構文と型システム

MoonBit は関数型言語のため、Rust とは異なるアプローチが必要でした。

### 課題:
- 構造体の初期化構文 (`Struct::{ field: value }`)
- 列挙型の定義 (`enum` vs `type`)
- 配列操作 (`Array::push` は Unit を返す)

### 対応:
```moonbit
// 構造体の初期化
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

## 2. エラー処理

Rust の `Result` と似ていますが、`try/catch/noraise` パターンが必要です。

### 課題:
- sqlite3 の API が `raise SqliteError` を返す
- `try` 式を `if` や `while` で使う際の構文

### 対応:
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

## 3. パッケージシステム

### 課題:
- `moon.pkg.json` でのインポート/エクスポート宣言が必要
- 同じパッケージ内のファイル間でも明示的なエクスポートが必要

### 対応:
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

## 4. SQLite バインディング

`moonbit-community/sqlite3` ライブラリを使用。

### 課題:
- `execute` メソッドが存在しない（`prepare` → `step` → `finalize` のパターンが必要）
- NULL 値のバインド方法（`Option::None` は使えない）

### 対応:
```moonbit
// 正しいパターン
let stmt = try storage.conn.prepare("INSERT INTO ... VALUES (?);") catch { ... }
try stmt.bind(index=1, value) catch { ... }
try stmt.step_once() catch { ... }
try stmt.finalize() catch { ... }

// NULL 値は空文字列で代用
description: if description == "" { Option::None } else { Option::Some(description) }
```

## 5. コマンドライン引数

### 課題:
- `@sys.get_cli_args()` が moonbitlang/x v0.4.41 で FFI エラー
- MoonBit は `fn main(argv)` 構文をサポートしていない

### 対応:
- `moonbitlang/core/env` の `@env.args()` を使用
- パッケージインポートに `moonbitlang/core/env` を追加

```moonbit
// 現在の動作する実装
fn main() -> Unit {
  let argv = @env.args()
  // ... コマンドディスパッチの残り
}
```

## 6. 文字列操作

### 課題:
- 複数行文字列リテラルの構文 (`#|...|#`)
- 数値から文字列への変換 (`Int.to_string()`)

### 対応:
```moonbit
// 複数行文字列
fn usage_text() -> String {
  "beads - Local-first issue tracker\n\nUsage:\n  beads <command>\n"
}

// 数値変換
println("Priority: P" + issue.priority.to_string())
```

## 7. CLI 引数パース

MoonBit 標準の `@env.args()` を使用:

```moonbit
fn main() -> Unit {
  let argv = @env.args()
  
  if argv.length() < 2 {
    println(usage_text())
    return
  }
  
  let command = argv[1]
  match command {
    "init" => handle_init_command(argv)
    "create" => handle_create_command(argv)
    // ... 他のコマンド
  }
}
```

## 7. パッケージ設定

### メインパッケージ (`cmd/main/moon.pkg`)
```json
{
  "import": [
    "utenadev/beads_mbt/lib" @lib,
    "moonbitlang/core/env" @env,
    "moonbitlang/x/sys" @sys
  ],
  "options": { "is-main": true }
}
```

### ライブラリパッケージ (`lib/moon.pkg.json`)
```json
{
  "import": [
    "moonbit-community/sqlite3",
    "moonbitlang/x/fs"
  ],
  "export": [
    "open", "close", "set_config", "get_config",
    "insert_issue", "get_issue_by_id", "list_issues",
    "get_ready_issues", "update_issue_status",
    "update_issue_title", "update_issue_priority",
    "defer_issue", "add_dependency", "remove_dependency",
    "get_dependencies", "get_blocked_by", "is_blocked",
    "add_label", "remove_label", "get_labels", "get_all_labels",
    "search_issues", "add_comment", "get_comments",
    "init_workspace", "make_issue", "generate_issue_id",
    "status_to_string", "string_to_status",
    "issue_type_to_string", "string_to_issue_type"
  ]
}
```

## 8. ビルドとテストコマンド

```bash
# ビルド
moon build cmd/main --target native

# 実行
moon run cmd/main -- init
moon run cmd/main -- create "Issue title"
moon run cmd/main -- list

# テスト
moon test

# フォーマット
moon fmt

# インターフェース生成
moon info
```

## 9. 既知の制限

1. **JSONL sync**: 未実装
2. **依存関係**: ブロック関係管理（部分的に実装済み）
3. **ラベル/コメント**: 未実装
4. **エラーメッセージ**: 英語のみ
5. **Windows テスト**: CI カバレッジが限定的

## 10. 今後の作業

1. **JSONL sync**: データベースから JSONL への同期
2. **依存関係**: 完全なブロック関係管理
3. **ラベル/コメント**: 完全実装
4. **テスト**: 包括的なテストスイート
5. **ドキュメント**: 既存ドキュメントの拡充