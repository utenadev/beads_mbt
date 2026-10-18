///|
/// Entry point for the beads CLI tool.
/// Run with `moon run cmd/bm -- <args>` from the project root.
/// Build with `moon build cmd/bm --target native` for native binary.
fn main {
  let cli_args = @env.args()

  if cli_args.length() < 2 {
    println(usage_text())
    return
  }

  let command = cli_args[1]
  match command {
    "init" => handle_init_command(cli_args)
    "create" => handle_create_command(cli_args)
    "list" => handle_list_command(cli_args)
    "show" => handle_show_command(cli_args)
    "update" => handle_update_command(cli_args)
    "close" => handle_close_command(cli_args)
    "ready" => handle_ready_command()
    "sync" => handle_sync_command(cli_args)
    "defer" => handle_defer_command(cli_args)
    "dep" => handle_dep_command(cli_args)
    "label" => handle_label_command(cli_args)
    "blocked" => handle_blocked_command(cli_args)
    "search" => handle_search_command(cli_args)
    "comments" => handle_comments_command(cli_args)
    "--help" | "-h" => println(usage_text())
    "--version" | "-v" => println("bm 0.1.0 (moonbit)")
    _ => {
      println("unknown command: " + command)
      println(usage_text())
    }
  }
}

///|
/// Path to the SQLite database, relative to the project root.
let db_path : String = "./.beads/beads.db"

///|
fn usage_text() -> String {
  "bm - Local-first issue tracker for git repositories\n\nUsage:\n  bm [options] <command> [args...]\n\nCommands:\n  init                    Initialize beads workspace\n  create <title> [--priority N] [--type TYPE]\n                          Create a new issue\n  list                    List issues\n  show <id>               Show issue details\n  update <id> [--title TITLE] [--priority N]\n                          Update an issue\n  close <id>              Close an issue\n  ready                   Show actionable issues\n  blocked                 Show blocked issues\n  search <query>          Search issues\n  comments <subcmd>       Manage comments\n  defer <id>              Defer an issue\n  dep <subcmd>            Manage dependencies\n  label <subcmd>          Manage labels\n  sync                    Sync database with JSONL export\n\nDependency Subcommands:\n  dep add <issue> <dep>   Add dependency\n  dep remove <issue> <dep> Remove dependency\n  dep list <issue>        List dependencies\n\nLabel Subcommands:\n  label add <issue> <label>     Add label\n  label remove <issue> <label>  Remove label\n  label list <issue>            List issue labels\n  label list-all                List all labels\n\nComments Subcommands:\n  comments add <issue> <body>   Add comment\n  comments list <issue>         List comments\n\nOptions:\n  -h, --help              Print this help message\n  -v, --version           Print version information\n"
}

///|
/// Open the workspace database, run `action`, then close it.
/// An error while opening the database is printed and ignored.
fn with_storage(action : (@lib.BeadsStorage) -> Unit) -> Unit {
  match @lib.open(db_path) {
    Result::Ok(storage) => {
      action(storage)
      @lib.close(storage)
    }
    Result::Err(e) => println("error: " + e)
  }
}

///|
/// Require at least `min` entries in `argv`. When there are fewer, print an
/// error and usage message and return false.
fn require_args(
  argv : Array[String],
  min : Int32,
  error_msg : String,
  usage : String,
) -> Bool {
  if argv.length() < min {
    println("error: " + error_msg)
    println("usage: " + usage)
    false
  } else {
    true
  }
}

///|
/// Format an issue as an id, priority, and title row.
fn format_issue_line(issue : @lib.Issue) -> String {
  "  " + issue.id + "  P" + issue.priority.to_string() + "  " + issue.title
}

