///|
/// Whitebox tests for the structured output layer.
/// Run `moon test` to execute them.

///|
test "output: exit codes follow the beads_rust table" {
  assert_eq(@output.exit_code(@output.ErrorKind::Internal), 1)
  assert_eq(@output.exit_code(@output.ErrorKind::Database), 2)
  assert_eq(@output.exit_code(@output.ErrorKind::Issue), 3)
  assert_eq(@output.exit_code(@output.ErrorKind::Validation), 4)
  assert_eq(@output.exit_code(@output.ErrorKind::Dependency), 5)
  assert_eq(@output.exit_code(@output.ErrorKind::Sync), 6)
  assert_eq(@output.exit_code(@output.ErrorKind::Config), 7)
  assert_eq(@output.exit_code(@output.ErrorKind::Io), 8)
}

///|
test "output: @output.error_envelope writes the documented shape" {
  let error = @output.cli_error(
    @output.ErrorKind::Issue,
    "ISSUE_NOT_FOUND",
    "Issue not found: bd-x",
    hint="Run 'bm list' to see available issues.",
    context=Json::object({ "searched_id": Json::string("bd-x") }),
  )
  assert_eq(
    @output.error_envelope(error).stringify(),
    "{\"error\":{\"code\":\"ISSUE_NOT_FOUND\",\"message\":\"Issue not found: bd-x\",\"hint\":\"Run 'bm list' to see available issues.\",\"retryable\":false,\"context\":{\"searched_id\":\"bd-x\"}}}",
  )
}

///|
test "output: @output.error_envelope reports a missing hint as null" {
  let error = @output.cli_error(
    @output.ErrorKind::Validation,
    "REQUIRED_FIELD",
    "title is required",
  )
  assert_eq(
    @output.error_envelope(error).stringify(),
    "{\"error\":{\"code\":\"REQUIRED_FIELD\",\"message\":\"title is required\",\"hint\":null,\"retryable\":false,\"context\":null}}",
  )
}

///|
test "output: @output.parse_fields trims, orders, and drops duplicates" {
  match @output.parse_fields(" id , title ,id , priority ") {
    Ok(fields) => assert_eq(fields.join(","), "id,title,priority")
    Err(_) => assert_eq(true, false)
  }
}

///|
test "output: @output.parse_fields rejects unknown and empty names" {
  assert_eq(@output.parse_fields("id,titel") is Err(_), true)
  assert_eq(@output.parse_fields("id,,title") is Err(_), true)
  assert_eq(@output.parse_fields("") is Err(_), true)
  assert_eq(@output.parse_fields("type") is Err(_), true)
  // the failure carries the exit category of a validation error
  match @output.parse_fields("titel") {
    Ok(_) => assert_eq(true, false)
    Err(error) => assert_eq(@output.exit_code(error.kind), 4)
  }
}

///|
test "output: supported fields cover the documented names" {
  assert_eq(
    @output.supported_fields_text(),
    "id, title, description, status, priority, issue_type, assignee, owner, acceptance_criteria, prerequisites, external_ref, estimated_minutes, due_at, created_at, updated_at, labels, dependency_count, dependent_count",
  )
}

///|
test "output: the default projection is the issue row" {
  assert_eq(
    @output.default_fields().join(","),
    "id,title,description,status,priority,issue_type,assignee,owner,acceptance_criteria,prerequisites,external_ref,estimated_minutes,due_at,created_at,updated_at",
  )
  assert_eq(@output.needs_issue_facts(@output.default_fields()), false)
  assert_eq(@output.needs_issue_facts(["id", "labels"]), true)
  assert_eq(@output.needs_issue_facts(["id", "dependency_count"]), true)
  assert_eq(@output.needs_issue_facts(["id"]), false)
}

///|
test "output: @output.brief_fields is the ready projection" {
  assert_eq(
    @output.brief_fields().join(","),
    "id,title,status,priority,issue_type,created_at,updated_at",
  )
  assert_eq(@output.needs_issue_facts(@output.brief_fields()), false)
}

