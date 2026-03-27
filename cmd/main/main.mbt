/// Entry point for the beads CLI tool.
/// Run with `moon run cmd/main -- <args>` from the project root.
/// Build with `moon build cmd/main --target native` for native binary.

fn main() -> Unit {
  let cli_args = @sys.get_cli_args()
  
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
    "--help" | "-h" => {
      println(usage_text())
    }
    "--version" | "-v" => {
      println("beads 0.1.0 (moonbit)")
    }
    _ => {
      println("unknown command: " + command)
      println(usage_text())
    }
  }
}

fn usage_text() -> String {
  "beads - Local-first issue tracker for git repositories\n\nUsage:\n  beads [options] <command> [args...]\n\nCommands:\n  init                    Initialize beads workspace\n  create <title>          Create a new issue\n  list                    List issues\n  show <id>               Show issue details\n  update <id>             Update an issue\n  close <id>              Close an issue\n  ready                   Show actionable issues\n  defer <id>              Defer an issue\n  sync                    Sync database with JSONL export\n\nOptions:\n  -h, --help              Print this help message\n  -v, --version           Print version information\n"
}

fn handle_init_command(argv : Array[String]) -> Unit {
  let mut prefix : String? = None
  let mut force = false

  let mut index = 2
  while index < argv.length() {
    let arg = argv[index]
    if arg == "--prefix" {
      if index + 1 >= argv.length() {
        println("error: missing value for --prefix")
        println("Error"); return
      }
      prefix = Some(argv[index + 1])
      index += 2
    } else if arg == "--force" {
      force = true
      index += 1
    } else {
      index += 1
    }
  }

  let beads_dir = "./.beads"
  let db_path = beads_dir + "/beads.db"

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
    Result::Err(err) => {
      println("error: " + err)
    }
  }
}

fn handle_create_command(argv : Array[String]) -> Unit {
  if argv.length() < 3 {
    println("error: title is required")
    println("usage: beads create <title> [--priority N] [--type TYPE]")
    return
  }

  let title = argv[2]
  let mut priority = 2
  let mut type_ = "task"

  let mut i = 3
  while i < argv.length() {
    let arg = argv[i]
    if arg == "--priority" && i + 1 < argv.length() {
      priority = 1  // TODO: parse int
      i = i + 2
    } else if arg == "--type" && i + 1 < argv.length() {
      type_ = argv[i + 1]
      i = i + 2
    } else {
      i = i + 1
    }
  }

  let db_path = "./.beads/beads.db"
  match @lib.open(db_path) {
    Result::Ok(storage) => {
      let id = @lib.generate_issue_id("bd")
      let issue = @lib.make_issue(id, title)
      match @lib.insert_issue(storage, issue) {
        Result::Ok(_) => { println("Created: " + id) }
        Result::Err(e) => { println("error: " + e) }
      }
      @lib.close(storage)
    }
    Result::Err(e) => println("error: " + e)
  }
}

fn handle_list_command(argv : Array[String]) -> Unit {
  let db_path = "./.beads/beads.db"
  match @lib.open(db_path) {
    Result::Ok(storage) => {
      match @lib.list_issues(storage) {
        Result::Ok(issues) => {
          if issues.length() == 0 {
            println("No issues.")
          } else {
            println("Issues:")
            for issue in issues {
              println("  " + issue.id + "  " + issue.title)
            }
          }
        }
        Result::Err(e) => { println("error: " + e) }
      }
      @lib.close(storage)
    }
    Result::Err(e) => { println("error: " + e) }
  }
}

fn handle_show_command(argv : Array[String]) -> Unit {
  if argv.length() < 3 {
    println("error: issue ID is required")
    println("usage: beads show <id>")
    return
  }

  let id = argv[2]
  let db_path = "./.beads/beads.db"

  match @lib.open(db_path) {
    Result::Ok(storage) => {
      match @lib.get_issue_by_id(storage, id) {
        Result::Ok(Option::Some(issue)) => {
          println("Issue: " + issue.id)
          println("Title: " + issue.title)
          println("Status: " + @lib.status_to_string(issue.status))
          println("Priority: P" + issue.priority.to_string())
          println("Type: " + @lib.issue_type_to_string(issue.type_))
        }
        Result::Ok(Option::None) => { println("Issue not found: " + id) }
        Result::Err(e) => { println("error: " + e) }
      }
      @lib.close(storage)
    }
    Result::Err(e) => { println("error: " + e) }
  }
}

