// ============================================================================
// Query commands
// ============================================================================

///|
fn handle_ready_command(ctx : Context) -> Int32 {
  let options = parse_query_options(ctx.args, 2, QueryFlags::{
    excludes: true,
    fields: false,
    brief: true,
  })
  match options.error {
    Option::Some(error) => return fail(ctx, error)
    Option::None => ()
  }

  // `--brief` trims the JSON projection; the text renderer already writes only
  // the identifying columns, so it is a no-op there.
  let fields = if options.brief {
    @output.brief_fields()
  } else {
    @output.default_fields()
  }

  with_storage(ctx, fn(storage) {
    let issues = match @lib.get_ready_issues(storage) {
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
        emit_json(Json::array(rows))
      }
      OutputMode::Text =>
        if kept.length() == 0 {
          println("No issues ready to work on.")
        } else {
          println("Ready to work on:")
          println("")
          for issue in kept {
            println(format_issue_line(issue))
          }
        }
    }
    Result::Ok(())
  })
}

///|
fn handle_blocked_command(ctx : Context) -> Int32 {
  let options = parse_query_options(ctx.args, 2, QueryFlags::{
    excludes: false,
    fields: false,
    brief: false,
  })
  match options.error {
    Option::Some(error) => return fail(ctx, error)
    Option::None => ()
  }

  with_storage(ctx, fn(storage) {
    let entries = match @lib.get_blocked_issues_with_blockers(storage) {
      Result::Ok(entries) => entries
      Result::Err(e) => return Result::Err(@output.storage_error(e))
    }

    match ctx.mode {
      OutputMode::Json => {
        let fields = @output.default_fields()
        let rows : Array[Json] = []
        for entry in entries {
          Array::push(
            rows,
            @output.blocked_issue_json(
              entry.issue,
              fields,
              None,
              entry.blockers,
            ),
          )
        }
        emit_json(
          @output.page_json("issues", rows, entries.length(), 0, 0, false),
        )
      }
      OutputMode::Text => {
        println("Blocked issues:")
        println("")
        if entries.length() == 0 {
          println("  No blocked issues")
        } else {
          for entry in entries {
            println(format_issue_line(entry.issue))
          }
        }
      }
    }
    Result::Ok(())
  })
}

///|
fn handle_search_command(ctx : Context) -> Int32 {
  let options = parse_query_options(ctx.args, 2, QueryFlags::{
    excludes: true,
    fields: true,
    brief: false,
  })
  match options.error {
    Option::Some(error) => return fail(ctx, error)
    Option::None => ()
  }
  if options.positionals.length() == 0 {
    return fail(
      ctx,
      required_field(
        "search query required", "bm search <query> [--exclude-label LABEL]",
      ),
    )
  }

  let query = options.positionals[0]
  let fields = match resolve_fields(options.fields, @output.default_fields()) {
    Result::Err(error) => return fail(ctx, error)
    Result::Ok(fields) => fields
  }

  with_storage(ctx, fn(storage) {
    let matches = match @lib.search_matching_issues(storage, query) {
      Result::Ok(matches) => matches
      Result::Err(e) => return Result::Err(@output.storage_error(e))
    }
    let kept = match
      @lib.exclude_issues_with_labels(storage, matches, options.excludes) {
      Result::Ok(kept) => kept
      Result::Err(e) => return Result::Err(@output.storage_error(e))
    }
    let page = take_issues(kept, @lib.search_limit)
    let has_more = kept.length() > @lib.search_limit

    match ctx.mode {
      OutputMode::Json => {
        let rows = match issue_rows(storage, page, fields) {
          Result::Ok(rows) => rows
          Result::Err(error) => return Result::Err(error)
        }
        // bm keeps every match visible, closed ones included, so nothing is
        // hidden from the result.
        emit_json(@output.search_json(rows, 0, @lib.search_limit, 0, has_more))
      }
      OutputMode::Text =>
        if page.length() == 0 {
          println("No issues found matching '" + query + "'")
        } else {
          println("Search results for '" + query + "':")
          println("")
          for issue in page {
            println(format_issue_line(issue))
          }
          if has_more {
            println("")
            println(
              "(showing " +
              @lib.search_limit.to_string() +
              " of " +
              kept.length().to_string() +
              " matches)",
            )
          }
        }
    }
    Result::Ok(())
  })
}
