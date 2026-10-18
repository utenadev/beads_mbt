// ============================================================================
// Organization commands
// ============================================================================

///|
fn handle_dep_command(ctx : Context) -> Int32 {
  if ctx.args.length() < 3 {
    return fail(
      ctx,
      required_field(
        "subcommand required", "bm dep <add|remove|list> [args...]",
      ),
    )
  }

  let subcmd = ctx.args[2]
  match subcmd {
    "add" => {
      if ctx.args.length() < 5 {
        return fail(
          ctx,
          required_field(
            "two issue IDs required", "bm dep add <issue> <depends_on>",
          ),
        )
      }
      let issue = ctx.args[3]
      let depends_on = ctx.args[4]
      let dep_type = @lib.default_dependency_type()
      with_storage(ctx, fn(storage) {
        match @lib.add_dependency(storage, issue, depends_on, dep_type) {
          Result::Err(e) => Result::Err(@output.storage_error(e))
          Result::Ok(_) => {
            match ctx.mode {
              OutputMode::Text =>
                println(
                  "Added dependency: " + issue + " depends on " + depends_on,
                )
              OutputMode::Json => {
                let entries : Map[String, Json] = Map([])
                entries.set("issue_id", Json::string(issue))
                entries.set("depends_on", Json::string(depends_on))
                entries.set("type", Json::string(dep_type))
                emit_json(Json::object(entries))
              }
            }
            Result::Ok(())
          }
        }
      })
    }
    "remove" => {
      if ctx.args.length() < 5 {
        return fail(
          ctx,
          required_field(
            "two issue IDs required", "bm dep remove <issue> <depends_on>",
          ),
        )
      }
      let issue = ctx.args[3]
      let depends_on = ctx.args[4]
      with_storage(ctx, fn(storage) {
        match @lib.remove_dependency(storage, issue, depends_on) {
          Result::Err(e) => Result::Err(@output.storage_error(e))
          Result::Ok(_) => {
            match ctx.mode {
              OutputMode::Text => println("Removed dependency")
              OutputMode::Json => {
                let entries : Map[String, Json] = Map([])
                entries.set("issue_id", Json::string(issue))
                entries.set("depends_on", Json::string(depends_on))
                entries.set("removed", Json::boolean(true))
                emit_json(Json::object(entries))
              }
            }
            Result::Ok(())
          }
        }
      })
    }
    "list" => {
      if ctx.args.length() < 4 {
        return fail(
          ctx,
          required_field("issue ID required", "bm dep list <issue>"),
        )
      }
      let issue = ctx.args[3]
      with_storage(ctx, fn(storage) {
        match @lib.get_dependencies(storage, issue) {
          Result::Err(e) => Result::Err(@output.storage_error(e))
          Result::Ok(deps) => {
            match ctx.mode {
              OutputMode::Text =>
                if deps.length() == 0 {
                  println("No dependencies")
                } else {
                  println("Dependencies for " + issue + ":")
                  for dep in deps {
                    println("  - " + dep.depends_on + " (" + dep.type_ + ")")
                  }
                }
              OutputMode::Json => {
                let rows : Array[Json] = []
                for dep in deps {
                  let entries : Map[String, Json] = Map([])
                  entries.set("issue_id", Json::string(dep.issue_id))
                  entries.set("depends_on", Json::string(dep.depends_on))
                  entries.set("type", Json::string(dep.type_))
                  Array::push(rows, Json::object(entries))
                }
                emit_json(Json::array(rows))
              }
            }
            Result::Ok(())
          }
        }
      })
    }
    _ =>
      fail(
        ctx,
        @output.cli_error(
          @output.ErrorKind::Validation,
          "UNKNOWN_COMMAND",
          "unknown subcommand: " + subcmd,
          hint="usage: bm dep <add|remove|list> [args...]",
        ),
      )
  }
}

