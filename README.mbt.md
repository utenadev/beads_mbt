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

## Usage

### Initialize

```bash
moon run cmd/main  # Set argv to ["beads", "init"]
```

### Create Issue

```bash
moon run cmd/main  # Set argv to ["beads", "create", "Issue title"]
```

### List Issues

```bash
moon run cmd/main  # Set argv to ["beads", "list"]
```

### Show Issue Details

```bash
moon run cmd/main  # Set argv to ["beads", "show", "bd-xxxxxx"]
```

### Update Issue

```bash
moon run cmd/main  # Set argv to ["beads", "update", "bd-xxxxxx", "--title", "New title"]
```

### Close Issue

```bash
moon run cmd/main  # Set argv to ["beads", "close", "bd-xxxxxx"]
```

### Show Ready Issues

```bash
moon run cmd/main  # Set argv to ["beads", "ready"]
```

### Defer Issue

```bash
moon run cmd/main  # Set argv to ["beads", "defer", "bd-xxxxxx"]
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

## Migration Notes

### 1. MoonBit Syntax and Type System

MoonBit is a functional language, requiring different approaches than Rust.

**Challenges:**
- Struct initialization syntax (`Struct::{ field: value }`)
- Enum definitions (`enum` vs `type`)
- Array operations (`Array::push` returns Unit)

**Solutions:**
```moonbit
// Struct initialization
Issue::{
  id: id,
  title: title,
  status: Status::Open
}

// Enum definition
enum Status {
  Open
  InProgress
  Closed
  Deferred
}
```

### 2. Error Handling

Similar to Rust's `Result`, but requires `try/catch/noraise` pattern.

**Challenges:**
- sqlite3 API returns `raise SqliteError`
- Syntax for using `try` in `if` or `while`

**Solutions:**
```moonbit
// try/catch/noraise pattern
let stmt = try storage.conn.prepare("SELECT ...") catch { 
  _ => return Result::Err("prepare failed") 
}

// Usage in if statement
let result = if (try stmt.step() catch { _ => return Result::Err("step failed") }) {
  // ...
} else {
  // ...
}

// Usage in match expression
match @lib.open(db_path) {
  Result::Ok(storage) => { /* ... */ }
  Result::Err(e) => { println("error: " + e) }
}
```

### 3. Package System

**Challenges:**
- Import/export declarations required in `moon.pkg.json`
- Explicit exports needed even for files in the same package

**Solutions:**
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

### 4. SQLite Bindings

Using `moonbit-community/sqlite3` library.

**Challenges:**
- No `execute` method (requires `prepare` → `step` → `finalize` pattern)
- NULL value binding (`Option::None` not supported)

**Solutions:**
```moonbit
// Correct pattern
let stmt = try storage.conn.prepare("INSERT INTO ... VALUES (?);") catch { ... }
try stmt.bind(index=1, value) catch { ... }
try stmt.step_once() catch { ... }
try stmt.finalize() catch { ... }

// NULL values use empty string as placeholder
description: if description == "" { Option::None } else { Option::Some(description) }
```

### 5. Command Line Arguments

**Challenges:**
- `@sys.command_line_args()` not available
- Requires `moonbitlang/x/sys` package installation

**Solutions:**
- Currently testing with hardcoded argument arrays
- Plan to use `@xsys.command_line_args()` in the future

```moonbit
// Current testing method
let argv : Array[String] = ["beads", "init"]

// Future implementation
let argv = @xsys.command_line_args()
```

### 6. String Operations

**Challenges:**
- Multi-line string literal syntax (`#|...|#`)
- Number to string conversion (`Int.to_string()`)

**Solutions:**
```moonbit
// Multi-line strings
fn usage_text() -> String {
  "beads - Local-first issue tracker\n\nUsage:\n  beads <command>\n"
}

// Number conversion
println("Priority: P" + issue.priority.to_string())
```

## Project Structure

```
beads_mbt/
├── cmd/
│   └── main/
│       ├── main.mbt          # CLI entry point
│       ├── cli.mbt           # Command line parser
│       └── moon.pkg          # Package config
├── lib/
│   ├── model.mbt             # Data models
│   ├── storage.mbt           # SQLite storage layer
│   ├── util.mbt              # Utilities
│   └── moon.pkg.json         # Package config
├── moon.mod.json             # Module config
├── README.md                 # This file
└── README-ja.md              # Japanese README
```

## For Developers

### Build Commands

```bash
# Build
moon build cmd/main --target native

# Run
moon run cmd/main

# Test
moon test lib

# Format
moon fmt

# Generate info
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

### Testing

Edit `argv` in `cmd/main/main.mbt`:

```moonbit
let argv : Array[String] = ["beads", "init"]
let argv : Array[String] = ["beads", "create", "Test issue"]
let argv : Array[String] = ["beads", "list"]
// ...
```

## Known Limitations

1. **Command line arguments**: Currently testing with hardcoded values
2. **JSONL sync**: Not implemented
3. **Dependencies**: Not implemented
4. **Labels/Comments**: Not implemented
5. **Error messages**: English only

## Future Work

1. **Command line arguments**: Use `@xsys.command_line_args()`
2. **JSONL sync**: Database to JSONL synchronization
3. **Dependencies**: Block relationship management
4. **Tests**: Comprehensive test suite
5. **Documentation**: Enhance existing docs

## License

MIT

## References

- [MoonBit Official Site](https://www.moonbitlang.com/)
- [MoonBit Documentation](https://docs.moonbitlang.com/)
- [beads_rust (Original Project)](https://github.com/Dicklesworthstone/beads_rust)
- [sqlite3.mbt (SQLite Bindings)](https://github.com/myfreess/sqlite3.mbt)
- [actrun (MoonBit CLI Example)](https://github.com/mizchi/actrun)
