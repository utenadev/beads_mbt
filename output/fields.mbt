/// Column selection for the structured issue output of `bm list` and
/// `bm search`, plus the fixed `--brief` projection of `bm ready`.

///|
/// Every field name `--fields` accepts, in the order the default projection
/// writes them. The set is the beads_rust one minus the columns bm does not
/// have, and is validated eagerly so a typo fails instead of silently
/// dropping a column.
let supported_fields : Array[String] = [
  "id", "title", "description", "status", "priority", "issue_type", "assignee", "owner",
  "acceptance_criteria", "prerequisites", "external_ref", "estimated_minutes", "due_at",
  "created_at", "updated_at", "labels", "dependency_count", "dependent_count",
]

///|
/// The field names `--fields` accepts, space separated, for help text.
pub fn supported_fields_text() -> String {
  supported_fields.join(", ")
}

///|
/// Whether a projection writes labels or dependency counts. Those live outside
/// the issue row, so the caller has to load them first.
pub fn needs_issue_facts(fields : Array[String]) -> Bool {
  fields.contains("labels") ||
  fields.contains("dependency_count") ||
  fields.contains("dependent_count")
}

///|
/// The `bm ready --brief` projection: enough to choose work, without the long
/// free text. `bm show <id>` reads the details of the issue that was picked.
pub fn brief_fields() -> Array[String] {
  [
    "id", "title", "status", "priority", "issue_type", "created_at", "updated_at",
  ]
}

///|
/// Parse a `--fields` value into a projection.
/// Names are exact and case sensitive; surrounding whitespace is trimmed and
/// duplicates are dropped, while an unknown name or an empty entry is a
/// validation failure, including when nothing matched. Use `issue_type`, not
/// `type`.
pub fn parse_fields(spec : String) -> Result[Array[String], CliError] {
  let fields : Array[String] = []
  for part in spec.split(",") {
    let name = part.trim().to_owned()
    if name == "" {
      return Result::Err(
        cli_error(
          ErrorKind::Validation,
          "INVALID_FIELDS",
          "empty field name in --fields: " + spec,
          hint="Pass a comma-separated list of field names, for example --fields id,title.",
        ),
      )
    }
    if !supported_fields.contains(name) {
      return Result::Err(
        cli_error(
          ErrorKind::Validation,
          "INVALID_FIELDS",
          "unknown field in --fields: " + name,
          hint="Supported fields: " + supported_fields_text() + ".",
        ),
      )
    }
    if !fields.contains(name) {
      Array::push(fields, name)
    }
  }

  if fields.length() == 0 {
    return Result::Err(
      cli_error(
        ErrorKind::Validation,
        "INVALID_FIELDS",
        "--fields needs at least one field name",
        hint="Supported fields: " + supported_fields_text() + ".",
      ),
    )
  }
  Result::Ok(fields)
}
