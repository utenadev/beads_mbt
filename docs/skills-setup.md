# MoonBit Skills Setup

## Overview

This project uses shared MoonBit development skills from a centralized
repository, checked out as the `.skills` git submodule (see `.gitmodules`).

## Setup

### Initialize the submodule

The submodule is already registered in `.gitmodules`. After cloning this
repository, fetch the skill files with:

```bash
git submodule update --init --recursive
```

### Update the submodule

```bash
git submodule update --remote .skills
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
| `moonbit-agent-guide/` | MoonBit language and toolchain guide (vendored from upstream) |
| `moonbit-c-binding/` | C binding guides |
| `moonbit-extract-spec-test/` | Spec extraction |

## Usage in Development

Refer to the relevant skill documentation while developing:

```bash
# SQLite integration guide
cat .skills/sqlite/SKILL.md

# Testing strategy
cat .skills/testing-strategy/SKILL.md
```

**Language note**: some skill files may contain Korean. Prefer the
English or Japanese files where available.

## For AI Agents

When assisting with MoonBit development in this project:

1. **Check skills first**: look in `.skills/` for relevant guides
2. **Follow skill guidelines**: each skill has a `SKILL.md` with best practices
3. **Update skills if needed**: if new patterns are discovered, consider
   adding them to the skills repository

## Repository Links

- **Skills Repository**: https://github.com/utenadev/moonbit-skills
- **Main Project (beads_mbt)**: https://github.com/utenadev/beads_mbt

## License

MIT License - see `.skills/LICENSE` for details.
