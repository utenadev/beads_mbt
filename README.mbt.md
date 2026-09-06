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
moon build cmd/main --target native
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
moon run cmd/main -- init
```

### Create Issue
```bash
moon run cmd/main -- create "Issue title"
```

### List Issues
```bash
moon run cmd/main -- list
```

### Show Issue Details
```bash
moon run cmd/main -- show "bd-xxxxxx"
```

### Update Issue
```bash
moon run cmd/main -- update "bd-xxxxxx" --title "New title"
```

### Close Issue
```bash
moon run cmd/main -- close "bd-xxxxxx"
```

### Show Ready Issues
```bash
moon run cmd/main -- ready
```

### Defer Issue
```bash
moon run cmd/main -- defer "bd-xxxxxx"
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
| `sync` | JSONL sync | ❌ |

## For Developers

### Build Commands
```bash
# Build
moon build cmd/main --target native

# Run
moon run cmd/main -- <command>

# Test
moon test

# Format
moon fmt

# Generate interface
moon info
```

### Dependencies
```json
{
  "deps": {
    "moonbit-community/sqlite3": "0.1.3",
    "moonbitlang/x": "0.4.41"
  }
}
```

## Known Limitations
1. **JSONL sync**: Not implemented
2. **Dependencies**: Not implemented
3. **Labels/Comments**: Not implemented
4. **Error messages**: English only

## Future Work
1. **JSONL sync**: Database to JSONL synchronization
2. **Dependencies**: Block relationship management
3. **Labels/Comments**: Not implemented
4. **Tests**: Comprehensive test suite
5. **Documentation**: Enhance existing docs

## License
MIT

## References
- [beads_rust](https://github.com/Dicklesworthstone/beads_rust) - Original Rust implementation
- [MoonBit Documentation](https://docs.moonbitlang.com/)
- [actrun (MoonBit CLI Example)](https://github.com/mizchi/actrun)

## Migration Notes
For detailed migration notes from beads_rust to beads_mbt, see [TECH.md](TECH.md).# CI trigger
# CI fix
# CI fix
# CI trigger
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
# CI fix