fn handle_update_command(argv : Array[String]) -> Unit {
  if argv.length() < 3 {
    println("error: issue ID is required")
    println("usage: beads update <id> [--title TITLE] [--priority N]")
    return
  }

  let id = argv[2]
  let db_path = "./.beads/beads.db"

  let mut new_title : Option[String] = Option::None
  let mut new_priority : Option[Int] = Option::None

  let mut i = 3
  while i < argv.length() {
    let arg = argv[i]
    if arg == "--title" && i + 1 < argv.length() {
      new_title = Option::Some(argv[i + 1])
      i = i + 2
    } else if arg == "--priority" && i + 1 < argv.length() {
      // TODO: parse int properly
      new_priority = Option::Some(1)
      i = i + 2
    } else {
      i = i + 1
    }
  }

  match @lib.open(db_path) {
    Result::Ok(storage) => {
      let mut updated = false

      match new_title {
        Option::Some(title) => {
          match @lib.update_issue_title(storage, id, title) {
            Result::Ok(_) => { updated = true; println("Updated title") }
            Result::Err(e) => { println("error: " + e) }
          }
        }
        Option::None => { () }
      }

      match new_priority {
        Option::Some(priority) => {
          match @lib.update_issue_priority(storage, id, priority) {
            Result::Ok(_) => { updated = true; println("Updated priority") }
            Result::Err(e) => { println("error: " + e) }
          }
        }
        Option::None => { () }
      }

      if !updated {
        println("No updates specified")
      }

      @lib.close(storage)
    }
    Result::Err(e) => { println("error: " + e) }
  }
}

fn handle_close_command(argv : Array[String]) -> Unit {
  if argv.length() < 3 {
    println("error: issue ID is required")
    println("usage: beads close <id>")
    return
  }

  let id = argv[2]
  let db_path = "./.beads/beads.db"

  match @lib.open(db_path) {
    Result::Ok(storage) => {
      match @lib.update_issue_status(storage, id, "closed") {
        Result::Ok(_) => { println("Closed: " + id) }
        Result::Err(e) => { println("error: " + e) }
      }
      @lib.close(storage)
    }
    Result::Err(e) => { println("error: " + e) }
  }
}

fn handle_ready_command() -> Unit {
  let db_path = "./.beads/beads.db"

  match @lib.open(db_path) {
    Result::Ok(storage) => {
      match @lib.get_ready_issues(storage) {
        Result::Ok(issues) => {
          if issues.length() == 0 {
            println("No issues ready to work on.")
          } else {
            println("Ready to work on:")
            println("")
            for issue in issues {
              let priority_str = "P" + issue.priority.to_string()
              println("  " + issue.id + "  " + priority_str + "  " + issue.title)
            }
          }
        }
        Result::Err(e) => { println("error: " + e) }
      }
      @lib.close(storage)
    }
    Result::Err(e) => { println("error: " + e) }
  }
}

fn handle_sync_command(argv : Array[String]) -> Unit {
  println("sync command: not yet implemented")
}

fn handle_defer_command(argv : Array[String]) -> Unit {
  if argv.length() < 3 {
    println("error: issue ID is required")
    println("usage: beads defer <id>")
    return
  }

  let id = argv[2]
  let db_path = "./.beads/beads.db"

  match @lib.open(db_path) {
    Result::Ok(storage) => {
      match @lib.defer_issue(storage, id) {
        Result::Ok(_) => { println("Deferred: " + id) }
        Result::Err(e) => { println("error: " + e) }
      }
      @lib.close(storage)
    }
    Result::Err(e) => { println("error: " + e) }
  }
}
