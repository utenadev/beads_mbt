# beads_mbt - Beads in MoonBit

[English](README.md) | [日本語](README.ja.md)

A MoonBit port of [beads_rust](https://github.com/Dicklesworthstone/beads_rust) - a local-first issue tracker for git repositories.

## Overview

beads is a local-first issue tracker designed for git repositories. This project ports the Rust implementation to MoonBit language.

## Installation

```bash
# Clone the repository
git clone https://github.com/utenadev/beads_mbt.git
cd beads_mbt

# Build the native binary
moon build cmd/bm --target native

# Optional: install it as `bm` (`bm.exe` on Windows) into ~/.moon/bin
moon install ./cmd/bm
```

MoonBit names the native artifact `bm.exe` on every platform, macOS and Linux
included, so the raw build output is
`_build/native/debug/build/cmd/bm/bm.exe`. To get a plain `bm` on your `PATH`,
install it with `moon install ./cmd/bm` (`just install` does the same): the
executable lands in `~/.moon/bin` as `bm` on macOS and Linux and as `bm.exe` on
Windows. The `bm` examples below assume the binary is available as `bm` on your
`PATH`.

### Prebuilt binaries

Each tagged [release](https://github.com/utenadev/beads_mbt/releases) ships the
release builds:

| Asset | Platform |
|-------|----------|
| `bm-linux-x86_64` | Linux, x86_64 |
| `bm-macos-arm64` | macOS, Apple silicon |
| `bm-windows-x86_64.exe` | Windows, x86_64 |

Download the one for your platform, make it executable (`chmod +x bm` on macOS
and Linux), and put it on your `PATH`.

## Usage

### Initialize
```bash
bm init
```

### Create Issue
```bash
bm create "Issue title"
bm create "Issue title" --priority P1 --type bug
```
`--priority` accepts `0`-`4` or `P0`-`P4`, `--type` accepts
`bug`, `feature`, `task`, `documentation` (or `docs`), `question`, `other`.

### List Issues
```bash
bm list
```

### Show Issue Details
```bash
bm show "bd-xxxxxx"
bm show "bd-xxxxxx" "bd-yyyyyy"    # several issues in one call
```
The `Prerequisites:` and `Acceptance Criteria:` sections are printed when the
issue carries them. An ID that matches nothing fails the whole command with
exit code `3`, so a partly printed list never looks complete.

### Update Issue
```bash
bm update "bd-xxxxxx" --title "New title"
bm update "bd-xxxxxx" --priority 2
```

### Close Issue
```bash
bm close "bd-xxxxxx"
```

### Show Ready Issues
```bash
bm ready
bm ready --brief
```

### Defer Issue
```bash
bm defer "bd-xxxxxx"
```

### Show Blocked Issues
```bash
bm blocked
```

### Search Issues
```bash
bm search "query"
```

### Filter Out Labelled Issues
```bash
bm list --exclude-label internal
bm ready --exclude-label internal --brief
bm search "query" --exclude-label internal
```
`--exclude-label` can be repeated, and hides an issue as soon as any listed
label is present. `bm blocked` has no such filter, matching beads_rust.

### Manage Dependencies
```bash
bm dep add "bd-xxxxxx" "bd-yyyyyy"
bm dep remove "bd-xxxxxx" "bd-yyyyyy"
bm dep list "bd-xxxxxx"
```
`dep add` creates a `blocks` dependency; `dep list` prints each dependency with
its type. An issue is blocked while a `blocks` dependency points at an issue
that is not closed, and a child inherits the blocked state of its parent
through `parent-child` dependencies.

### Manage Labels
```bash
bm label add "bd-xxxxxx" "bug"
bm label remove "bd-xxxxxx" "bug"
bm label list "bd-xxxxxx"
bm label list-all
```

### Manage Comments
```bash
bm comments add "bd-xxxxxx" "Comment body"
bm comments list "bd-xxxxxx"
```

## Machine-readable output

Every command accepts `--json`, or its alias `--robot`, and `--format
json|text` selects the mode by name:

```bash
bm list --json
bm ready --robot
bm show "bd-xxxxxx" --format json
```

In JSON mode stdout carries only the machine-readable document: the result on
success, and the error envelope on failure. Human mode keeps diagnostics on
stderr, so a pipeline can read stdout without filtering.

```json
{"error":{"code":"ISSUE_NOT_FOUND","message":"Issue not found: bd-x","hint":"Run 'bm list' to see available issues.","retryable":false,"context":{"searched_id":"bd-x"}}}
```

### Exit codes

| Code | Meaning |
|------|---------|
| 0 | Success |
| 1 | Internal error |
| 2 | Database error |
| 3 | Issue not found |
| 4 | Validation error (missing argument, bad value, unknown option) |
| 5 | Dependency error |

Codes `6`-`8` of the beads_rust contract are reserved for the parts this port
does not implement yet.

### JSON shapes

| Command | Output |
|---------|--------|
| `list` | `{"issues":[...],"total":N,"limit":0,"offset":0,"has_more":false}` |
| `blocked` | the same envelope, with `blocked_by` and `blocked_by_count` on each row |
| `ready` | an array of issue objects |
| `search` | `{"issues":[...],"hidden_closed_count":0,"limit":50,"offset":0,"has_more":B}` |
| `show` | an array holding one issue object per requested ID |
| `create`, `update`, `close`, `defer` | the issue object as stored after the change |
| `dep list`, `label list`, `label list-all`, `comments list` | an array of the stored values |
| `dep add`, `dep remove`, `label add`, `label remove`, `comments add` | the change that was applied |
| `init` | `{"database":"./.beads/beads.db","prefix":"bd"}` |

`bm list` returns every match, which is why its `limit`/`offset`/`has_more` are
always `0`/`0`/`false`; `bm search` caps results at `50` matches like
beads_rust and reports whether more were left out. Timestamps are written as
Unix seconds.

### Selecting columns

`bm list --json` and `bm search --json` accept `--fields` to write only the
columns a caller needs. The order of the names is the order of the keys, and an
unknown name fails the command:

```bash
bm list --json --fields id,title,status,priority
bm list --json --fields id,title,labels,dependency_count,dependent_count
```

Supported names: `id`, `title`, `description`, `status`, `priority`,
`issue_type`, `assignee`, `owner`, `acceptance_criteria`, `prerequisites`,
`created_at`, `updated_at`, `labels`, `dependency_count`, `dependent_count`.
`labels` and the dependency counts need extra queries, so they are only loaded
when a projection asks for them. `bm ready --brief` selects
`id,title,status,priority,issue_type,created_at,updated_at`, which is what the
`ready` text output already shows.

## Implemented Features

| Command | Description | Status |
|---------|-------------|--------|
| `init` | Initialize SQLite DB | ✅ |
| `create` | Create issue | ✅ |
| `list` | List issues | ✅ |
| `show` | Show issue details | ✅ |
| `update` | Update issue | ✅ |
| `close` | Close issue | ✅ |
| `ready` | Show actionable issues | ✅ |
| `defer` | Defer issue | ✅ |
| `blocked` | Show blocked issues | ✅ |
| `search` | Search issues | ✅ |
| `dep` | Manage dependencies (add/remove/list) | ✅ |
| `label` | Manage labels (add/remove/list/list-all) | ✅ |
| `comments` | Manage comments (add/list) | ✅ |
| `sync` | JSONL sync | ❌ (exits `1`) |

## For Developers

### Quick Commands (just)

Local development tasks are wrapped in [just](https://github.com/casey/just) recipes:

```bash
just                # check + test
just fmt            # format code
just fmt-check      # verify formatting
just check          # type check (deny warnings)
just test           # run tests
just test-update    # update snapshot tests
just run            # run the CLI via moon
just info           # regenerate interface files
just info-check     # verify interface files are up to date
just e2e            # run the E2E suite (isolated workspace)
just ci             # local CI equivalent (fmt-check + info-check + check + test)
just clean          # clean build artifacts
just release-check  # pre-release check
```

### Build Commands
```bash
# Build
moon build cmd/bm --target native

# Run
moon run cmd/bm -- <command>

# Test
moon test

# Format
moon fmt

# Generate interface
moon info
```

### Dependencies
```
// moon.mod
import {
  "moonbit-community/sqlite3@0.2.3",
  "moonbitlang/x@0.5.5",
}
```

Built and tested with MoonBit toolchain `moon` 0.1.20261012 (`moonc` v0.10.15).

## Known Limitations
1. **JSONL sync**: Not implemented; `bm sync` fails with exit code `1` instead of reporting success
2. **Close metadata**: `closed_at` and `close_reason` are never written, so `bm close` leaves `closed_at` null in JSON output
3. **Error messages**: English only
4. **Search case folding**: `bm search` folds ASCII case only, so accented text has to match verbatim (beads_rust folds non-ASCII case too)
5. **TOON output**: `--format` accepts `text` and `json` only

## Future Work
1. **JSONL sync**: Database to JSONL synchronization
2. **Tests**: Comprehensive test suite
3. **Documentation**: Enhance existing docs

## License
MIT (see [LICENSE](LICENSE))

## References
- [beads_rust](https://github.com/Dicklesworthstone/beads_rust) - Original Rust implementation
- [MoonBit Documentation](https://docs.moonbitlang.com/)
- [actrun (MoonBit CLI Example)](https://github.com/mizchi/actrun)

## Migration Notes
For detailed migration notes from beads_rust to beads_mbt, see [TECH.md](TECH.md).