///|
fn handle_init_command(argv : Array[String]) -> Unit {
  let mut prefix : String? = None

  let mut index = 2
  while index < argv.length() {
    let arg = argv[index]
    if arg == "--prefix" {
      if index + 1 >= argv.length() {
        println("error: missing value for --prefix")
        println("Error")
        return
      }
      prefix = Some(argv[index + 1])
      index += 2
    } else {
      index += 1
    }
  }

  match @lib.init_workspace(db_path, prefix) {
    Result::Ok(msg) => {
      println("Initializing beads workspace")
      println("  .beads/ directory created")
      println("  SQLite database initialized")
      println("  metadata.json created")
      println("  config.yaml created")
      println("  .gitignore created")
      println("  issues.jsonl created")
      println("")
      println(msg)
    }
    Result::Err(err) => println("error: " + err)
  }
}

///|
fn handle_create_command(argv : Array[String]) -> Unit {
  if !require_args(
      argv, 3, "title is required", "bm create <title> [--priority N] [--type TYPE]",
    ) {
    return
  }

  let title = argv[2]
  let mut priority : Int32 = 2
  let mut issue_type = @lib.IssueType::Other

  let mut index = 3
  while index < argv.length() {
    let arg = argv[index]
    if arg == "--priority" && index + 1 < argv.length() {
      match @lib.parse_priority(argv[index + 1]) {
        Result::Ok(value) => priority = value
        Result::Err(e) => {
          println("error: " + e)
          return
        }
      }
      index += 2
    } else if arg == "--type" && index + 1 < argv.length() {
      match @lib.parse_issue_type(argv[index + 1]) {
        Result::Ok(value) => issue_type = value
        Result::Err(e) => {
          println("error: " + e)
          return
        }
      }
      index += 2
    } else {
      index += 1
    }
  }

  with_storage(fn(storage) {
    let id = @lib.generate_issue_id("bd")
    let issue = @lib.make_issue(id, title, issue_type~, priority~)
    match @lib.insert_issue(storage, issue) {
      Result::Ok(_) => println("Created: " + id)
      Result::Err(e) => println("error: " + e)
    }
  })
}

///|
fn handle_list_command(_argv : Array[String]) -> Unit {
  with_storage(fn(storage) {
    match @lib.list_issues(storage) {
      Result::Ok(issues) =>
        if issues.length() == 0 {
          println("No issues.")
        } else {
          println("Issues:")
          for issue in issues {
            println("  " + issue.id + "  " + issue.title)
          }
        }
      Result::Err(e) => println("error: " + e)
    }
  })
}

///|
fn handle_show_command(argv : Array[String]) -> Unit {
  if !require_args(argv, 3, "issue ID is required", "bm show <id>") {
    return
  }

  let id = argv[2]
  with_storage(fn(storage) {
    match @lib.get_issue_by_id(storage, id) {
      Result::Ok(Option::Some(issue)) => {
        println("Issue: " + issue.id)
        println("Title: " + issue.title)
        println("Status: " + @lib.status_to_string(issue.status))
        println("Priority: P" + issue.priority.to_string())
        println("Type: " + @lib.issue_type_to_string(issue.type_))
      }
      Result::Ok(Option::None) => println("Issue not found: " + id)
      Result::Err(e) => println("error: " + e)
    }
  })
}

///|
fn handle_update_command(argv : Array[String]) -> Unit {
  if !require_args(
      argv, 3, "issue ID is required", "bm update <id> [--title TITLE] [--priority N]",
    ) {
    return
  }

  let id = argv[2]
  let mut new_title : String? = Option::None
  let mut new_priority : Int32? = Option::None

  let mut i = 3
  while i < argv.length() {
    let arg = argv[i]
    if arg == "--title" && i + 1 < argv.length() {
      new_title = Option::Some(argv[i + 1])
      i = i + 2
    } else if arg == "--priority" && i + 1 < argv.length() {
      match @lib.parse_priority(argv[i + 1]) {
        Result::Ok(value) => new_priority = Option::Some(value)
        Result::Err(e) => {
          println("error: " + e)
          return
        }
      }
      i = i + 2
    } else {
      i = i + 1
    }
  }

  with_storage(fn(storage) {
    let mut updated = false

    match new_title {
      Option::Some(title) =>
        match @lib.update_issue_title(storage, id, title) {
          Result::Ok(_) => {
            updated = true
            println("Updated title")
          }
          Result::Err(e) => println("error: " + e)
        }
      Option::None => ()
    }

    match new_priority {
      Option::Some(priority) =>
        match @lib.update_issue_priority(storage, id, priority) {
          Result::Ok(_) => {
            updated = true
            println("Updated priority")
          }
          Result::Err(e) => println("error: " + e)
        }
      Option::None => ()
    }

    if !updated {
      println("No updates specified")
    }
  })
}

