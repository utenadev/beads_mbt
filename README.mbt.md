# beads_mbt - Beads in MoonBit

A MoonBit port of [beads_rust](https://github.com/Dicklesworthstone/beads_rust) - a local-first issue tracker for git repositories.

## Overview

beads is a local-first issue tracker designed for git repositories. This project ports the Rust implementation to MoonBit language.

## Installation

```bash
# Clone the repository
git clone https://github.com/utenadev/beads_mbt.git
cd beads_mbt

# Build
moon build cmd/bm --target native
```

## Quick Commands

```bash
just           # check + test
just fmt       # format code
just fmt-check # verify formatting
just check     # type check
just test      # run tests
just test-update  # update snapshot tests
just run       # run main
just info      # generate type definition files
just e2e       # run E2E tests
just ci        # local CI equivalent
just ci-all    # lint + js/native test matrix
just release-check-all  # release check on js + native
```

## Usage

### Initialize
```bash
moon run cmd/bm -- init
```

### Create Issue
```bash
moon run cmd/bm -- create "Issue title"
```

### List Issues
```bash
moon run cmd/bm -- list
```

### Show Issue Details
```bash
moon run cmd/bm -- show "bd-xxxxxx"
```

### Update Issue
```bash
moon run cmd/bm -- update "bd-xxxxxx" --title "New title"
```

### Close Issue
```bash
moon run cmd/bm -- close "bd-xxxxxx"
```

### Show Ready Issues
```bash
moon run cmd/bm -- ready
```

### Defer Issue
```bash
moon run cmd/bm -- defer "bd-xxxxxx"
```

### Show Blocked Issues
```bash
moon run cmd/bm -- blocked
```

### Search Issues
```bash
moon run cmd/bm -- search "query"
```

### Manage Dependencies
```bash
moon run cmd/bm -- dep add "bd-xxxxxx" "bd-yyyyyy"
moon run cmd/bm -- dep remove "bd-xxxxxx" "bd-yyyyyy"
moon run cmd/bm -- dep list "bd-xxxxxx"
```

### Manage Labels
```bash
moon run cmd/bm -- label add "bd-xxxxxx" "bug"
moon run cmd/bm -- label remove "bd-xxxxxx" "bug"
moon run cmd/bm -- label list "bd-xxxxxx"
moon run cmd/bm -- label list-all
```

### Manage Comments
```bash
moon run cmd/bm -- comments add "bd-xxxxxx" "Comment body"
moon run cmd/bm -- comments list "bd-xxxxxx"
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
