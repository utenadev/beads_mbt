# beads_mbt - MoonBit 版 Beads

[English](README.md) | [日本語](README.ja.md)

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

# 任意: `bm`（Windows では `bm.exe`）として ~/.moon/bin にインストール
moon install ./cmd/bm
```

MoonBit はネイティブの実行ファイルを macOS / Linux も含めたすべてのプラットフォームで `bm.exe` という名前で出力するため、ビルド直後の成果物は `_build/native/debug/build/cmd/bm/bm.exe` です。`bm` という名前で `PATH` に置きたい場合は `moon install ./cmd/bm`（`just install` も同じ）を実行してください。実行ファイルは `~/.moon/bin` にインストールされ、macOS / Linux では `bm`、Windows では `bm.exe` になります。以下に示す `bm` の例は、バイナリが `PATH` 上で `bm` として利用できる前提です。

### 配布バイナリ

タグを付けた[リリース](https://github.com/utenadev/beads_mbt/releases)にはリリースビルドを添付しています。

| アセット | プラットフォーム |
|---------|----------------|
| `bm-linux-x86_64` | Linux x86_64 |
| `bm-macos-arm64` | macOS（Apple silicon） |
| `bm-windows-x86_64.exe` | Windows x86_64 |

自分のプラットフォーム用のファイルをダウンロードし、実行権限を付けて（macOS / Linux では `chmod +x bm`）`PATH` の通った場所に置いてください。

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
bm show "bd-xxxxxx" "bd-yyyyyy"    # 複数 ID をまとめて表示
```
Issue が値を持っている場合のみ `Prerequisites:` と `Acceptance Criteria:` の
セクションを表示します。存在しない ID が 1 つでもあるとコマンド全体が終了コード
`3` で失敗するため、途中まで表示された結果を完全な結果と誤認しません。

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
bm ready --brief
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

### ラベルによる除外
```bash
bm list --exclude-label internal
bm ready --exclude-label internal --brief
bm search "検索クエリ" --exclude-label internal
```
`--exclude-label` は繰り返し指定でき、指定したラベルのいずれかを持つ Issue を
非表示にします。`bm blocked` にはこのフィルタがありません（beads_rust と同じ）。

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

## 機械可読出力

すべてのコマンドは `--json`（別名 `--robot`）を受け付け、`--format json|text`
でも名前で指定できます。

```bash
bm list --json
bm ready --robot
bm show "bd-xxxxxx" --format json
```

JSON モードでは stdout に機械可読なドキュメントだけを出力します（成功時は結果、
失敗時はエラー envelope）。人間向けモードでは診断を stderr に出すため、パイプ
ラインはフィルタなしで stdout を読めます。

```json
{"error":{"code":"ISSUE_NOT_FOUND","message":"Issue not found: bd-x","hint":"Run 'bm list' to see available issues.","retryable":false,"context":{"searched_id":"bd-x"}}}
```

### 終了コード

| コード | 意味 |
|-------|------|
| 0 | 成功 |
| 1 | 内部エラー |
| 2 | DB エラー |
| 3 | Issue が見つからない |
| 4 | バリデーションエラー（引数不足、不正な値、未知のオプション） |
| 5 | 依存関係エラー |

beads_rust の契約のうち `6`〜`8` は、本移植で未実装の機能用に予約しています。

### コマンドごとの JSON 形式

| コマンド | 出力 |
|---------|------|
| `list` | `{"issues":[...],"total":N,"limit":0,"offset":0,"has_more":false}` |
| `blocked` | 同じ envelope。各行に `blocked_by` と `blocked_by_count` が付きます |
| `ready` | Issue オブジェクトの配列 |
| `search` | `{"issues":[...],"hidden_closed_count":0,"limit":50,"offset":0,"has_more":B}` |
| `show` | 指定した ID ごとに 1 つの Issue オブジェクトを持つ配列 |
| `create` / `update` / `close` / `defer` | 変更後の Issue オブジェクト |
| `dep list` / `label list` / `label list-all` / `comments list` | 保存されている値の配列 |
| `dep add` / `dep remove` / `label add` / `label remove` / `comments add` | 適用した変更 |
| `init` | `{"database":"./.beads/beads.db","prefix":"bd"}` |

`bm list` は一致した全件を返すため `limit`/`offset`/`has_more` は常に
`0`/`0`/`false` です。`bm search` は beads_rust と同じく 50 件で打ち切り、
打ち切られた一致があるかを報告します。タイムスタンプは Unix 秒で出力します。

### 列の選択

`bm list --json` と `bm search --json` は `--fields` で必要な列だけを出力できます。
指定順がキーの順序になり、未知の名前はエラーになります。

```bash
bm list --json --fields id,title,status,priority
bm list --json --fields id,title,labels,dependency_count,dependent_count
```

指定できる名前: `id`, `title`, `description`, `status`, `priority`,
`issue_type`, `assignee`, `owner`, `acceptance_criteria`, `prerequisites`,
`created_at`, `updated_at`, `labels`, `dependency_count`, `dependent_count`。
`labels` と依存件数は追加クエリが必要なため、指定されたときだけ読み込みます。
`bm ready --brief` は
`id,title,status,priority,issue_type,created_at,updated_at`
（`ready` のテキスト出力と同じ列）を選択します。

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
| `sync` | JSONL sync | ❌（終了コード `1`） |

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
1. **JSONL sync**: 未実装（`bm sync` は成功を報告せず終了コード `1` で失敗します）
2. **タイムスタンプ**: `current_timestamp()` が未実装のため `created_at` / `updated_at` は常に `0` です。JSON 出力でも全 Issue が `0` となり、「新しい順」は id 順にフォールバックします
3. **エラーメッセージ**: 英語のみ
4. **検索の大文字小文字**: `bm search` が畳み込むのは ASCII のみで、アクセント付き文字はそのまま一致させる必要があります（beads_rust は非 ASCII も畳み込みます）
5. **TOON 出力**: `--format` は `text` と `json` のみ受け付けます

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
