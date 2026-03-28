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
    "dep" => handle_dep_command(cli_args)
    "label" => handle_label_command(cli_args)
    "blocked" => handle_blocked_command(cli_args)
    "search" => handle_search_command(cli_args)
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
  "beads - Local-first issue tracker for git repositories\n\nUsage:\n  beads [options] <command> [args...]\n\nCommands:\n  init                    Initialize beads workspace\n  create <title>          Create a new issue\n  list                    List issues\n  show <id>               Show issue details\n  update <id>             Update an issue\n  close <id>              Close an issue\n  ready                   Show actionable issues\n  blocked                 Show blocked issues\n  search <query>          Search issues\n  defer <id>              Defer an issue\n  dep <subcmd>            Manage dependencies\n  label <subcmd>          Manage labels\n  sync                    Sync database with JSONL export\n\nDependency Subcommands:\n  dep add <issue> <dep>   Add dependency\n  dep remove <issue> <dep> Remove dependency\n  dep list <issue>        List dependencies\n\nLabel Subcommands:\n  label add <issue> <label>     Add label\n  label remove <issue> <label>  Remove label\n  label list <issue>            List issue labels\n  label list-all                List all labels\n\nOptions:\n  -h, --help              Print this help message\n  -v, --version           Print version information\n"
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

fn handle_dep_command(argv : Array[String]) -> Unit {
  if argv.length() < 4 {
    println("error: subcommand required")
    println("usage: beads dep <add|remove|list> [args...]")
    return
  }

  let subcmd = argv[2]
  let db_path = "./.beads/beads.db"
  
  match @lib.open(db_path) {
    Result::Ok(storage) => {
      match subcmd {
        "add" => {
          if argv.length() < 5 {
            println("error: two issue IDs required")
            println("usage: beads dep add <issue> <depends_on>")
          } else {
            let issue = argv[3]
            let depends_on = argv[4]
            match @lib.add_dependency(storage, issue, depends_on) {
              Result::Ok(_) => { println("Added dependency: " + issue + " depends on " + depends_on) }
              Result::Err(e) => { println("error: " + e) }
            }
          }
        }
        "remove" => {
          if argv.length() < 5 {
            println("error: two issue IDs required")
            println("usage: beads dep remove <issue> <depends_on>")
          } else {
            let issue = argv[3]
            let depends_on = argv[4]
            match @lib.remove_dependency(storage, issue, depends_on) {
              Result::Ok(_) => { println("Removed dependency") }
              Result::Err(e) => { println("error: " + e) }
            }
          }
        }
        "list" => {
          if argv.length() < 4 {
            println("error: issue ID required")
            println("usage: beads dep list <issue>")
          } else {
            let issue = argv[3]
            match @lib.get_dependencies(storage, issue) {
              Result::Ok(deps) => {
                if deps.length() == 0 {
                  println("No dependencies")
                } else {
                  println("Dependencies for " + issue + ":")
                  for dep in deps {
                    println("  - " + dep)
                  }
                }
              }
              Result::Err(e) => { println("error: " + e) }
            }
          }
        }
        _ => {
          println("error: unknown subcommand: " + subcmd)
          println("usage: beads dep <add|remove|list> [args...]")
        }
      }
      @lib.close(storage)
    }
    Result::Err(e) => { println("error: " + e) }
  }
}

fn handle_label_command(argv : Array[String]) -> Unit {
  if argv.length() < 3 {
    println("error: subcommand required")
    println("usage: beads label <add|remove|list|list-all> [args...]")
    return
  }

  let subcmd = argv[2]
  let db_path = "./.beads/beads.db"
  
  match @lib.open(db_path) {
    Result::Ok(storage) => {
      match subcmd {
        "add" => {
          if argv.length() < 5 {
            println("error: issue ID and label required")
            println("usage: beads label add <issue> <label>")
          } else {
            let issue = argv[3]
            let label = argv[4]
            match @lib.add_label(storage, issue, label) {
              Result::Ok(_) => { println("Added label '" + label + "' to " + issue) }
              Result::Err(e) => { println("error: " + e) }
            }
          }
        }
        "remove" => {
          if argv.length() < 5 {
            println("error: issue ID and label required")
            println("usage: beads label remove <issue> <label>")
          } else {
            let issue = argv[3]
            let label = argv[4]
            match @lib.remove_label(storage, issue, label) {
              Result::Ok(_) => { println("Removed label '" + label + "' from " + issue) }
              Result::Err(e) => { println("error: " + e) }
            }
          }
        }
        "list" => {
          if argv.length() < 4 {
            println("error: issue ID required")
            println("usage: beads label list <issue>")
          } else {
            let issue = argv[3]
            match @lib.get_labels(storage, issue) {
              Result::Ok(labels) => {
                if labels.length() == 0 {
                  println("No labels")
                } else {
                  println("Labels for " + issue + ":")
                  for label in labels {
                    println("  - " + label)
                  }
                }
              }
              Result::Err(e) => { println("error: " + e) }
            }
          }
        }
        "list-all" => {
          match @lib.get_all_labels(storage) {
            Result::Ok(labels) => {
              if labels.length() == 0 {
                println("No labels in project")
              } else {
                println("All labels in project:")
                for label in labels {
                  println("  - " + label)
                }
              }
            }
            Result::Err(e) => { println("error: " + e) }
          }
        }
        _ => {
          println("error: unknown subcommand: " + subcmd)
          println("usage: beads label <add|remove|list|list-all> [args...]")
        }
      }
      @lib.close(storage)
    }
    Result::Err(e) => { println("error: " + e) }
  }
}

fn handle_blocked_command(argv : Array[String]) -> Unit {
  let db_path = "./.beads/beads.db"
  
  match @lib.open(db_path) {
    Result::Ok(storage) => {
      match @lib.list_issues(storage) {
        Result::Ok(issues) => {
          let mut blocked_count = 0
          println("Blocked issues:")
          println("")
          
          for issue in issues {
            match @lib.is_blocked(storage, issue.id) {
              Result::Ok(true) => {
                let priority_str = "P" + issue.priority.to_string()
                println("  " + issue.id + "  " + priority_str + "  " + issue.title)
                blocked_count = blocked_count + 1
              }
              _ => ()
            }
          }
          
          if blocked_count == 0 {
            println("  No blocked issues")
          }
        }
        Result::Err(e) => { println("error: " + e) }
      }
      @lib.close(storage)
    }
    Result::Err(e) => { println("error: " + e) }
  }
}

fn handle_search_command(argv : Array[String]) -> Unit {
  if argv.length() < 3 {
    println("error: search query required")
    println("usage: beads search <query>")
    return
  }

  let query = argv[2]
  let db_path = "./.beads/beads.db"
  
  match @lib.open(db_path) {
    Result::Ok(storage) => {
      match @lib.search_issues(storage, query) {
        Result::Ok(issues) => {
          if issues.length() == 0 {
            println("No issues found matching '" + query + "'")
          } else {
            println("Search results for '" + query + "':")
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