///|
fn handle_label_command(ctx : Context) -> Int32 {
  if ctx.args.length() < 3 {
    return fail(
      ctx,
      required_field(
        "subcommand required", "bm label <add|remove|list|list-all> [args...]",
      ),
    )
  }

  let subcmd = ctx.args[2]
  match subcmd {
    "add" => {
      if ctx.args.length() < 5 {
        return fail(
          ctx,
          required_field(
            "issue ID and label required", "bm label add <issue> <label>",
          ),
        )
      }
      change_label(ctx, ctx.args[3], ctx.args[4], true)
    }
    "remove" => {
      if ctx.args.length() < 5 {
        return fail(
          ctx,
          required_field(
            "issue ID and label required", "bm label remove <issue> <label>",
          ),
        )
      }
      change_label(ctx, ctx.args[3], ctx.args[4], false)
    }
    "list" => {
      if ctx.args.length() < 4 {
        return fail(
          ctx,
          required_field("issue ID required", "bm label list <issue>"),
        )
      }
      let issue = ctx.args[3]
      with_storage(ctx, fn(storage) {
        match @lib.get_labels(storage, issue) {
          Result::Err(e) => Result::Err(@output.storage_error(e))
          Result::Ok(labels) => {
            match ctx.mode {
              OutputMode::Text =>
                if labels.length() == 0 {
                  println("No labels")
                } else {
                  println("Labels for " + issue + ":")
                  for label in labels {
                    println("  - " + label)
                  }
                }
              OutputMode::Json => emit_json(strings_json(labels))
            }
            Result::Ok(())
          }
        }
      })
    }
    "list-all" =>
      with_storage(ctx, fn(storage) {
        match @lib.get_all_labels(storage) {
          Result::Err(e) => Result::Err(@output.storage_error(e))
          Result::Ok(labels) => {
            match ctx.mode {
              OutputMode::Text =>
                if labels.length() == 0 {
                  println("No labels in project")
                } else {
                  println("All labels in project:")
                  for label in labels {
                    println("  - " + label)
                  }
                }
              OutputMode::Json => emit_json(strings_json(labels))
            }
            Result::Ok(())
          }
        }
      })
    _ =>
      fail(
        ctx,
        @output.cli_error(
          @output.ErrorKind::Validation,
          "UNKNOWN_COMMAND",
          "unknown subcommand: " + subcmd,
          hint="usage: bm label <add|remove|list|list-all> [args...]",
        ),
      )
  }
}

///|
/// Add or remove one label and report the result.
fn change_label(
  ctx : Context,
  issue : String,
  label : String,
  adding : Bool,
) -> Int32 {
  with_storage(ctx, fn(storage) {
    let result = if adding {
      @lib.add_label(storage, issue, label)
    } else {
      @lib.remove_label(storage, issue, label)
    }
    match result {
      Result::Err(e) => Result::Err(@output.storage_error(e))
      Result::Ok(_) => {
        match ctx.mode {
          OutputMode::Text =>
            if adding {
              println("Added label '" + label + "' to " + issue)
            } else {
              println("Removed label '" + label + "' from " + issue)
            }
          OutputMode::Json => {
            let entries : Map[String, Json] = Map([])
            entries.set("issue_id", Json::string(issue))
            entries.set("label", Json::string(label))
            entries.set("added", Json::boolean(adding))
            emit_json(Json::object(entries))
          }
        }
        Result::Ok(())
      }
    }
  })
}

///|
/// A JSON array of strings.
fn strings_json(values : Array[String]) -> Json {
  let rows : Array[Json] = []
  for value in values {
    Array::push(rows, Json::string(value))
  }
  Json::array(rows)
}

///|
fn handle_comments_command(ctx : Context) -> Int32 {
  if ctx.args.length() < 4 {
    return fail(
      ctx,
      required_field("subcommand required", "bm comments <add|list> [args...]"),
    )
  }

  let subcmd = ctx.args[2]
  match subcmd {
    "add" => {
      if ctx.args.length() < 5 {
        return fail(
          ctx,
          required_field(
            "issue ID and comment body required", "bm comments add <issue> <body>",
          ),
        )
      }
      let issue = ctx.args[3]
      let body = ctx.args[4]
      with_storage(ctx, fn(storage) {
        match @lib.add_comment(storage, issue, body) {
          Result::Err(e) => Result::Err(@output.storage_error(e))
          Result::Ok(_) => {
            match ctx.mode {
              OutputMode::Text => println("Comment added to " + issue)
              OutputMode::Json => {
                let entries : Map[String, Json] = Map([])
                entries.set("issue_id", Json::string(issue))
                entries.set("body", Json::string(body))
                emit_json(Json::object(entries))
              }
            }
            Result::Ok(())
          }
        }
      })
    }
    "list" => {
      if ctx.args.length() < 4 {
        return fail(
          ctx,
          required_field("issue ID required", "bm comments list <issue>"),
        )
      }
      let issue = ctx.args[3]
      with_storage(ctx, fn(storage) {
        match @lib.get_comments(storage, issue) {
          Result::Err(e) => Result::Err(@output.storage_error(e))
          Result::Ok(comments) => {
            match ctx.mode {
              OutputMode::Text =>
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
              OutputMode::Json => emit_json(strings_json(comments))
            }
            Result::Ok(())
          }
        }
      })
    }
    _ =>
      fail(
        ctx,
        @output.cli_error(
          @output.ErrorKind::Validation,
          "UNKNOWN_COMMAND",
          "unknown subcommand: " + subcmd,
          hint="usage: bm comments <add|list> [args...]",
        ),
      )
  }
}
