/// The command handlers. Each one reports through `Result` and lets
/// `with_storage` turn the outcome into an exit code.

// ============================================================================
// Core commands
// ============================================================================

///|
fn handle_init_command(ctx : Context) -> Int32 {
  let args = ctx.args
  let mut prefix : String? = Option::None

  let mut index = 2
  while index < args.length() {
    let arg = args[index]
    if arg == "--prefix" {
      if index + 1 >= args.length() {
        return fail(ctx, missing_value_error(arg))
      }
      prefix = Option::Some(args[index + 1])
      index += 2
    } else if is_flag(arg) {
      return fail(ctx, unknown_option_error(arg))
    } else {
      index += 1
    }
  }

  match @lib.init_workspace(db_path, prefix) {
    Result::Err(e) => fail(ctx, @output.storage_error(e))
    Result::Ok(msg) => {
      match ctx.mode {
        OutputMode::Json => {
          let effective = match prefix {
            Option::Some(value) => value
            Option::None => "bd"
          }
          let entries : Map[String, Json] = Map([])
          entries.set("database", Json::string(db_path))
          entries.set("prefix", Json::string(effective))
          emit_json(Json::object(entries))
        }
        OutputMode::Text => {
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
      }
      0
    }
  }
}

///|
/// Parse `--estimate`: minutes as a non-negative integer, or the empty string
/// to clear an existing estimate.
fn estimate_from_flag(value : String) -> Result[Int32?, @output.CliError] {
  if value.trim().length() == 0 {
    return Result::Ok(Option::None)
  }
  match @lib.parse_non_negative_int(value) {
    Result::Ok(minutes) => Result::Ok(Option::Some(minutes))
    Result::Err(e) => Result::Err(invalid_value_error("INVALID_ESTIMATE", e))
  }
}

///|
/// Parse a date flag (`--due`, `--defer`, `defer --until`): a date as
/// `lib.parse_date_to_timestamp` accepts, or the empty string to clear it.
fn optional_date_from_flag(value : String) -> Result[Int32?, @output.CliError] {
  if value.trim().length() == 0 {
    return Result::Ok(Option::None)
  }
  match @lib.parse_date_to_timestamp(value) {
    Result::Ok(timestamp) => Result::Ok(Option::Some(timestamp))
    Result::Err(e) => Result::Err(invalid_value_error("INVALID_DATE", e))
  }
}

///|
/// Parse `--external-ref`: an opaque reference, or the empty string to clear it.
fn ref_from_flag(value : String) -> String? {
  if value.trim().length() == 0 {
    Option::None
  } else {
    Option::Some(value)
  }
}

///|
fn handle_create_command(ctx : Context) -> Int32 {
  if ctx.args.length() < 3 {
    return fail(
      ctx,
      required_field(
        "title is required", "bm create <title> [--priority N] [--type TYPE] [--estimate MINUTES] [--due DATE] [--defer DATE] [--external-ref REF]",
      ),
    )
  }

  let title = ctx.args[2]
  let mut priority : Int32 = 2
  let mut issue_type = @lib.IssueType::Other
  let mut estimate : Int32? = Option::None
  let mut due_date : Int32? = Option::None
  let mut defer_until : Int32? = Option::None
  let mut external_ref : String? = Option::None

  let mut index = 3
  while index < ctx.args.length() {
    let arg = ctx.args[index]
    if arg == "--priority" ||
      arg == "--type" ||
      arg == "--estimate" ||
      arg == "--due" ||
      arg == "--defer" ||
      arg == "--external-ref" {
      if index + 1 >= ctx.args.length() {
        return fail(ctx, missing_value_error(arg))
      }
      let value = ctx.args[index + 1]
      if arg == "--priority" {
        match @lib.parse_priority(value) {
          Result::Ok(parsed) => priority = parsed
          Result::Err(e) =>
            return fail(ctx, invalid_value_error("INVALID_PRIORITY", e))
        }
      } else if arg == "--type" {
        match @lib.parse_issue_type(value) {
          Result::Ok(parsed) => issue_type = parsed
          Result::Err(e) =>
            return fail(ctx, invalid_value_error("INVALID_TYPE", e))
        }
      } else if arg == "--estimate" {
        match estimate_from_flag(value) {
          Result::Ok(parsed) => estimate = parsed
          Result::Err(e) => return fail(ctx, e)
        }
      } else if arg == "--due" {
        match optional_date_from_flag(value) {
          Result::Ok(parsed) => due_date = parsed
          Result::Err(e) => return fail(ctx, e)
        }
      } else if arg == "--defer" {
        match optional_date_from_flag(value) {
          Result::Ok(parsed) => defer_until = parsed
          Result::Err(e) => return fail(ctx, e)
        }
      } else {
        external_ref = ref_from_flag(value)
      }
      index += 2
    } else if is_flag(arg) {
      return fail(ctx, unknown_option_error(arg))
    } else {
      index += 1
    }
  }

  with_storage(ctx, fn(storage) {
    let id = @lib.generate_issue_id("bd")
    let issue = @lib.make_issue(
      id,
      title,
      issue_type~,
      priority~,
      estimate~,
      due_date~,
      defer_until~,
      external_ref~,
    )
    match @lib.insert_issue(storage, issue) {
      Result::Err(e) => Result::Err(@output.storage_error(e))
      Result::Ok(_) =>
        match ctx.mode {
          OutputMode::Text => {
            println("Created: " + id)
            Result::Ok(())
          }
          OutputMode::Json => print_stored_issue(storage, id)
        }
    }
  })
}

///|
/// Write one stored issue as JSON, for the mutation commands that report the
/// issue they changed.
fn print_stored_issue(
  storage : @lib.BeadsStorage,
  id : String,
) -> Result[Unit, @output.CliError] {
  match @lib.get_issue_by_id(storage, id) {
    Result::Err(e) => Result::Err(@output.storage_error(e))
    Result::Ok(Option::Some(issue)) => {
      emit_json(@output.issue_json(issue, @output.default_fields(), None))
      Result::Ok(())
    }
    Result::Ok(Option::None) => Result::Err(issue_not_found(id))
  }
}

///|
fn handle_list_command(ctx : Context) -> Int32 {
  let options = parse_query_options(ctx.args, 2, QueryFlags::{
    excludes: true,
    fields: true,
    brief: false,
    include_deferred: false,
  })
  match options.error {
    Option::Some(error) => return fail(ctx, error)
    Option::None => ()
  }

  let fields = match resolve_fields(options.fields, @output.default_fields()) {
    Result::Err(error) => return fail(ctx, error)
    Result::Ok(fields) => fields
  }

  with_storage(ctx, fn(storage) {
    let issues = match @lib.list_issues(storage) {
      Result::Ok(issues) => issues
      Result::Err(e) => return Result::Err(@output.storage_error(e))
    }
    let kept = match
      @lib.exclude_issues_with_labels(storage, issues, options.excludes) {
      Result::Ok(kept) => kept
      Result::Err(e) => return Result::Err(@output.storage_error(e))
    }

    match ctx.mode {
      OutputMode::Json => {
        let rows = match issue_rows(storage, kept, fields) {
          Result::Ok(rows) => rows
          Result::Err(error) => return Result::Err(error)
        }
        // bm lists every match, so the page is never capped.
        emit_json(@output.page_json("issues", rows, kept.length(), 0, 0, false))
        Result::Ok(())
      }
      OutputMode::Text => {
        if kept.length() == 0 {
          println("No issues.")
        } else {
          println("Issues:")
          for issue in kept {
            println("  " + issue.id + "  " + issue.title)
          }
        }
        Result::Ok(())
      }
    }
  })
}

///|
fn handle_show_command(ctx : Context) -> Int32 {
  let options = parse_query_options(ctx.args, 2, QueryFlags::{
    excludes: false,
    fields: false,
    brief: false,
    include_deferred: false,
  })
  match options.error {
    Option::Some(error) => return fail(ctx, error)
    Option::None => ()
  }
  let ids = options.positionals
  if ids.length() == 0 {
    return fail(ctx, required_field("issue ID is required", "bm show <id>..."))
  }

  with_storage(ctx, fn(storage) {
    let issues : Array[@lib.Issue] = []
    for id in ids {
      match @lib.get_issue_by_id(storage, id) {
        Result::Err(e) => return Result::Err(@output.storage_error(e))
        Result::Ok(Option::Some(issue)) => Array::push(issues, issue)
        Result::Ok(Option::None) => return Result::Err(issue_not_found(id))
      }
    }

    match ctx.mode {
      OutputMode::Json => {
        let rows : Array[Json] = []
        for issue in issues {
          Array::push(
            rows,
            @output.issue_json(issue, @output.default_fields(), None),
          )
        }
        emit_json(Json::array(rows))
      }
      OutputMode::Text => {
        let mut first = true
        for issue in issues {
          if !first {
            println("")
          }
          first = false
          print_issue_detail(issue)
        }
      }
    }
    Result::Ok(())
  })
}

///|
fn handle_update_command(ctx : Context) -> Int32 {
  if ctx.args.length() < 3 {
    return fail(
      ctx,
      required_field(
        "issue ID is required", "bm update <id> [--title TITLE] [--priority N] [--estimate MINUTES] [--due DATE] [--defer DATE] [--external-ref REF]",
      ),
    )
  }

  let id = ctx.args[2]
  let mut new_title : String? = Option::None
  let mut new_priority : Int32? = Option::None
  let mut new_estimate : Int32? = Option::None
  let mut estimate_given = false
  let mut new_due_date : Int32? = Option::None
  let mut due_date_given = false
  let mut new_defer_until : Int32? = Option::None
  let mut defer_until_given = false
  let mut new_external_ref : String? = Option::None
  let mut external_ref_given = false

  let mut index = 3
  while index < ctx.args.length() {
    let arg = ctx.args[index]
    if arg == "--title" ||
      arg == "--priority" ||
      arg == "--estimate" ||
      arg == "--due" ||
      arg == "--defer" ||
      arg == "--external-ref" {
      if index + 1 >= ctx.args.length() {
        return fail(ctx, missing_value_error(arg))
      }
      let value = ctx.args[index + 1]
      if arg == "--title" {
        new_title = Option::Some(value)
      } else if arg == "--priority" {
        match @lib.parse_priority(value) {
          Result::Ok(parsed) => new_priority = Option::Some(parsed)
          Result::Err(e) =>
            return fail(ctx, invalid_value_error("INVALID_PRIORITY", e))
        }
      } else if arg == "--estimate" {
        match estimate_from_flag(value) {
          Result::Ok(parsed) => {
            new_estimate = parsed
            estimate_given = true
          }
          Result::Err(e) => return fail(ctx, e)
        }
      } else if arg == "--due" {
        match optional_date_from_flag(value) {
          Result::Ok(parsed) => {
            new_due_date = parsed
            due_date_given = true
          }
          Result::Err(e) => return fail(ctx, e)
        }
      } else if arg == "--defer" {
        match optional_date_from_flag(value) {
          Result::Ok(parsed) => {
            new_defer_until = parsed
            defer_until_given = true
          }
          Result::Err(e) => return fail(ctx, e)
        }
      } else {
        new_external_ref = ref_from_flag(value)
        external_ref_given = true
      }
      index += 2
    } else if is_flag(arg) {
      return fail(ctx, unknown_option_error(arg))
    } else {
      index += 1
    }
  }

  if !estimate_given &&
    !due_date_given &&
    !defer_until_given &&
    !external_ref_given &&
    new_title is None &&
    new_priority is None {
    return fail(
      ctx,
      required_field(
        "no updates specified", "bm update <id> [--title TITLE] [--priority N] [--estimate MINUTES] [--due DATE] [--defer DATE] [--external-ref REF]",
      ),
    )
  }

  with_storage(ctx, fn(storage) {
    match new_title {
      Option::Some(title) =>
        match @lib.update_issue_title(storage, id, title) {
          Result::Ok(_) =>
            match ctx.mode {
              OutputMode::Text => println("Updated title")
              OutputMode::Json => ()
            }
          Result::Err(e) => return Result::Err(@output.storage_error(e))
        }
      Option::None => ()
    }

    match new_priority {
      Option::Some(priority) =>
        match @lib.update_issue_priority(storage, id, priority) {
          Result::Ok(_) =>
            match ctx.mode {
              OutputMode::Text => println("Updated priority")
              OutputMode::Json => ()
            }
          Result::Err(e) => return Result::Err(@output.storage_error(e))
        }
      Option::None => ()
    }

    if estimate_given {
      match @lib.update_issue_estimate(storage, id, new_estimate) {
        Result::Ok(_) =>
          match ctx.mode {
            OutputMode::Text => println("Updated estimate")
            OutputMode::Json => ()
          }
        Result::Err(e) => return Result::Err(@output.storage_error(e))
      }
    }

    if due_date_given {
      match @lib.update_issue_due_date(storage, id, new_due_date) {
        Result::Ok(_) =>
          match ctx.mode {
            OutputMode::Text => println("Updated due date")
            OutputMode::Json => ()
          }
        Result::Err(e) => return Result::Err(@output.storage_error(e))
      }
    }

    if defer_until_given {
      match @lib.update_issue_defer_until(storage, id, new_defer_until) {
        Result::Ok(_) =>
          match ctx.mode {
            OutputMode::Text => println("Updated defer date")
            OutputMode::Json => ()
          }
        Result::Err(e) => return Result::Err(@output.storage_error(e))
      }
    }

    if external_ref_given {
      match @lib.update_issue_external_ref(storage, id, new_external_ref) {
        Result::Ok(_) =>
          match ctx.mode {
            OutputMode::Text => println("Updated external reference")
            OutputMode::Json => ()
          }
        Result::Err(e) => return Result::Err(@output.storage_error(e))
      }
    }

    match ctx.mode {
      OutputMode::Text => Result::Ok(())
      OutputMode::Json => print_stored_issue(storage, id)
    }
  })
}

///|
fn handle_close_command(ctx : Context) -> Int32 {
  if ctx.args.length() < 3 {
    return fail(ctx, required_field("issue ID is required", "bm close <id>"))
  }

  let id = ctx.args[2]
  with_storage(ctx, fn(storage) {
    match @lib.update_issue_status(storage, id, "closed") {
      Result::Err(e) => Result::Err(@output.storage_error(e))
      Result::Ok(_) =>
        match ctx.mode {
          OutputMode::Text => {
            println("Closed: " + id)
            Result::Ok(())
          }
          OutputMode::Json => print_stored_issue(storage, id)
        }
    }
  })
}

///|
fn handle_sync_command(ctx : Context) -> Int32 {
  fail(
    ctx,
    @output.cli_error(
      @output.ErrorKind::Internal,
      "NOT_IMPLEMENTED",
      "sync is not implemented yet",
    ),
  )
}

///|
fn handle_defer_command(ctx : Context) -> Int32 {
  if ctx.args.length() < 3 {
    return fail(
      ctx,
      required_field("issue ID is required", "bm defer <id> [--until DATE]"),
    )
  }

  let id = ctx.args[2]
  let mut until : Int32? = Option::None
  let mut until_given = false

  let mut index = 3
  while index < ctx.args.length() {
    let arg = ctx.args[index]
    if arg == "--until" {
      if index + 1 >= ctx.args.length() {
        return fail(ctx, missing_value_error(arg))
      }
      match optional_date_from_flag(ctx.args[index + 1]) {
        Result::Ok(parsed) => {
          until = parsed
          until_given = true
        }
        Result::Err(e) => return fail(ctx, e)
      }
      index += 2
    } else if is_flag(arg) {
      return fail(ctx, unknown_option_error(arg))
    } else {
      index += 1
    }
  }

  with_storage(ctx, fn(storage) {
    match @lib.defer_issue(storage, id) {
      Result::Err(e) => Result::Err(@output.storage_error(e))
      Result::Ok(_) => {
        if until_given {
          match @lib.update_issue_defer_until(storage, id, until) {
            Result::Err(e) => return Result::Err(@output.storage_error(e))
            Result::Ok(_) => ()
          }
        }
        match ctx.mode {
          OutputMode::Text => {
            println("Deferred: " + id)
            Result::Ok(())
          }
          OutputMode::Json => print_stored_issue(storage, id)
        }
      }
    }
  })
}

///|
/// Clear the `defer_until` gate and put a deferred issue back to open.
fn handle_undefer_command(ctx : Context) -> Int32 {
  if ctx.args.length() < 3 {
    return fail(ctx, required_field("issue ID is required", "bm undefer <id>"))
  }

  let id = ctx.args[2]
  with_storage(ctx, fn(storage) {
    match @lib.undefer_issue(storage, id) {
      Result::Err(e) => Result::Err(@output.storage_error(e))
      Result::Ok(_) =>
        match ctx.mode {
          OutputMode::Text => {
            println("Undeferred: " + id)
            Result::Ok(())
          }
          OutputMode::Json => print_stored_issue(storage, id)
        }
    }
  })
}
