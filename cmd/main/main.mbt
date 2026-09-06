/// Entry point for the beads CLI tool.
/// Run with `moon run cmd/main -- <args>` from the project root.
/// Build with `moon build cmd/main --target native` for native binary.
/// NOTE: FFI get_cli_args() broken in moonbitlang/x v0.4.41, showing usage.

fn main() -> Unit {
  println(usage_text())
}

fn usage_text() -> String {
  "beads - Local-first issue tracker for git repositories\n\nUsage:\n  beads [options] <command> [args...]\n\nCommands:\n  init                    Initialize beads workspace\n  create <title>          Create a new issue\n  list                    List issues\n  show <id>               Show issue details\n  update <id>             Update an issue\n  close <id>              Close an issue\n  ready                   Show actionable issues\n  blocked                 Show blocked issues\n  search <query>          Search issues\n  comments <subcmd>       Manage comments\n  defer <id>              Defer an issue\n  dep <subcmd>            Manage dependencies\n  label <subcmd>          Manage labels\n  sync                    Sync database with JSONL export\n"
}
