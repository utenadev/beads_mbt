# MoonBit Skills Setup Instructions

## Overview

This project uses shared MoonBit development skills from a centralized repository.

## Setup

### 1. Add Skills Submodule

```bash
cd /path/to/task_mbt
git submodule add https://github.com/utenadev/moonbit-skills.git .skills
git commit -m "Add skills as submodule"
```

### 2. Verify Setup

```bash
ls -la .skills/
# Should show:
# - beads_mbt/
# - sqlite/
# - rust-porting/
# - js-backend/
# - wasm-cli/
# - testing-strategy/
# - mcp-gemini-cli/
# - moonbit-c-binding/
# - moonbit-extract-spec-test/
```

### 3. Update Submodule (when skills are updated)

```bash
cd .skills
git pull origin main
cd ..
git add .skills
git commit -m "Update skills submodule"
```

## Available Skills

| Skill | Description |
|-------|-------------|
| `beads_mbt/` | Project-specific guidelines for beads_mbt |
| `sqlite/` | SQLite integration guide |
| `rust-porting/` | Rust CLI porting guide |
| `js-backend/` | JS backend development |
| `wasm-cli/` | WASM CLI development |
| `testing-strategy/` | Testing strategy (UT, E2E, QuickCheck) |
| `mcp-gemini-cli/` | Gemini MCP integration |
| `moonbit-c-binding/` | C binding guides |
| `moonbit-extract-spec-test/` | Spec extraction |

## Usage in Development

When developing MoonBit code, refer to the relevant skill documentation:

```bash
# Example: Check SQLite integration guide
cat .skills/sqlite/SKILL.md

# Example: Check testing strategy
cat .skills/testing-strategy/SKILL.md
```

## For AI Agents

When assisting with MoonBit development in this project:

1. **Check skills first**: Look in `.skills/` for relevant guides
2. **Follow skill guidelines**: Each skill has `SKILL.md` with best practices
3. **Update skills if needed**: If new patterns are discovered, consider adding to skills repo

## Repository Links

- **Skills Repository**: https://github.com/utenadev/moonbit-skills
- **Main Project (beads_mbt)**: https://github.com/utenadev/beads_mbt

## License

MIT License - See `.skills/LICENSE` for details.