///|
fn handle_close_command(argv : Array[String]) -> Unit {
  if !require_args(argv, 3, "issue ID is required", "bm close <id>") {
    return
  }

  let id = argv[2]
  with_storage(fn(storage) {
    match @lib.update_issue_status(storage, id, "closed") {
      Result::Ok(_) => println("Closed: " + id)
      Result::Err(e) => println("error: " + e)
    }
  })
}

///|
fn handle_ready_command() -> Unit {
  with_storage(fn(storage) {
    match @lib.get_ready_issues(storage) {
      Result::Ok(issues) =>
        if issues.length() == 0 {
          println("No issues ready to work on.")
        } else {
          println("Ready to work on:")
          println("")
          for issue in issues {
            println(format_issue_line(issue))
          }
        }
      Result::Err(e) => println("error: " + e)
    }
  })
}

///|
fn handle_sync_command(_argv : Array[String]) -> Unit {
  println("sync command: not yet implemented")
}

///|
fn handle_defer_command(argv : Array[String]) -> Unit {
  if !require_args(argv, 3, "issue ID is required", "bm defer <id>") {
    return
  }

  let id = argv[2]
  with_storage(fn(storage) {
    match @lib.defer_issue(storage, id) {
      Result::Ok(_) => println("Deferred: " + id)
      Result::Err(e) => println("error: " + e)
    }
  })
}

///|
fn handle_dep_command(argv : Array[String]) -> Unit {
  if !require_args(
      argv, 4, "subcommand required", "bm dep <add|remove|list> [args...]",
    ) {
    return
  }

  let subcmd = argv[2]
  with_storage(fn(storage) {
    match subcmd {
      "add" =>
        if require_args(
            argv, 5, "two issue IDs required", "bm dep add <issue> <depends_on>",
          ) {
          let issue = argv[3]
          let depends_on = argv[4]
          match
            @lib.add_dependency(
              storage,
              issue,
              depends_on,
              @lib.default_dependency_type(),
            ) {
            Result::Ok(_) =>
              println(
                "Added dependency: " + issue + " depends on " + depends_on,
              )
            Result::Err(e) => println("error: " + e)
          }
        }
      "remove" =>
        if require_args(
            argv, 5, "two issue IDs required", "bm dep remove <issue> <depends_on>",
          ) {
          let issue = argv[3]
          let depends_on = argv[4]
          match @lib.remove_dependency(storage, issue, depends_on) {
            Result::Ok(_) => println("Removed dependency")
            Result::Err(e) => println("error: " + e)
          }
        }
      "list" =>
        if require_args(argv, 4, "issue ID required", "bm dep list <issue>") {
          let issue = argv[3]
          match @lib.get_dependencies(storage, issue) {
            Result::Ok(deps) =>
              if deps.length() == 0 {
                println("No dependencies")
              } else {
                println("Dependencies for " + issue + ":")
                for dep in deps {
                  println("  - " + dep.depends_on + " (" + dep.type_ + ")")
                }
              }
            Result::Err(e) => println("error: " + e)
          }
        }
      _ => {
        println("error: unknown subcommand: " + subcmd)
        println("usage: bm dep <add|remove|list> [args...]")
      }
    }
  })
}

