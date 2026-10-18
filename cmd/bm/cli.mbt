/// Flag parsing, failure reporting, and the shared plumbing the command
/// handlers build on.

// ============================================================================
// Failures and shared plumbing
// ============================================================================

///|
/// A flag that was given without its value.
fn missing_value_error(flag : String) -> @output.CliError {
  @output.cli_error(
    @output.ErrorKind::Validation,
    "REQUIRED_FIELD",
    "missing value for " + flag,
  )
}

///|
/// An argument the command cannot run without.
fn required_field(message : String, usage : String) -> @output.CliError {
  @output.cli_error(
    @output.ErrorKind::Validation,
    "REQUIRED_FIELD",
    message,
    hint="usage: " + usage,
  )
}

///|
/// A flag value the command rejects.
fn invalid_value_error(code : String, message : String) -> @output.CliError {
  @output.cli_error(@output.ErrorKind::Validation, code, message)
}

///|
/// A flag the command does not support.
fn unknown_option_error(arg : String) -> @output.CliError {
  @output.cli_error(
    @output.ErrorKind::Validation,
    "UNKNOWN_OPTION",
    "unknown option: " + arg,
    hint="Run 'bm --help' to see the supported options.",
  )
}

///|
/// Whether an argument is a flag rather than a value. `--` is the marker that
/// ends the flags, so it is not one.
fn is_flag(arg : String) -> Bool {
  arg.has_prefix("--") && arg != "--"
}

///|
/// An issue ID no row matched.
fn issue_not_found(id : String) -> @output.CliError {
  @output.cli_error(
    @output.ErrorKind::Issue,
    "ISSUE_NOT_FOUND",
    "Issue not found: " + id,
    hint="Run 'bm list' to see available issues.",
    context=Json::object({ "searched_id": Json::string(id) }),
  )
}

///|
/// Report a failure in the active output mode and return its exit code.
/// Human mode keeps stdout pipeline clean by writing the diagnostic to stderr;
/// JSON mode writes the envelope to stdout, the only stream a robot reads.
fn fail(ctx : Context, error : @output.CliError) -> Int32 {
  match ctx.mode {
    OutputMode::Json => emit_json(@output.error_envelope(error))
    OutputMode::Text => {
      eprintln("error: " + error.message)
      match error.hint {
        Option::Some(hint) => eprintln("hint: " + hint)
        Option::None => ()
      }
    }
  }
  @output.exit_code(error.kind)
}

///|
/// Write one compact JSON document so a caller can read a stream of them.
fn emit_json(value : Json) -> Unit {
  println(value.stringify())
}

///|
/// Open the workspace database, run `action`, then close it.
/// Every handler reports through `Result`, so the exit code and the error
/// envelope are written in one place.
fn with_storage(
  ctx : Context,
  action : (@lib.BeadsStorage) -> Result[Unit, @output.CliError],
) -> Int32 {
  match @lib.open(db_path) {
    Result::Err(e) =>
      fail(
        ctx,
        @output.cli_error(
          @output.ErrorKind::Database,
          "DATABASE_UNAVAILABLE",
          e,
          hint="Run 'bm init' to create the workspace in the current directory.",
        ),
      )
    Result::Ok(storage) => {
      let result = action(storage)
      @lib.close(storage)
      match result {
        Result::Ok(_) => 0
        Result::Err(error) => fail(ctx, error)
      }
    }
  }
}

///|
/// The JSON rows of `issues` under `fields`, loading labels and dependency
/// counts only when the projection asks for them.
fn issue_rows(
  storage : @lib.BeadsStorage,
  issues : Array[@lib.Issue],
  fields : Array[String],
) -> Result[Array[Json], @output.CliError] {
  let facts = if @output.needs_issue_facts(fields) {
    match @lib.load_issue_facts(storage, issues) {
      Result::Ok(facts) => Some(facts)
      Result::Err(e) => return Result::Err(@output.storage_error(e))
    }
  } else {
    None
  }

  let rows : Array[Json] = []
  for issue in issues {
    let issue_facts = match facts {
      Some(facts) => facts.get(issue.id)
      None => None
    }
    Array::push(rows, @output.issue_json(issue, fields, issue_facts))
  }
  Result::Ok(rows)
}