///|
test "output: @output.issue_json writes the requested fields in order" {
  let issue = @lib.make_issue("bd-1", "Title")
  assert_eq(
    @output.issue_json(issue, ["id", "title", "description", "priority"], None).stringify(),
    "{\"id\":\"bd-1\",\"title\":\"Title\",\"description\":null,\"priority\":2}",
  )
}

///|
test "output: @output.issue_json escapes strings" {
  let issue = @lib.make_issue("bd-1", "a\"b\nc")
  assert_eq(
    @output.issue_json(issue, ["title"], None).stringify(),
    "{\"title\":\"a\\\"b\\nc\"}",
  )
}

///|
test "output: labels and counts come from the loaded facts" {
  let issue = @lib.make_issue("bd-1", "Title")
  let facts = @lib.IssueFacts::{
    labels: ["alpha", "beta"],
    dependency_count: 2,
    dependent_count: 1,
  }
  assert_eq(
    @output.issue_json(
      issue,
      ["labels", "dependency_count", "dependent_count"],
      Some(facts),
    ).stringify(),
    "{\"labels\":[\"alpha\",\"beta\"],\"dependency_count\":2,\"dependent_count\":1}",
  )
  // without facts the relation fields stay empty rather than missing
  assert_eq(
    @output.issue_json(issue, ["labels"], None).stringify(),
    "{\"labels\":[]}",
  )
  assert_eq(
    @output.issue_json(issue, ["dependency_count"], None).stringify(),
    "{\"dependency_count\":0}",
  )
}

///|
test "output: @output.blocked_issue_json appends the blockers" {
  let issue = @lib.make_issue("bd-1", "Title")
  assert_eq(
    @output.blocked_issue_json(issue, ["id", "title"], None, ["bd-2", "bd-3"]).stringify(),
    "{\"id\":\"bd-1\",\"title\":\"Title\",\"blocked_by_count\":2,\"blocked_by\":[\"bd-2\",\"bd-3\"]}",
  )
}

///|
test "output: @output.page_json keeps the page envelope" {
  assert_eq(
    @output.page_json("issues", [], 3, 0, 0, false).stringify(),
    "{\"issues\":[],\"total\":3,\"limit\":0,\"offset\":0,\"has_more\":false}",
  )
  assert_eq(
    @output.page_json(
      "issues",
      [Json::object({ "id": Json::string("bd-1") })],
      1,
      10,
      10,
      true,
    ).stringify(),
    "{\"issues\":[{\"id\":\"bd-1\"}],\"total\":1,\"limit\":10,\"offset\":10,\"has_more\":true}",
  )
}

///|
test "output: @output.search_json keeps the search keys" {
  assert_eq(
    @output.search_json([], 0, 50, 0, true).stringify(),
    "{\"issues\":[],\"hidden_closed_count\":0,\"limit\":50,\"offset\":0,\"has_more\":true}",
  )
}

///|
test "output: scheduling fields are null when unset" {
  let issue = @lib.make_issue("bd-1", "Title")
  assert_eq(
    @output.issue_json(
      issue,
      ["external_ref", "estimated_minutes", "due_at"],
      None,
    ).stringify(),
    "{\"external_ref\":null,\"estimated_minutes\":null,\"due_at\":null}",
  )
}

///|
test "output: scheduling fields use the beads_rust names" {
  let issue = @lib.make_issue(
    "bd-2",
    "Scheduled",
    external_ref=Option::Some("gh-42"),
    estimate=Option::Some(45),
    due_date=Option::Some(1789117200),
  )
  assert_eq(
    @output.issue_json(
      issue,
      ["external_ref", "estimated_minutes", "due_at"],
      None,
    ).stringify(),
    "{\"external_ref\":\"gh-42\",\"estimated_minutes\":45,\"due_at\":1789117200}",
  )
}
