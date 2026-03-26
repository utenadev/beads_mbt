/// Command-line interface for beads.
/// Parses command-line arguments and dispatches to appropriate commands.

/// Command types supported by beads
enum Command {
  Init(InitArgs)
  Create(CreateArgs)
  List(ListArgs)
  Show(ShowArgs)
  Update(UpdateArgs)
  Close(CloseArgs)
  Ready
  Sync(SyncArgs)
  Help
  Version
}

/// Arguments for 'init' command
struct InitArgs {
  prefix : Option[String]
  force : Bool
}

/// Arguments for 'create' command
struct CreateArgs {
  title : String
  type_ : Option[String]
  priority : Option[Int]
  description : Option[String]
  assignee : Option[String]
  labels : Array[String]
}

/// Arguments for 'list' command
struct ListArgs {
  status : Option[String]
  priority : Option[String]
  assignee : Option[String]
  labels : Array[String]
  json : Bool
}

/// Arguments for 'show' command
struct ShowArgs {
  id : String
  json : Bool
}

/// Arguments for 'update' command
struct UpdateArgs {
  id : String
  title : Option[String]
  priority : Option[Int]
  status : Option[String]
  assignee : Option[String]
  description : Option[String]
}

/// Arguments for 'close' command
struct CloseArgs {
  id : String
  reason : Option[String]
}

/// Arguments for 'sync' command
struct SyncArgs {
  flush_only : Bool
  import_only : Bool
  force : Bool
}

/// Parse command-line arguments into a Command
fn parse_args(argv : Array[String]) -> Command {
  let len = argv.length()
  if len <= 1 {
    Command::Help
  } else {
    let cmd = argv[1]
    match cmd {
      "init" => parse_init(argv)
      "create" => parse_create(argv)
      "list" => parse_list(argv)
      "show" => parse_show(argv)
      "update" => parse_update(argv)
      "close" => parse_close(argv)
      "ready" => Command::Ready
      "sync" => parse_sync(argv)
      "--help" | "-h" => Command::Help
      "--version" | "-v" => Command::Version
      _ => Command::Help
    }
  }
}

