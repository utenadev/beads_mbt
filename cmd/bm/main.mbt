///|
/// Entry point for the beads CLI tool.
/// Run with `moon run cmd/bm -- <args>` from the project root.
/// Build with `moon build cmd/bm --target native` for native binary.
fn main {
  let code = run(@env.args())
  if code != 0 {
    @sys.exit(code)
  }
}

///|
/// How results are written.
enum OutputMode {
  Text
  Json
}

///|
/// A parsed invocation: the output mode, the arguments left for the command,
/// and a flag error that has to be reported before any command runs.
struct Context {
  mode : OutputMode
  args : Array[String]
  error : @output.CliError?
}

///|
/// Path to the SQLite database, relative to the project root.
let db_path : String = "./.beads/beads.db"

///|
/// Dispatch one invocation and report the process exit code.
fn run(argv : Array[String]) -> Int32 {
  if argv.length() < 2 {
    println(usage_text())
    return 0
  }

  let ctx = parse_context(argv)
  match ctx.error {
    Option::Some(error) => return fail(ctx, error)
    Option::None => ()
  }

  if ctx.args.length() < 2 {
    println(usage_text())
    return 0
  }

  match ctx.args[1] {
    "init" => handle_init_command(ctx)
    "create" => handle_create_command(ctx)
    "list" => handle_list_command(ctx)
    "show" => handle_show_command(ctx)
    "update" => handle_update_command(ctx)
    "close" => handle_close_command(ctx)
    "ready" => handle_ready_command(ctx)
    "sync" => handle_sync_command(ctx)
    "defer" => handle_defer_command(ctx)
    "dep" => handle_dep_command(ctx)
    "label" => handle_label_command(ctx)
    "blocked" => handle_blocked_command(ctx)
    "search" => handle_search_command(ctx)
    "comments" => handle_comments_command(ctx)
    "--help" | "-h" => {
      println(usage_text())
      0
    }
    "--version" | "-v" => {
      println("bm 0.2.0 (moonbit)")
      0
    }
    command =>
      fail(
        ctx,
        @output.cli_error(
          @output.ErrorKind::Validation,
          "UNKNOWN_COMMAND",
          "unknown command: " + command,
          hint="Run 'bm --help' to see the available commands.",
        ),
      )
  }
}

///|
/// Take the output flags out of `argv`, wherever they appear.
/// `--json` and its `--robot` alias select JSON; `--format` selects it by name.
/// An unusable value is remembered instead of being reported here, because the
/// report needs the output mode the caller asked for.
fn parse_context(argv : Array[String]) -> Context {
  let mut mode = OutputMode::Text
  let rest : Array[String] = []
  let mut error : @output.CliError? = Option::None
  let mut index = 0
  while index < argv.length() {
    let arg = argv[index]
    if arg == "--json" || arg == "--robot" {
      mode = OutputMode::Json
      index += 1
    } else if arg == "--format" {
      if index + 1 >= argv.length() {
        error = Option::Some(missing_value_error(arg))
        index += 1
      } else {
        let value = argv[index + 1]
        if value == "json" {
          mode = OutputMode::Json
        } else if value == "text" {
          mode = OutputMode::Text
        } else {
          error = Option::Some(
            @output.cli_error(
              @output.ErrorKind::Validation,
              "INVALID_FORMAT",
              "unsupported output format: " + value,
              hint="Supported formats: text, json.",
            ),
          )
        }
        index += 2
      }
    } else {
      Array::push(rest, arg)
      index += 1
    }
  }
  Context::{ mode, args: rest, error, }
}

///|
fn usage_text() -> String {
  "bm - Local-first issue tracker for git repositories\n\nUsage:\n  bm [options] <command> [args...]\n\nCommands:\n  init [--prefix PREFIX] Initialize beads workspace\n  create <title> [--priority N] [--type TYPE]\n                          Create a new issue\n  list [--exclude-label LABEL] [--fields FIELDS]\n                          List issues\n  show <id>...            Show issue details\n  update <id> [--title TITLE] [--priority N]\n                          Update an issue\n  close <id>              Close an issue\n  ready [--brief] [--exclude-label LABEL]\n                          Show actionable issues\n  blocked                 Show blocked issues\n  search <query> [--exclude-label LABEL] [--fields FIELDS]\n                          Search issues\n  comments <subcmd>       Manage comments\n  defer <id>              Defer an issue\n  dep <subcmd>            Manage dependencies\n  label <subcmd>          Manage labels\n  sync                    Sync database with JSONL export\n\nDependency Subcommands:\n  dep add <issue> <dep>   Add dependency\n  dep remove <issue> <dep> Remove dependency\n  dep list <issue>        List dependencies\n\nLabel Subcommands:\n  label add <issue> <label>     Add label\n  label remove <issue> <label>  Remove label\n  label list <issue>            List issue labels\n  label list-all                List all labels\n\nComments Subcommands:\n  comments add <issue> <body>   Add comment\n  comments list <issue>         List comments\n\nOptions:\n  --json, --robot         Machine-readable output\n  --format FORMAT         Output format: text, json\n  --fields FIELDS         Columns to write in JSON: " +
  @output.supported_fields_text() +
  "\n  -h, --help              Print this help message\n  -v, --version           Print version information\n"
}
