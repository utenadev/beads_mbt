# beads_rust - 移植元のプロジェクト

## 概要

[beads_rust](https://github.com/Dicklesworthstone/beads_rust) は、Steve Yegge の [beads](https://github.com/steveyegge/beads) プロジェクトを Rust で移植したものです。

beads_mbt は、この beads_rust を MoonBit 言語に移植したプロジェクトです。

## 主な機能

beads_rust の主要機能：

- **Issue 管理**: 作成、更新、完了、延期
- **依存関係管理**: Issue 間のブロック関係
- **ラベル管理**: Issue へのタグ付け
- **コメント機能**: Issue へのコメント追加
- **JSONL sync**: Git 連携用の JSONL エクスポート/インポート
- **SQLite ストレージ**: ローカルデータベース

## 移植状況

| 機能 | beads_rust | beads_mbt | 備考 |
|------|-----------|-----------|------|
| **init** | ✅ | ✅ | ワークスペース初期化 |
| **create** | ✅ | ✅ | Issue 作成 |
| **list** | ✅ | ✅ | Issue 一覧 |
| **show** | ✅ | ✅ | Issue 詳細 |
| **update** | ✅ | ✅ | Issue 更新 |
| **close** | ✅ | ✅ | Issue 完了 |
| **ready** | ✅ | ✅ | 着手可能 Issue |
| **defer** | ✅ | ✅ | Issue 延期 |
| **dep** | ✅ | ✅ | 依存関係管理 |
| **label** | ✅ | ✅ | ラベル管理 |
| **comments** | ✅ | ✅ | コメント機能 |
| **search** | ✅ | ✅ | 全文検索 |
| **blocked** | ✅ | ✅ | ブロック Issue 一覧 |
| **sync** | ✅ | ❌ | JSONL sync（未実装） |

## 技術的な違い

| 項目 | beads_rust | beads_mbt |
|------|-----------|-----------|
| **言語** | Rust | MoonBit |
| **ビルド** | Cargo | Moon |
| **ターゲット** | ネイティブ | ネイティブ（JS/WASM も可能） |
| **エラー処理** | anyhow/thiserror | Result + try/catch |
| **CLI パーサー** | clap | 自前実装 |
| **テスト** | cargo test | moon test |

## 移植の方針

1. **コア機能の移植**: Issue CRUD、依存関係、ラベル、コメント
2. **SQLite 連携**: `moonbit-community/sqlite3` を使用
3. **CLI 構造**: beads_rust のコマンド構造を維持
4. **テスト戦略**: ユニットテスト + E2E テスト
5. **ドキュメント**: 日本語ドキュメントを充実

## 参考リソース

- [beads_rust GitHub](https://github.com/Dicklesworthstone/beads_rust)
- [beads (元プロジェクト)](https://github.com/steveyegge/beads)
- [MoonBit 公式サイト](https://www.moonbitlang.com/)
- [moonbit-community/sqlite3](https://github.com/myfreess/sqlite3.mbt)

## 移植メモ

### 主な課題と解決策

1. **コマンドライン引数**
   - Rust: `clap` ライブラリ
   - MoonBit: `@sys.get_cli_args()` または `moonbit-community/ArgParser`

2. **エラー処理**
   - Rust: `Result<T, E>` + `?` オペレーター
   - MoonBit: `Result[T, E]` + `try/catch` パターン

3. **SQLite バインディング**
   - Rust: `rusqlite` クレート
   - MoonBit: `moonbit-community/sqlite3` パッケージ

4. **テスト**
   - Rust: `#[test]` アトリビュート
   - MoonBit: `test "name" { ... }` ブロック + `inspect` スナップショット

### 学んだこと

- MoonBit のコンパイルは Rust より**10〜100 倍速い**
- スナップショットテスト（`inspect` + `moon test -u`）が非常に便利
- WASM/JS バックエンドへの展開が可能（将来の選択肢）
- エコシステムは発展途上だが、急速に成長中

---

**注意**: このディレクトリは参考資料として残しています。実際の開発は beads_mbt プロジェクトで行ってください。
