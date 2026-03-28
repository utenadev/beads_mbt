# beads_mbt Agents Guide

## Project Skills

This project uses skills in `.skills/` directory:

- **`.skills/moonbit-lang/`** - MoonBit language fundamentals
- **`.skills/sqlite/`** - SQLite integration
- **`.skills/beads_mbt/`** - Project-specific guidelines
- **`.skills/mcp-gemini-cli/`** - Gemini MCP server usage

**Language Note**: Some skill files may contain Korean (한국어). 
Please refer to English/Japanese files when possible.

## Working with Qwen

When asking Qwen to implement features:

1. **Reference skills explicitly**
   ```
   Refer to .skills/sqlite/SKILL.md for database operations
   Refer to .skills/mcp-gemini-cli/SKILL.md for Gemini search
   ```

2. **Follow MoonBit conventions**
   - Block style with `///|` separator
   - Use `Array[T]` not `List[T]`
   - Handle errors with `Result[T, E]`

3. **Build and test**
   ```bash
   moon build cmd/main --target native
   moon run cmd/main -- <args>
   ```

## Key Commands

```bash
# Initialize
moon run cmd/main -- init

# Create issue
moon run cmd/main -- create "Issue title"

# List issues
moon run cmd/main -- list

# Show issue
moon run cmd/main -- show "bd-123456"

# Search with Gemini (via MCP)
moon run cmd/main -- search "MoonBit YAML parser"
```

## Database

SQLite database stored in `.beads/beads.db`

See `.skills/sqlite/SKILL.md` for schema and operations.

## MCP Integration

mcp-gemini-cli is available for:
- Google search
- AI chat
- File analysis

See `.skills/mcp-gemini-cli/SKILL.md` for usage.