///|
/// The projection to write: the `--fields` selection, or `fallback` when the
/// flag was not given.
fn resolve_fields(
  spec : String?,
  fallback : Array[String],
) -> Result[Array[String], @output.CliError] {
  match spec {
    Option::Some(spec) => @output.parse_fields(spec)
    Option::None => Result::Ok(fallback)
  }
}

///|
/// The first `limit` issues of `issues`.
fn take_issues(issues : Array[@lib.Issue], limit : Int32) -> Array[@lib.Issue] {
  let taken : Array[@lib.Issue] = []
  let mut index = 0
  while index < issues.length() && index < limit {
    Array::push(taken, issues[index])
    index += 1
  }
  taken
}

///|
/// Format an issue as an id, priority, and title row.
fn format_issue_line(issue : @lib.Issue) -> String {
  "  " + issue.id + "  P" + issue.priority.to_string() + "  " + issue.title
}

///|
/// Print one issue block: the identifying fields, then whichever free-text
/// planning sections the issue carries.
fn print_issue_detail(issue : @lib.Issue) -> Unit {
  println("Issue: " + issue.id)
  println("Title: " + issue.title)
  println("Status: " + @lib.status_to_string(issue.status))
  println("Priority: P" + issue.priority.to_string())
  println("Type: " + @lib.issue_type_to_string(issue.type_))

  match issue.description {
    Option::Some(text) =>
      if text != "" {
        println("")
        println(text)
      }
    Option::None => ()
  }
  match issue.prerequisites {
    Option::Some(text) =>
      if text != "" {
        println("")
        println("Prerequisites:")
        println(text)
      }
    Option::None => ()
  }
  match issue.acceptance_criteria {
    Option::Some(text) =>
      if text != "" {
        println("")
        println("Acceptance Criteria:")
        println(text)
      }
    Option::None => ()
  }
}

///|
/// The flags the query commands share, and which of them a given command
/// accepts. A flag that is not accepted is reported instead of being ignored.
struct QueryFlags {
  excludes : Bool
  fields : Bool
  brief : Bool
}

///|
/// What a command line was split into: the positional arguments, the flags it
/// accepts, and the first problem found.
struct QueryOptions {
  positionals : Array[String]
  excludes : Array[String]
  fields : String?
  brief : Bool
  error : @output.CliError?
}

///|
/// Read the query flags out of `args`, starting at `start`.
/// `--` ends the flags, so a query or an ID that starts with `--` can still be
/// passed after it. Anything else starting with `--` is a typo, not a value.
fn parse_query_options(
  args : Array[String],
  start : Int32,
  flags : QueryFlags,
) -> QueryOptions {
  let positionals : Array[String] = []
  let excludes : Array[String] = []
  let mut fields : String? = Option::None
  let mut brief = false
  let mut error : @output.CliError? = Option::None
  let mut only_positionals = false

  let mut index = start
  while index < args.length() {
    let arg = args[index]
    if only_positionals {
      Array::push(positionals, arg)
      index += 1
    } else if arg == "--" {
      only_positionals = true
      index += 1
    } else if arg == "--exclude-label" && flags.excludes {
      if index + 1 >= args.length() {
        error = Option::Some(missing_value_error(arg))
        index += 1
      } else {
        Array::push(excludes, args[index + 1])
        index += 2
      }
    } else if arg == "--fields" && flags.fields {
      if index + 1 >= args.length() {
        error = Option::Some(missing_value_error(arg))
        index += 1
      } else {
        fields = Option::Some(args[index + 1])
        index += 2
      }
    } else if arg == "--brief" && flags.brief {
      brief = true
      index += 1
    } else if is_flag(arg) {
      error = Option::Some(unknown_option_error(arg))
      index += 1
    } else {
      Array::push(positionals, arg)
      index += 1
    }
  }
  QueryOptions::{ positionals, excludes, fields, brief, error, }
}
