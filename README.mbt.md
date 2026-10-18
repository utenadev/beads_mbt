# beads_mbt - Beads in MoonBit

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
```

The build writes the executable to `_build/native/debug/build/cmd/bm/bm.exe`.
The `bm` examples below assume the binary is available as `bm` on your `PATH`;
copy or symlink it there, or invoke it by its full path.

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
```

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
| `sync` | JSONL sync | ❌ |

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
1. **JSONL sync**: Not implemented (`sync` prints a placeholder message)
2. **Error messages**: English only
3. **Search case folding**: `bm search` folds ASCII case only, so accented text has to match verbatim (beads_rust folds non-ASCII case too)

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