///|
fn handle_label_command(argv : Array[String]) -> Unit {
  if !require_args(
      argv, 3, "subcommand required", "bm label <add|remove|list|list-all> [args...]",
    ) {
    return
  }

  let subcmd = argv[2]
  with_storage(fn(storage) {
    match subcmd {
      "add" =>
        if require_args(
            argv, 5, "issue ID and label required", "bm label add <issue> <label>",
          ) {
          let issue = argv[3]
          let label = argv[4]
          match @lib.add_label(storage, issue, label) {
            Result::Ok(_) => println("Added label '" + label + "' to " + issue)
            Result::Err(e) => println("error: " + e)
          }
        }
      "remove" =>
        if require_args(
            argv, 5, "issue ID and label required", "bm label remove <issue> <label>",
          ) {
          let issue = argv[3]
          let label = argv[4]
          match @lib.remove_label(storage, issue, label) {
            Result::Ok(_) =>
              println("Removed label '" + label + "' from " + issue)
            Result::Err(e) => println("error: " + e)
          }
        }
      "list" =>
        if require_args(argv, 4, "issue ID required", "bm label list <issue>") {
          let issue = argv[3]
          match @lib.get_labels(storage, issue) {
            Result::Ok(labels) =>
              if labels.length() == 0 {
                println("No labels")
              } else {
                println("Labels for " + issue + ":")
                for label in labels {
                  println("  - " + label)
                }
              }
            Result::Err(e) => println("error: " + e)
          }
        }
      "list-all" =>
        match @lib.get_all_labels(storage) {
          Result::Ok(labels) =>
            if labels.length() == 0 {
              println("No labels in project")
            } else {
              println("All labels in project:")
              for label in labels {
                println("  - " + label)
              }
            }
          Result::Err(e) => println("error: " + e)
        }
      _ => {
        println("error: unknown subcommand: " + subcmd)
        println("usage: bm label <add|remove|list|list-all> [args...]")
      }
    }
  })
}

///|
fn handle_blocked_command(_argv : Array[String]) -> Unit {
  with_storage(fn(storage) {
    match @lib.get_blocked_issues(storage) {
      Result::Ok(issues) => {
        println("Blocked issues:")
        println("")

        if issues.length() == 0 {
          println("  No blocked issues")
        } else {
          for issue in issues {
            println(format_issue_line(issue))
          }
        }
      }
      Result::Err(e) => println("error: " + e)
    }
  })
}

///|
fn handle_search_command(argv : Array[String]) -> Unit {
  if !require_args(argv, 3, "search query required", "bm search <query>") {
    return
  }

  let query = argv[2]
  with_storage(fn(storage) {
    match @lib.search_issues(storage, query) {
      Result::Ok(issues) =>
        if issues.length() == 0 {
          println("No issues found matching '" + query + "'")
        } else {
          println("Search results for '" + query + "':")
          println("")
          for issue in issues {
            println(format_issue_line(issue))
          }
        }
      Result::Err(e) => println("error: " + e)
    }
  })
}

///|
fn handle_comments_command(argv : Array[String]) -> Unit {
  if !require_args(
      argv, 4, "subcommand required", "bm comments <add|list> [args...]",
    ) {
    return
  }

  let subcmd = argv[2]
  with_storage(fn(storage) {
    match subcmd {
      "add" =>
        if require_args(
            argv, 5, "issue ID and comment body required", "bm comments add <issue> <body>",
          ) {
          let issue = argv[3]
          let body = argv[4]
          match @lib.add_comment(storage, issue, body) {
            Result::Ok(_) => println("Comment added to " + issue)
            Result::Err(e) => println("error: " + e)
          }
        }
      "list" =>
        if require_args(
            argv, 4, "issue ID required", "bm comments list <issue>",
          ) {
          let issue = argv[3]
          match @lib.get_comments(storage, issue) {
            Result::Ok(comments) =>
              if comments.length() == 0 {
                println("No comments")
              } else {
                println("Comments for " + issue + ":")
                println("")
                let mut i = 0
                while i < comments.length() {
                  println((i + 1).to_string() + ". " + comments[i])
                  i = i + 1
                }
              }
            Result::Err(e) => println("error: " + e)
          }
        }
      _ => {
        println("error: unknown subcommand: " + subcmd)
        println("usage: bm comments <add|list> [args...]")
      }
    }
  })
}
