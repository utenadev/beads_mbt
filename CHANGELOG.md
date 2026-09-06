# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

### Added
- E2E test suite with 12 tests covering all CLI commands
- 20 unit tests covering model, storage, and util modules
- Japanese documentation (README.ja.md, TECH.ja.md)

### Changed
- Fixed CLI argument parsing by replacing broken `@sys.get_cli_args()` with `@env.args()`
- Restored full CLI command handlers (init, create, list, show, update, close, ready, sync, defer, dep, label, blocked, search, comments)

### Fixed
- Fixed FFI linker error with `moonbitlang/x` v0.4.41 by switching from `@sys.get_cli_args()` to `@env.args()`

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