# Migration Notes: beads_rust → beads_mbt

[English](TECH.md) | [日本語](TECH.ja.md)

This document records the technical challenges and solutions encountered during the MoonBit port of [beads_rust](https://github.com/Dicklesworthstone/beads_rust).

## 1. MoonBit Syntax and Type System

MoonBit is a functional language, requiring different approaches than Rust.

### Challenges:
- Struct initialization syntax (`Struct::{ field: value }`)
- Enum definitions (`enum` vs `type`)
- Array operations (`Array::push` returns Unit)

### Solutions:
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

## 2. Error Handling

Similar to Rust's `Result`, but requires `try/catch/noraise` pattern.

### Challenges:
- sqlite3 API returns `raise SqliteError`
- Syntax for using `try` in `if` or `while`

### Solutions:
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

## 3. Package System

### Challenges:
- Import/export declarations required in `moon.pkg`
- Explicit exports needed even for files in the same package

### Solutions:
```
import {
  "moonbit-community/sqlite3",
}

options(
  "export": [
    "open",
    "close",
    "insert_issue",
    "get_issue_by_id",
    "list_issues",
  ],
)
```

> Note: newer MoonBit toolchains replaced the old `moon.pkg.json` (JSON)
> with the `moon.pkg` block syntax shown above.

## 4. SQLite Bindings

Using `moonbit-community/sqlite3` library.

### Challenges:
- No `execute` method (requires `prepare` → `step` → `finalize` pattern)
- NULL value binding (`Option::None` not supported)

### Solutions:
```moonbit
// Correct pattern
let stmt = try storage.conn.prepare("INSERT INTO ... VALUES (?);") catch { ... }
try stmt.bind(index=1, value) catch { ... }
ignore(stmt.step() catch { ... })  // step() returns Bool (row available)
try stmt.finalize() catch { ... }

// NULL values use empty string as placeholder
description: if description == "" { Option::None } else { Option::Some(description) }
```

## 5. Command Line Arguments

### Challenges:
- `@sys.get_cli_args()` FFI issue on native targets (seen with older `moonbitlang/x`)
- MoonBit doesn't support `fn main(argv)` syntax

### Solutions:
- Use `@env.args()` from `moonbitlang/core/env` instead
- Added `moonbitlang/core/env` to package imports

```moonbit
// Current working implementation
fn main() -> Unit {
  let argv = @env.args()
  // ... rest of command dispatch
}
```

## 6. String Operations

### Challenges:
- Multi-line string literal syntax (`#|...|#`)
- Number to string conversion (`Int.to_string()`)

### Solutions:
```moonbit
// Multi-line strings
fn usage_text() -> String {
  "bm - Local-first issue tracker\n\nUsage:\n  bm <command>\n"
}

// Number conversion
println("Priority: P" + issue.priority.to_string())
```

## 7. CLI Argument Parsing

Using MoonBit's built-in `@env.args()`:

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
    // ... other commands
  }
}
```

## 7. Package Configuration

### Main Package (`cmd/bm/moon.pkg`)
```
import {
  "utenadev/beads_mbt/lib",
  "moonbitlang/core/env",
}

pkgtype(kind: "executable")

supported_targets = "native"
```

### Library Package (`lib/moon.pkg`)
```
import {
  "moonbit-community/sqlite3",
  "moonbitlang/x/fs",
}

supported_targets = "native"

options(
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
    "issue_type_to_string", "string_to_issue_type",
  ],
)
```

## 8. Build and Test Commands

```bash
# Build
moon build cmd/bm --target native

# Run
moon run cmd/bm -- init
moon run cmd/bm -- create "Issue title"
moon run cmd/bm -- list

# Test
moon test

# Format
moon fmt

# Generate interface
moon info
```

## 9. Known Limitations

1. **JSONL sync**: Not implemented (`sync` prints a placeholder message)
2. **Error messages**: English only
3. **Windows testing**: Limited CI coverage

## 10. Future Work

1. **JSONL sync**: Database to JSONL synchronization
2. **Tests**: Comprehensive test suite
3. **Documentation**: Enhance existing docs