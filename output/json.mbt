/// JSON rendering of issues and result envelopes.

///|
/// The projection used when no `--fields` is given: every column of the issue
/// row. Labels and dependency counts are left out because they need extra
/// queries, and `--fields` asks for them explicitly.
pub fn default_fields() -> Array[String] {
  let fields : Array[String] = []
  for field in supported_fields {
    if field != "labels" &&
      field != "dependency_count" &&
      field != "dependent_count" {
      Array::push(fields, field)
    }
  }
  fields
}

///|
/// A JSON object holding every requested field of `issue`, in the requested
/// order. An optional field with no value is `null`; `labels` is always an
/// array, including when empty. `facts` must be loaded whenever the projection
/// names labels or counts; without them those fields read as empty.
pub fn issue_json(
  issue : @lib.Issue,
  fields : Array[String],
  facts : @lib.IssueFacts?,
) -> Json {
  let entries : Map[String, Json] = Map([])
  for field in fields {
    entries.set(field, issue_field_json(issue, field, facts))
  }
  Json::object(entries)
}

///|
/// A blocked issue: the requested fields plus the blockers that hold it.
pub fn blocked_issue_json(
  issue : @lib.Issue,
  fields : Array[String],
  facts : @lib.IssueFacts?,
  blocked_by : Array[String],
) -> Json {
  let entries : Map[String, Json] = Map([])
  for field in fields {
    entries.set(field, issue_field_json(issue, field, facts))
  }
  entries.set("blocked_by_count", Json::number(blocked_by.length().to_double()))
  let blockers : Array[Json] = []
  for id in blocked_by {
    Array::push(blockers, Json::string(id))
  }
  entries.set("blocked_by", Json::array(blockers))
  Json::object(entries)
}

///|
/// One field of an issue as JSON. `issue_field_json` is only called with names
/// `parse_fields` accepted.
fn issue_field_json(
  issue : @lib.Issue,
  field : String,
  facts : @lib.IssueFacts?,
) -> Json {
  match field {
    "id" => Json::string(issue.id)
    "title" => Json::string(issue.title)
    "description" => optional_json(issue.description)
    "status" => Json::string(@lib.status_to_string(issue.status))
    "priority" => Json::number(issue.priority.to_double())
    "issue_type" => Json::string(@lib.issue_type_to_string(issue.type_))
    "assignee" => optional_json(issue.assignee)
    "owner" => optional_json(issue.owner)
    "acceptance_criteria" => optional_json(issue.acceptance_criteria)
    "prerequisites" => optional_json(issue.prerequisites)
    "external_ref" => optional_json(issue.external_ref)
    "estimated_minutes" => optional_int_json(issue.estimate)
    "due_at" => optional_int_json(issue.due_date)
    "created_at" => Json::number(issue.created_at.to_double())
    "updated_at" => Json::number(issue.updated_at.to_double())
    "labels" =>
      match facts {
        Option::Some(facts) => {
          let labels : Array[Json] = []
          for label in facts.labels {
            Array::push(labels, Json::string(label))
          }
          Json::array(labels)
        }
        Option::None => Json::array([])
      }
    "dependency_count" =>
      Json::number(
        match facts {
          Option::Some(facts) => facts.dependency_count.to_double()
          Option::None => 0
        },
      )
    "dependent_count" =>
      Json::number(
        match facts {
          Option::Some(facts) => facts.dependent_count.to_double()
          Option::None => 0
        },
      )
    _ => Json::null()
  }
}

///|
/// A nullable string as JSON: `null` when the issue has no value.
fn optional_json(value : String?) -> Json {
  match value {
    Option::Some(text) => Json::string(text)
    Option::None => Json::null()
  }
}

///|
/// A nullable integer as JSON: `null` when the issue has no value.
fn optional_int_json(value : Int32?) -> Json {
  match value {
    Option::Some(number) => Json::number(number.to_double())
    Option::None => Json::null()
  }
}

///|
/// The page envelope of `bm list` and `bm blocked`.
/// `key` names the array of rows (`issues`), and `total` is the size of the
/// complete result before the cap that `limit` records.
pub fn page_json(
  key : String,
  rows : Array[Json],
  total : Int32,
  limit : Int32,
  offset : Int32,
  has_more : Bool,
) -> Json {
  let entries : Map[String, Json] = Map([])
  entries.set(key, Json::array(rows))
  entries.set("total", Json::number(total.to_double()))
  entries.set("limit", Json::number(limit.to_double()))
  entries.set("offset", Json::number(offset.to_double()))
  entries.set("has_more", Json::boolean(has_more))
  Json::object(entries)
}

///|
/// The envelope of `bm search`. It keeps the beads_rust keys instead of the
/// `total` of the other pages, so a caller that already reads `br search`
/// output keeps working.
pub fn search_json(
  rows : Array[Json],
  hidden_closed_count : Int32,
  limit : Int32,
  offset : Int32,
  has_more : Bool,
) -> Json {
  let entries : Map[String, Json] = Map([])
  entries.set("issues", Json::array(rows))
  entries.set(
    "hidden_closed_count",
    Json::number(hidden_closed_count.to_double()),
  )
  entries.set("limit", Json::number(limit.to_double()))
  entries.set("offset", Json::number(offset.to_double()))
  entries.set("has_more", Json::boolean(has_more))
  Json::object(entries)
}