/// Parse 'init' command arguments
fn parse_init(args : Array[String]) -> Command {
  let mut prefix = Option::None
  let mut force = false
  
  let mut i = 1
  let len = args.length()
  while i < len {
    let arg = args[i]
    match arg {
      "--prefix" => {
        if i + 1 < len {
          prefix = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--force" => {
        force = true
        i = i + 1
      }
      _ => {
        i = i + 1
      }
    }
  }
  
  Command::Init(InitArgs::{ prefix: prefix, force: force })
}

/// Parse 'create' command arguments
fn parse_create(args : Array[String]) -> Command {
  let mut title = ""
  let mut type_ = Option::None
  let priority = Option::None
  let mut description = Option::None
  let mut assignee = Option::None
  let labels : Array[String] = []
  
  let mut i = 1
  let len = args.length()
  while i < len {
    let arg = args[i]
    match arg {
      "--type" => {
        if i + 1 < len {
          type_ = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--priority" | "-p" => {
        if i + 1 < len {
          // TODO: Convert string to int
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--description" | "-d" => {
        if i + 1 < len {
          description = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--assignee" | "-a" => {
        if i + 1 < len {
          assignee = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--label" | "-l" => {
        if i + 1 < len {
          Array::push(labels, args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      _ => {
        if title == "" {
          title = arg
        }
        i = i + 1
      }
    }
  }
  
  Command::Create(CreateArgs::{ title: title, type_: type_, priority: priority, description: description, assignee: assignee, labels: labels })
}

/// Parse 'list' command arguments
fn parse_list(args : Array[String]) -> Command {
  let mut status = Option::None
  let mut priority = Option::None
  let mut assignee = Option::None
  let labels : Array[String] = []
  let mut json = false
  
  let mut i = 1
  let len = args.length()
  while i < len {
    let arg = args[i]
    match arg {
      "--status" | "-s" => {
        if i + 1 < len {
          status = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--priority" | "-p" => {
        if i + 1 < len {
          priority = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--assignee" | "-a" => {
        if i + 1 < len {
          assignee = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--label" | "-l" => {
        if i + 1 < len {
          Array::push(labels, args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--json" => {
        json = true
        i = i + 1
      }
      _ => {
        i = i + 1
      }
    }
  }
  
  Command::List(ListArgs::{ status: status, priority: priority, assignee: assignee, labels: labels, json: json })
}

/// Parse 'show' command arguments
fn parse_show(args : Array[String]) -> Command {
  let mut id = ""
  let mut json = false
  
  let mut i = 1
  let len = args.length()
  while i < len {
    let arg = args[i]
    match arg {
      "--json" => {
        json = true
        i = i + 1
      }
      _ => {
        if id == "" {
          id = arg
        }
        i = i + 1
      }
    }
  }
  
  Command::Show(ShowArgs::{ id: id, json: json })
}

/// Parse 'update' command arguments
fn parse_update(args : Array[String]) -> Command {
  let mut id = ""
  let mut title = Option::None
  let priority = Option::None
  let mut status = Option::None
  let mut assignee = Option::None
  let mut description = Option::None
  
  let mut i = 1
  let len = args.length()
  while i < len {
    let arg = args[i]
    match arg {
      "--title" | "-t" => {
        if i + 1 < len {
          title = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--priority" | "-p" => {
        if i + 1 < len {
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--status" => {
        if i + 1 < len {
          status = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--assignee" | "-a" => {
        if i + 1 < len {
          assignee = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      "--description" | "-d" => {
        if i + 1 < len {
          description = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      _ => {
        if id == "" {
          id = arg
        }
        i = i + 1
      }
    }
  }
  
  Command::Update(UpdateArgs::{ id: id, title: title, priority: priority, status: status, assignee: assignee, description: description })
}

/// Parse 'close' command arguments
fn parse_close(args : Array[String]) -> Command {
  let mut id = ""
  let mut reason = Option::None
  
  let mut i = 1
  let len = args.length()
  while i < len {
    let arg = args[i]
    match arg {
      "--reason" | "-r" => {
        if i + 1 < len {
          reason = Option::Some(args[i + 1])
          i = i + 2
        } else {
          i = i + 1
        }
      }
      _ => {
        if id == "" {
          id = arg
        }
        i = i + 1
      }
    }
  }
  
  Command::Close(CloseArgs::{ id: id, reason: reason })
}

/// Parse 'sync' command arguments
fn parse_sync(args : Array[String]) -> Command {
  let mut flush_only = false
  let mut import_only = false
  let mut force = false
  
  let mut i = 1
  let len = args.length()
  while i < len {
    let arg = args[i]
    match arg {
      "--flush-only" => {
        flush_only = true
        i = i + 1
      }
      "--import-only" => {
        import_only = true
        i = i + 1
      }
      "--force" => {
        force = true
        i = i + 1
      }
      _ => {
        i = i + 1
      }
    }
  }
  
  Command::Sync(SyncArgs::{ flush_only: flush_only, import_only: import_only, force: force })
}

/// Print usage information
fn print_usage() -> Unit {
  println("beads - Local-first issue tracker for git repositories")
  println("")
  println("Usage:")
  println("  beads [options] <command> [args...]")
  println("")
  println("Commands:")
  println("  init                    Initialize beads workspace")
  println("  create <title>          Create a new issue")
  println("  list                    List issues")
  println("  show <id>               Show issue details")
  println("  update <id>             Update an issue")
  println("  close <id>              Close an issue")
  println("  ready                   Show actionable issues")
  println("  sync                    Sync database with JSONL export")
  println("")
  println("Options:")
  println("  -h, --help              Print this help message")
  println("  -v, --version           Print version information")
}

/// Print version information
fn print_version() -> Unit {
  println("beads 0.1.0 (moonbit)")
}
