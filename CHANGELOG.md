# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- Machine-readable output: `--json` (alias `--robot`) and `--format json|text` on every command, writing results to stdout and failures as the beads_rust error envelope
- Exit codes: `0` success, `1` internal, `2` database, `3` issue not found, `4` validation; human-mode errors now go to stderr so stdout stays pipeline clean
- `--exclude-label` on `bm list`, `bm ready`, and `bm search`
- `bm ready --brief` for a short JSON projection of the ready list
- `--fields` column selection for `bm list --json` and `bm search --json`
- `bm show` accepts several IDs and prints the `Prerequisites:` and `Acceptance Criteria:` sections when an issue carries them
- `acceptance_criteria` and `prerequisites` columns on `issues`, with an automatic migration to schema version 2
- `output` package holding the JSON projections, error envelope, and exit-code mapping
- JSON output for the mutating commands, `dep list`, `label list`, `label list-all`, and `comments list`
- E2E test suite with 24 tests covering all CLI commands
- 56 unit tests covering model, storage, output, and util modules
- Japanese documentation (README.ja.md, TECH.ja.md)

### Changed
- `bm create` applies `--priority` (`0`-`4` / `P0`-`P4`) and `--type` instead of ignoring them
- `bm update --priority` parses its value instead of always setting priority 1
- `bm ready` excludes blocked issues and orders by priority, then newest, then id
- `bm search` matches id, title, and description (was title only) and orders by priority
- `bm search` reports how many matches were left out when the 50-result cap kicks in
- `bm blocked` lists blocked non-closed issues from a single computed set, and its JSON rows carry the blockers that hold each one back
- `bm blocked` blockers include those a child inherits from its parent
- `bm list` breaks ties in "most recently created first" with the id, so the order is stable between runs
- Unknown options are reported instead of being ignored (or read as an issue ID by `bm show`), and missing flag values are errors
- `bm sync` fails with exit code `1` instead of reporting success
- `cmd/bm` is split into `main.mbt`, `cli.mbt`, `commands.mbt`, `query.mbt`, and `organization.mbt`
- `dep list` prints each dependency with its type
- Fixed CLI argument parsing by replacing broken `@sys.get_cli_args()` with `@env.args()`
- Restored full CLI command handlers (init, create, list, show, update, close, ready, sync, defer, dep, label, blocked, search, comments)
- Upgraded MoonBit toolchain to `moon` 0.1.20261012 (`moonc` v0.10.15)
- Bumped dependencies: `moonbit-community/sqlite3` 0.1.3 → 0.2.3, `moonbitlang/x` 0.4.41 → 0.5.5
- Migrated to the sqlite3 0.2.3 API (`step_once()` → `step()`, `Int64` column reads)
- Declared `supported_targets = "native"` in all packages
- Renamed the CLI package `cmd/main` → `cmd/bm`; the built binary is now `bm`
- Help, version, and usage messages now display `bm` instead of `beads`

### Fixed
- `is_blocked` now ignores dependency types that never block (`related`, etc.), keeps blocking when the target is unknown, treats every non-closed blocker as open, and propagates a parent's blocked state to its children
- Added `type` to `issue_dependencies` and made it part of the primary key, with an automatic migration for existing databases
- Fixed FFI linker error with `moonbitlang/x` v0.4.41 by switching from `@sys.get_cli_args()` to `@env.args()`
- Resolved all `moon check --deny-warn` warnings (deprecated idioms, unused imports/values, dead code)
- Made `just info-check` effective by detecting regenerated `.mbti` files via `git status`
- Made storage tests idempotent so repeated `moon test` runs pass

## [0.1.1] - 2026-09-06

### Added
- Unit tests for model, storage, and util modules (20 tests)
- E2E test script (scripts/e2e_test.sh)
- Japanese documentation (README.ja.md, TECH.ja.md)

### Changed
- Updated `moonbitlang/x` from 0.4.40 to 0.4.41 (FFI issue resolved)
- Updated `moon.mod.json` version to 0.1.1

### Fixed
- Fixed FFI linker error with `moonbitlang/x` by using `@env.args()` instead of `@sys.get_cli_args()`

## [0.1.0] - 2026-03-XX

### Added
- Initial MoonBit port of beads_rust
- Core data models (Issue, Status, IssueType, Priority)
- SQLite storage layer with schema migration
- CLI commands: init, create, list, show, update, close, ready, defer, sync, dep, label, blocked, search, comments
- YAML parsing with moonbit-community/yaml
- Unit tests (20 tests) and E2E tests (12 tests)
- Japanese documentation (README-ja.md, TECH.md)
- GitHub Actions CI with multi-platform builds (Linux, macOS, Windows)