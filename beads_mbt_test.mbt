///|
/// Blackbox tests run against the package's public API.
/// Prefer high-level behaviors over implementation details.
/// Run `moon test` to execute and `moon test --update` to refresh snapshots.

///|
/// Remove any leftover database file, then open a fresh connection.
/// Keeps the storage tests idempotent across repeated runs.
fn open_fresh(path : String) -> Result[@lib.BeadsStorage, String] {
  @fs.remove_file(path) catch {
    _ => ()
  }
  @lib.open(path)
}

///|
test "model: make_issue creates issue with defaults" {
  let issue = @lib.make_issue("bd-123456", "Test issue")

  assert_eq(issue.id, "bd-123456")
  assert_eq(issue.title, "Test issue")
  assert_eq(@lib.issue_type_to_string(issue.type_), "other")
  assert_eq(issue.priority, 2)
  assert_eq(@lib.status_to_string(issue.status), "open")
  match issue.description {
    None => ()
    Some(_) => assert_eq(true, false)
  }
  match issue.assignee {
    None => ()
    Some(_) => assert_eq(true, false)
  }
  match issue.owner {
    None => ()
    Some(_) => assert_eq(true, false)
  }
  assert_eq(issue.is_ephemeral, false)
}

///|
test "model: string_to_status parses all valid statuses" {
  let open = @lib.string_to_status("open")
  let in_progress = @lib.string_to_status("in_progress")
  let closed = @lib.string_to_status("closed")
  let deferred = @lib.string_to_status("deferred")
  let fallback = @lib.string_to_status("invalid")

  assert_eq(@lib.status_to_string(open), "open")
  assert_eq(@lib.status_to_string(in_progress), "in_progress")
  assert_eq(@lib.status_to_string(closed), "closed")
  assert_eq(@lib.status_to_string(deferred), "deferred")
  assert_eq(@lib.status_to_string(fallback), "open")
}

///|
test "model: issue_type_to_string converts all types" {
  let bug = @lib.string_to_issue_type("bug")
  let feature = @lib.string_to_issue_type("feature")
  let task = @lib.string_to_issue_type("task")
  let doc = @lib.string_to_issue_type("documentation")
  let question = @lib.string_to_issue_type("question")
  let other = @lib.string_to_issue_type("other")

  assert_eq(@lib.issue_type_to_string(bug), "bug")
  assert_eq(@lib.issue_type_to_string(feature), "feature")
  assert_eq(@lib.issue_type_to_string(task), "task")
  assert_eq(@lib.issue_type_to_string(doc), "documentation")
  assert_eq(@lib.issue_type_to_string(question), "question")
  assert_eq(@lib.issue_type_to_string(other), "other")
}

///|
test "model: string_to_issue_type parses all valid types" {
  assert_eq(@lib.issue_type_to_string(@lib.string_to_issue_type("bug")), "bug")
  assert_eq(
    @lib.issue_type_to_string(@lib.string_to_issue_type("feature")),
    "feature",
  )
  assert_eq(
    @lib.issue_type_to_string(@lib.string_to_issue_type("task")),
    "task",
  )
  assert_eq(
    @lib.issue_type_to_string(@lib.string_to_issue_type("documentation")),
    "documentation",
  )
  assert_eq(
    @lib.issue_type_to_string(@lib.string_to_issue_type("question")),
    "question",
  )
  assert_eq(
    @lib.issue_type_to_string(@lib.string_to_issue_type("other")),
    "other",
  )
  assert_eq(
    @lib.issue_type_to_string(@lib.string_to_issue_type("invalid")),
    "other",
  )
}

///|
test "model: round-trip status conversion" {
  let statuses = ["open", "in_progress", "closed", "deferred"]
  for s in statuses {
    let parsed = @lib.string_to_status(s)
    let back = @lib.status_to_string(parsed)
    assert_eq(back, s)
  }
}

///|
test "model: round-trip issue type conversion" {
  let types = ["bug", "feature", "task", "documentation", "question", "other"]
  for t in types {
    let parsed = @lib.string_to_issue_type(t)
    let back = @lib.issue_type_to_string(parsed)
    assert_eq(back, t)
  }
}

///|
test "storage: open creates database and schema" {
  match open_fresh("/tmp/test_schema.db") {
    Ok(storage) => @lib.close(storage)
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: insert and get issue" {
  match open_fresh("/tmp/beads_test_insert.db") {
    Ok(storage) => {
      match
        @lib.insert_issue(storage, @lib.make_issue("bd-test123", "Test issue")) {
        Ok(_) => ()
        Err(_) => assert_eq(true, false)
      }
      match @lib.get_issue_by_id(storage, "bd-test123") {
        Ok(Some(issue)) => {
          assert_eq(issue.id, "bd-test123")
          assert_eq(issue.title, "Test issue")
          assert_eq(@lib.issue_type_to_string(issue.type_), "other")
          assert_eq(issue.priority, 2)
          assert_eq(@lib.status_to_string(issue.status), "open")
          assert_eq(issue.is_ephemeral, false)
        }
        _ => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: created issues carry Unix-second timestamps" {
  match open_fresh("/tmp/beads_test_timestamps.db") {
    Ok(storage) => {
      let issue = @lib.make_issue("bd-timestamp1", "Timestamped issue")
      assert_eq(issue.created_at, issue.updated_at)
      assert_eq(issue.created_at > 0, true)
      match @lib.insert_issue(storage, issue) {
        Ok(_) => ()
        Err(_) => assert_eq(true, false)
      }
      // The row keeps what `make_issue` stamped, and an update moves it on.
      match @lib.get_issue_by_id(storage, "bd-timestamp1") {
        Ok(Some(stored)) => {
          assert_eq(stored.created_at, issue.created_at)
          assert_eq(stored.updated_at, issue.updated_at)
        }
        _ => assert_eq(true, false)
      }
      match @lib.update_issue_title(storage, "bd-timestamp1", "Renamed") {
        Ok(_) => ()
        Err(_) => assert_eq(true, false)
      }
      match @lib.get_issue_by_id(storage, "bd-timestamp1") {
        Ok(Some(stored)) => {
          assert_eq(stored.created_at, issue.created_at)
          assert_eq(stored.updated_at >= stored.created_at, true)
        }
        _ => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: list_issues orders by recency and breaks ties by id" {
  match open_fresh("/tmp/beads_test_list.db") {
    Ok(storage) => {
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-1",
            "Issue 1",
            2,
            100,
            Option::None,
            @lib.Status::Open,
          ),
        ),
      )
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-2",
            "Issue 2",
            2,
            200,
            Option::None,
            @lib.Status::Open,
          ),
        ),
      )
      // same second as bd-2, so the id decides
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-3",
            "Issue 3",
            2,
            200,
            Option::None,
            @lib.Status::Open,
          ),
        ),
      )

      match @lib.list_issues(storage) {
        Ok(issues) => {
          assert_eq(issues.length(), 3)
          assert_eq(issues[0].id, "bd-2")
          assert_eq(issues[1].id, "bd-3")
          assert_eq(issues[2].id, "bd-1")
        }
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: update_issue_status" {
  match open_fresh("/tmp/beads_test_status.db") {
    Ok(storage) => {
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-status1", "Status test")),
      )
      match @lib.update_issue_status(storage, "bd-status1", "closed") {
        Ok(_) => ()
        Err(_) => assert_eq(true, false)
      }
      match @lib.get_issue_by_id(storage, "bd-status1") {
        Ok(Some(issue)) =>
          assert_eq(@lib.status_to_string(issue.status), "closed")
        _ => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: get_ready_issues" {
  match open_fresh("/tmp/beads_test_ready.db") {
    Ok(storage) => {
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-ready1", "Ready issue")),
      )
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-ready2", "Closed issue")),
      )
      ignore(@lib.update_issue_status(storage, "bd-ready2", "closed"))

      match @lib.get_ready_issues(storage) {
        Ok(issues) => {
          assert_eq(issues.length(), 1)
          assert_eq(issues[0].id, "bd-ready1")
          assert_eq(@lib.status_to_string(issues[0].status), "open")
        }
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: update_issue_title" {
  match open_fresh("/tmp/beads_test_title.db") {
    Ok(storage) => {
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-title1", "Old title")),
      )
      match @lib.update_issue_title(storage, "bd-title1", "New title") {
        Ok(_) => ()
        Err(_) => assert_eq(true, false)
      }
      match @lib.get_issue_by_id(storage, "bd-title1") {
        Ok(Some(issue)) => assert_eq(issue.title, "New title")
        _ => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: update_issue_priority" {
  match open_fresh("/tmp/beads_test_priority.db") {
    Ok(storage) => {
      ignore(
        @lib.insert_issue(
          storage,
          @lib.make_issue("bd-priority1", "Priority test"),
        ),
      )
      match @lib.update_issue_priority(storage, "bd-priority1", 0) {
        Ok(_) => ()
        Err(_) => assert_eq(true, false)
      }
      match @lib.get_issue_by_id(storage, "bd-priority1") {
        Ok(Some(issue)) => assert_eq(issue.priority, 0)
        _ => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: defer_issue" {
  match open_fresh("/tmp/beads_test_defer.db") {
    Ok(storage) => {
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-defer1", "Defer test")),
      )
      match @lib.defer_issue(storage, "bd-defer1") {
        Ok(_) => ()
        Err(_) => assert_eq(true, false)
      }
      match @lib.get_issue_by_id(storage, "bd-defer1") {
        Ok(Some(issue)) =>
          assert_eq(@lib.status_to_string(issue.status), "deferred")
        _ => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: add_dependency" {
  match open_fresh("/tmp/beads_test_dep.db") {
    Ok(storage) => {
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-dep1", "Dep 1")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-dep2", "Dep 2")))
      match
        @lib.add_dependency(
          storage,
          "bd-dep1",
          "bd-dep2",
          @lib.default_dependency_type(),
        ) {
        Ok(_) => ()
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "util: generate_issue_id has prefix" {
  let id = @lib.generate_issue_id("bd")
  assert_eq(id.has_prefix("bd-"), true)
  assert_eq(id.length(), 9)
}

///|
test "util: generate_short_id returns 6 chars" {
  let id = @lib.generate_short_id()
  assert_eq(id.length(), 6)
}

///|
test "util: current_timestamp is Unix seconds on the wall clock" {
  let before = (@env.now() / 1000UL).to_int()
  let ts = @lib.current_timestamp()
  let after = (@env.now() / 1000UL).to_int()
  // Seconds, not milliseconds: a millisecond reading would be ~1000x larger.
  assert_eq(ts >= before, true)
  assert_eq(ts <= after, true)
}

///|
test "model: IssueType enum equality" {
  let bug1 = @lib.string_to_issue_type("bug")
  let bug2 = @lib.string_to_issue_type("bug")
  let feature = @lib.string_to_issue_type("feature")

  assert_eq(@lib.issue_type_to_string(bug1), @lib.issue_type_to_string(bug2))
  assert_eq(
    @lib.issue_type_to_string(bug1) == @lib.issue_type_to_string(feature),
    false,
  )
}

///|
test "model: Status enum equality" {
  let open1 = @lib.string_to_status("open")
  let open2 = @lib.string_to_status("open")
  let closed = @lib.string_to_status("closed")

  assert_eq(@lib.status_to_string(open1), @lib.status_to_string(open2))
  assert_eq(
    @lib.status_to_string(open1) == @lib.status_to_string(closed),
    false,
  )
}

// ============================================================================
// Step 1: parsing, blocking semantics, search, and schema migration
// ============================================================================

///|
/// Build an issue with every field spelled out, so tests can control values
/// that `make_issue` leaves at its defaults (timestamps, descriptions, status).
fn build_issue(
  id : String,
  title : String,
  priority : Int32,
  created_at : Int32,
  description : String?,
  status : @lib.Status,
) -> @lib.Issue {
  @lib.Issue::{
    id,
    title,
    type_: @lib.IssueType::Task,
    priority,
    status,
    description,
    assignee: Option::None,
    owner: Option::None,
    acceptance_criteria: Option::None,
    prerequisites: Option::None,
    external_ref: Option::None,
    estimate: Option::None,
    due_date: Option::None,
    defer_until: Option::None,
    created_at,
    updated_at: created_at,
    is_ephemeral: false,
  }
}

///|
/// `is_blocked` as a plain bool; a storage error fails the test.
fn is_blocked_or_fail(storage : @lib.BeadsStorage, id : String) -> Bool {
  match @lib.is_blocked(storage, id) {
    Ok(value) => value
    Err(_) => abort("is_blocked returned an error")
  }
}

///|
/// The ready issues as a comma-separated id list, so ordering is easy to read.
fn ready_ids(storage : @lib.BeadsStorage) -> String {
  match @lib.get_ready_issues(storage) {
    Ok(issues) => {
      let ids : Array[String] = []
      for issue in issues {
        Array::push(ids, issue.id)
      }
      ids.join(",")
    }
    Err(_) => abort("get_ready_issues returned an error")
  }
}

///|
/// Search results as a comma-separated id list, so ordering is easy to read.
fn search_ids(storage : @lib.BeadsStorage, query : String) -> String {
  match @lib.search_issues(storage, query) {
    Ok(issues) => {
      let ids : Array[String] = []
      for issue in issues {
        Array::push(ids, issue.id)
      }
      ids.join(",")
    }
    Err(_) => abort("search_issues returned an error")
  }
}

///|
/// The number of search hits, without listing them.
fn search_count(storage : @lib.BeadsStorage, query : String) -> Int32 {
  match @lib.search_issues(storage, query) {
    Ok(issues) => issues.length()
    Err(_) => abort("search_issues returned an error")
  }
}

///|
/// Write a database that predates typed dependencies, so the migration path
/// can be exercised without an old binary.
fn write_legacy_database(path : String) -> Unit {
  @fs.remove_file(path) catch {
    _ => ()
  }
  let conn = @sqlite3.Connection::open(path) catch {
    _ => abort("cannot open the legacy database")
  }
  let statements = [
    "CREATE TABLE issues (id TEXT PRIMARY KEY, title TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'other', priority INTEGER NOT NULL DEFAULT 2, status TEXT NOT NULL DEFAULT 'open', description TEXT, assignee TEXT, owner TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, closed_at INTEGER, closed_reason TEXT, parent TEXT, estimate INTEGER, due_date INTEGER, external_ref TEXT, is_ephemeral INTEGER NOT NULL DEFAULT 0);",
    "CREATE TABLE issue_dependencies (issue_id TEXT NOT NULL, depends_on TEXT NOT NULL, PRIMARY KEY (issue_id, depends_on), FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE, FOREIGN KEY (depends_on) REFERENCES issues(id) ON DELETE CASCADE);",
    "INSERT INTO issues (id, title, created_at, updated_at) VALUES ('bd-legacy1', 'Legacy blocker', 1, 1);",
    "INSERT INTO issues (id, title, created_at, updated_at) VALUES ('bd-legacy2', 'Legacy blocked', 2, 2);",
    "INSERT INTO issue_dependencies (issue_id, depends_on) VALUES ('bd-legacy2', 'bd-legacy1');",
  ]
  for sql in statements {
    let stmt = conn.prepare(sql) catch {
      _ => abort("cannot prepare a legacy statement")
    }
    ignore(stmt.step() catch { _ => abort("cannot run a legacy statement") })
    stmt.finalize() catch {
      _ => ()
    }
  }
  conn.close() catch {
    _ => ()
  }
}

///|
/// Write a database at schema version 1: typed dependencies are already part
/// of the key, but the planning columns are not there yet.
fn write_version_one_database(path : String) -> Unit {
  @fs.remove_file(path) catch {
    _ => ()
  }
  let conn = @sqlite3.Connection::open(path) catch {
    _ => abort("cannot open the version 1 database")
  }
  let statements = [
    "CREATE TABLE issues (id TEXT PRIMARY KEY, title TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'other', priority INTEGER NOT NULL DEFAULT 2, status TEXT NOT NULL DEFAULT 'open', description TEXT, assignee TEXT, owner TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, is_ephemeral INTEGER NOT NULL DEFAULT 0);",
    "CREATE TABLE issue_dependencies (issue_id TEXT NOT NULL, depends_on TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'blocks', PRIMARY KEY (issue_id, depends_on, type));",
    "CREATE TABLE issue_labels (issue_id TEXT NOT NULL, label TEXT NOT NULL, PRIMARY KEY (issue_id, label));",
    "INSERT INTO issues (id, title, description, created_at, updated_at) VALUES ('bd-v1', 'Version one issue', 'kept text', 7, 7);",
    "INSERT INTO issue_labels (issue_id, label) VALUES ('bd-v1', 'step1');", "INSERT INTO issue_dependencies (issue_id, depends_on, type) VALUES ('bd-v1', 'bd-missing', 'blocks');",
    "PRAGMA user_version = 1;",
  ]
  for sql in statements {
    let stmt = conn.prepare(sql) catch {
      _ => abort("cannot prepare a version 1 statement")
    }
    ignore(stmt.step() catch { _ => abort("cannot run a version 1 statement") })
    stmt.finalize() catch {
      _ => ()
    }
  }
  conn.close() catch {
    _ => ()
  }
}

///|
test "model: parse_priority accepts 0-4 and P0-P4" {
  assert_eq(@lib.parse_priority("0"), Ok(0))
  assert_eq(@lib.parse_priority("4"), Ok(4))
  assert_eq(@lib.parse_priority("P0"), Ok(0))
  assert_eq(@lib.parse_priority("p3"), Ok(3))
  assert_eq(@lib.parse_priority("P4"), Ok(4))
}

///|
/// `parse_issue_type` as its canonical name; a rejected value fails the test.
fn parse_type(input : String) -> String {
  match @lib.parse_issue_type(input) {
    Ok(value) => @lib.issue_type_to_string(value)
    Err(_) => abort("parse_issue_type rejected: " + input)
  }
}

///|
test "model: parse_priority rejects anything else" {
  assert_eq(@lib.parse_priority("9") is Err(_), true)
  assert_eq(@lib.parse_priority("P9") is Err(_), true)
  assert_eq(@lib.parse_priority("high") is Err(_), true)
  assert_eq(@lib.parse_priority("") is Err(_), true)
}

///|
test "model: parse_issue_type accepts the documented types" {
  assert_eq(parse_type("bug"), "bug")
  assert_eq(parse_type("feature"), "feature")
  assert_eq(parse_type("task"), "task")
  assert_eq(parse_type("documentation"), "documentation")
  assert_eq(parse_type("docs"), "documentation")
  assert_eq(parse_type("question"), "question")
  assert_eq(parse_type("other"), "other")
}

///|
test "model: parse_issue_type rejects unknown types" {
  assert_eq(@lib.parse_issue_type("nonsense") is Err(_), true)
  assert_eq(@lib.parse_issue_type("") is Err(_), true)
}

///|
test "model: is_blocking_dependency_type follows beads_rust" {
  assert_eq(@lib.default_dependency_type(), "blocks")
  assert_eq(@lib.is_blocking_dependency_type("blocks"), true)
  assert_eq(@lib.is_blocking_dependency_type("conditional-blocks"), true)
  assert_eq(@lib.is_blocking_dependency_type("waits-for"), true)
  assert_eq(@lib.is_blocking_dependency_type("related"), false)
  assert_eq(@lib.is_blocking_dependency_type("discovered-from"), false)
  // a child inherits its parent's blocked state, the edge itself does not block
  assert_eq(@lib.is_blocking_dependency_type("parent-child"), false)
}

///|
test "storage: is_blocked only considers blocking dependency types" {
  match open_fresh("/tmp/beads_test_blocked_types.db") {
    Ok(storage) => {
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-t1", "Blocker")))
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-t2", "Blocking edge")),
      )
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-t3", "Related edge")),
      )
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-t4", "Dangling edge")),
      )
      ignore(@lib.add_dependency(storage, "bd-t2", "bd-t1", "blocks"))
      ignore(@lib.add_dependency(storage, "bd-t3", "bd-t1", "related"))
      ignore(@lib.add_dependency(storage, "bd-t4", "bd-missing", "blocks"))

      assert_eq(is_blocked_or_fail(storage, "bd-t1"), false)
      assert_eq(is_blocked_or_fail(storage, "bd-t2"), true)
      assert_eq(is_blocked_or_fail(storage, "bd-t3"), false)
      // an edge whose target is unknown keeps blocking
      assert_eq(is_blocked_or_fail(storage, "bd-t4"), true)
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: is_blocked follows the blocker's status" {
  match open_fresh("/tmp/beads_test_blocked_status.db") {
    Ok(storage) => {
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-s1", "Blocker")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-s2", "Waiting")))
      ignore(@lib.add_dependency(storage, "bd-s2", "bd-s1", "blocks"))

      assert_eq(is_blocked_or_fail(storage, "bd-s2"), true)

      // deferred is not done, so it still blocks
      ignore(@lib.defer_issue(storage, "bd-s1"))
      assert_eq(is_blocked_or_fail(storage, "bd-s2"), true)

      ignore(@lib.update_issue_status(storage, "bd-s1", "closed"))
      assert_eq(is_blocked_or_fail(storage, "bd-s2"), false)
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: a child inherits its parent's blocked state" {
  match open_fresh("/tmp/beads_test_parent_child.db") {
    Ok(storage) => {
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-p0", "Blocker")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-p1", "Parent")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-p2", "Child")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-p3", "Grandchild")))
      ignore(@lib.add_dependency(storage, "bd-p1", "bd-p0", "blocks"))
      ignore(@lib.add_dependency(storage, "bd-p2", "bd-p1", "parent-child"))
      ignore(@lib.add_dependency(storage, "bd-p3", "bd-p2", "parent-child"))

      assert_eq(is_blocked_or_fail(storage, "bd-p1"), true)
      assert_eq(is_blocked_or_fail(storage, "bd-p2"), true)
      assert_eq(is_blocked_or_fail(storage, "bd-p3"), true)

      ignore(@lib.update_issue_status(storage, "bd-p0", "closed"))
      assert_eq(is_blocked_or_fail(storage, "bd-p1"), false)
      assert_eq(is_blocked_or_fail(storage, "bd-p2"), false)
      assert_eq(is_blocked_or_fail(storage, "bd-p3"), false)

      // parent-child alone never blocks
      ignore(@lib.update_issue_status(storage, "bd-p0", "open"))
      ignore(@lib.remove_dependency(storage, "bd-p1", "bd-p0"))
      assert_eq(is_blocked_or_fail(storage, "bd-p2"), false)
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: get_ready_issues drops blocked issues and orders by priority" {
  match open_fresh("/tmp/beads_test_ready_order.db") {
    Ok(storage) => {
      // Three ready issues and one blocker that holds back `bd-r-blocked`.
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-r-old-low",
            "Older low priority",
            3,
            100,
            Option::None,
            @lib.Status::Open,
          ),
        ),
      )
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-r-new-high",
            "Newer high priority",
            1,
            200,
            Option::None,
            @lib.Status::Open,
          ),
        ),
      )
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-r-new-low",
            "Newer low priority",
            3,
            300,
            Option::None,
            @lib.Status::Open,
          ),
        ),
      )
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-r-blocked",
            "Blocked",
            0,
            400,
            Option::None,
            @lib.Status::Open,
          ),
        ),
      )
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-r-hold", "Holder")))
      ignore(
        @lib.add_dependency(storage, "bd-r-blocked", "bd-r-hold", "blocks"),
      )

      // priority first, then newest, and the blocked issue never shows up
      assert_eq(
        ready_ids(storage),
        "bd-r-new-high,bd-r-hold,bd-r-new-low,bd-r-old-low",
      )
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: get_blocked_issues skips closed issues" {
  match open_fresh("/tmp/beads_test_blocked_list.db") {
    Ok(storage) => {
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-l1", "Holder")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-l2", "Waiting")))
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-l3", "Waiting too")),
      )
      ignore(@lib.add_dependency(storage, "bd-l2", "bd-l1", "blocks"))
      ignore(@lib.add_dependency(storage, "bd-l3", "bd-l1", "blocks"))
      ignore(@lib.update_issue_status(storage, "bd-l3", "closed"))

      match @lib.get_blocked_issues(storage) {
        Ok(issues) => {
          assert_eq(issues.length(), 1)
          assert_eq(issues[0].id, "bd-l2")
        }
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: typed dependencies coexist for the same pair" {
  match open_fresh("/tmp/beads_test_typed_dep.db") {
    Ok(storage) => {
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-d1", "Source")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-d2", "Target")))
      ignore(@lib.add_dependency(storage, "bd-d1", "bd-d2", "blocks"))
      ignore(@lib.add_dependency(storage, "bd-d1", "bd-d2", "related"))
      // adding the same typed edge twice is a no-op
      ignore(@lib.add_dependency(storage, "bd-d1", "bd-d2", "blocks"))

      match @lib.get_dependencies(storage, "bd-d1") {
        Ok(deps) => {
          assert_eq(deps.length(), 2)
          assert_eq(deps[0].depends_on, "bd-d2")
          assert_eq(deps[0].type_, "blocks")
          assert_eq(deps[1].type_, "related")
        }
        Err(_) => assert_eq(true, false)
      }

      // only the blocking edge keeps the source blocked
      ignore(@lib.update_issue_status(storage, "bd-d2", "closed"))
      ignore(@lib.add_dependency(storage, "bd-d2", "bd-d1", "related"))
      assert_eq(is_blocked_or_fail(storage, "bd-d2"), false)
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: search matches id, title and description" {
  match open_fresh("/tmp/beads_test_search.db") {
    Ok(storage) => {
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-srch1",
            "Rename the widget",
            2,
            1,
            Option::Some("mentions gadget in the body"),
            @lib.Status::Open,
          ),
        ),
      )
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-srch2",
            "Unrelated",
            2,
            2,
            Option::None,
            @lib.Status::Open,
          ),
        ),
      )

      // title match, ASCII case-insensitive in either direction
      assert_eq(search_ids(storage, "WIDGET"), "bd-srch1")
      assert_eq(search_ids(storage, "rename"), "bd-srch1")
      // description match
      assert_eq(search_ids(storage, "gadget"), "bd-srch1")
      // id match
      assert_eq(search_ids(storage, "bd-srch2"), "bd-srch2")
      // no match
      assert_eq(search_ids(storage, "nothing here"), "")
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: search orders by priority and caps the result count" {
  match open_fresh("/tmp/beads_test_search_order.db") {
    Ok(storage) => {
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-so-low",
            "match low",
            3,
            300,
            Option::None,
            @lib.Status::Open,
          ),
        ),
      )
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-so-high",
            "match high",
            0,
            100,
            Option::None,
            @lib.Status::Open,
          ),
        ),
      )
      ignore(
        @lib.insert_issue(
          storage,
          build_issue(
            "bd-so-mid",
            "match mid",
            1,
            200,
            Option::None,
            @lib.Status::Open,
          ),
        ),
      )
      assert_eq(search_ids(storage, "match"), "bd-so-high,bd-so-mid,bd-so-low")
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: search stops at the result limit" {
  match open_fresh("/tmp/beads_test_search_limit.db") {
    Ok(storage) => {
      let mut index = 0
      while index < 55 {
        ignore(
          @lib.insert_issue(
            storage,
            build_issue(
              "bd-lim" + index.to_string(),
              "match number " + index.to_string(),
              2,
              index,
              Option::None,
              @lib.Status::Open,
            ),
          ),
        )
        index += 1
      }
      // beads_rust's DEFAULT_SEARCH_LIMIT
      assert_eq(search_count(storage, "match"), 50)
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: migrating a legacy database keeps its dependencies" {
  let path = "/tmp/beads_test_migration.db"
  write_legacy_database(path)

  match @lib.open(path) {
    Err(_) => assert_eq(true, false)
    Ok(storage) => {
      // the untyped edge survives as a `blocks` edge
      match @lib.get_dependencies(storage, "bd-legacy2") {
        Ok(deps) => {
          assert_eq(deps.length(), 1)
          assert_eq(deps[0].depends_on, "bd-legacy1")
          assert_eq(deps[0].type_, "blocks")
        }
        Err(_) => assert_eq(true, false)
      }
      assert_eq(is_blocked_or_fail(storage, "bd-legacy2"), true)

      // `type` is part of the key now, so a second type is allowed
      ignore(
        @lib.add_dependency(storage, "bd-legacy2", "bd-legacy1", "related"),
      )
      match @lib.get_dependencies(storage, "bd-legacy2") {
        Ok(deps) => assert_eq(deps.length(), 2)
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
  }

  // reopening must not migrate twice
  match @lib.open(path) {
    Err(_) => assert_eq(true, false)
    Ok(storage) => {
      match @lib.get_dependencies(storage, "bd-legacy2") {
        Ok(deps) => assert_eq(deps.length(), 2)
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
  }
}

// ============================================================================
// Step 2: machine-readable output
// ============================================================================

///|
/// Build an issue that carries the planning sections `bm show` renders.
fn build_planned_issue(
  id : String,
  acceptance_criteria : String?,
  prerequisites : String?,
) -> @lib.Issue {
  @lib.Issue::{
    id,
    title: "Planned " + id,
    type_: @lib.IssueType::Task,
    priority: 2,
    status: @lib.Status::Open,
    description: Option::None,
    assignee: Option::None,
    owner: Option::None,
    acceptance_criteria,
    prerequisites,
    external_ref: Option::None,
    estimate: Option::None,
    due_date: Option::None,
    defer_until: Option::None,
    created_at: 10,
    updated_at: 10,
    is_ephemeral: false,
  }
}

///|
/// The label list of one issue as a comma-separated string.
fn facts_labels(storage : @lib.BeadsStorage, id : String) -> String {
  let issues = match @lib.get_issue_by_id(storage, id) {
    Ok(Option::Some(issue)) => [issue]
    Ok(Option::None) => abort("issue is missing")
    Err(_) => abort("get_issue_by_id returned an error")
  }
  let facts = match @lib.load_issue_facts(storage, issues) {
    Ok(facts) => facts
    Err(_) => abort("load_issue_facts returned an error")
  }
  match facts.get(id) {
    Option::Some(entry) => entry.labels.join(",")
    Option::None => abort("no facts for " + id)
  }
}

///|
/// The `dependency_count/dependent_count` of one issue.
fn facts_counts(storage : @lib.BeadsStorage, id : String) -> String {
  let issues = match @lib.get_issue_by_id(storage, id) {
    Ok(Option::Some(issue)) => [issue]
    Ok(Option::None) => abort("issue is missing")
    Err(_) => abort("get_issue_by_id returned an error")
  }
  let facts = match @lib.load_issue_facts(storage, issues) {
    Ok(facts) => facts
    Err(_) => abort("load_issue_facts returned an error")
  }
  match facts.get(id) {
    Option::Some(entry) =>
      entry.dependency_count.to_string() +
      "/" +
      entry.dependent_count.to_string()
    Option::None => abort("no facts for " + id)
  }
}

///|
/// The blocked issues as `id(blockers)` entries joined by commas.
fn blocked_with_blockers(storage : @lib.BeadsStorage) -> String {
  match @lib.get_blocked_issues_with_blockers(storage) {
    Ok(entries) => {
      let parts : Array[String] = []
      for entry in entries {
        Array::push(
          parts,
          entry.issue.id + "(" + entry.blockers.join(" ") + ")",
        )
      }
      parts.join(",")
    }
    Err(_) => abort("get_blocked_issues_with_blockers returned an error")
  }
}

///|
test "storage: planning columns round-trip and read back as absent when empty" {
  match open_fresh("/tmp/beads_test_planning_columns.db") {
    Ok(storage) => {
      ignore(
        @lib.insert_issue(
          storage,
          build_planned_issue(
            "bd-plan1",
            Option::Some("- [ ] first"),
            Option::Some("needs bd-plan2"),
          ),
        ),
      )
      ignore(
        @lib.insert_issue(
          storage,
          build_planned_issue("bd-plan2", Option::None, Option::None),
        ),
      )

      match @lib.get_issue_by_id(storage, "bd-plan1") {
        Ok(Option::Some(issue)) => {
          assert_eq(issue.acceptance_criteria, Option::Some("- [ ] first"))
          assert_eq(issue.prerequisites, Option::Some("needs bd-plan2"))
        }
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }
      // an empty column is `None` again, not an empty string
      match @lib.get_issue_by_id(storage, "bd-plan2") {
        Ok(Option::Some(issue)) => {
          assert_eq(issue.acceptance_criteria, Option::None)
          assert_eq(issue.prerequisites, Option::None)
        }
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: migrating a legacy database adds the planning columns" {
  let path = "/tmp/beads_test_legacy_planning.db"
  write_legacy_database(path)

  match @lib.open(path) {
    Err(_) => assert_eq(true, false)
    Ok(storage) => {
      match @lib.get_issue_by_id(storage, "bd-legacy1") {
        Ok(Option::Some(issue)) => {
          assert_eq(issue.title, "Legacy blocker")
          assert_eq(issue.acceptance_criteria, Option::None)
          assert_eq(issue.prerequisites, Option::None)
        }
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }
      // the added columns are writable after the migration
      ignore(
        @lib.insert_issue(
          storage,
          build_planned_issue(
            "bd-legacy3",
            Option::Some("done when green"),
            Option::None,
          ),
        ),
      )
      match @lib.get_issue_by_id(storage, "bd-legacy3") {
        Ok(Option::Some(issue)) =>
          assert_eq(issue.acceptance_criteria, Option::Some("done when green"))
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
  }
}

///|
test "storage: migrating a version one database keeps its rows and labels" {
  let path = "/tmp/beads_test_v1_planning.db"
  write_version_one_database(path)

  match @lib.open(path) {
    Err(_) => assert_eq(true, false)
    Ok(storage) => {
      match @lib.get_issue_by_id(storage, "bd-v1") {
        Ok(Option::Some(issue)) => {
          assert_eq(issue.title, "Version one issue")
          assert_eq(issue.description, Option::Some("kept text"))
          assert_eq(issue.created_at, 7)
          assert_eq(issue.acceptance_criteria, Option::None)
          assert_eq(issue.defer_until, Option::None)
        }
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }
      // the comments table gained an author in the same migration
      ignore(@lib.add_comment(storage, "bd-v1", "migrated", author="alice"))
      match @lib.get_comments(storage, "bd-v1") {
        Ok(comments) => assert_eq(comments[0].author, "alice")
        Err(_) => assert_eq(true, false)
      }
      assert_eq(facts_labels(storage, "bd-v1"), "step1")
      // a version 1 row still blocks on an issue that no longer exists
      assert_eq(is_blocked_or_fail(storage, "bd-v1"), true)
      @lib.close(storage)
    }
  }

  // reopening must not migrate twice
  match @lib.open(path) {
    Err(_) => assert_eq(true, false)
    Ok(storage) => {
      match @lib.get_issue_by_id(storage, "bd-v1") {
        Ok(Option::Some(issue)) => assert_eq(issue.title, "Version one issue")
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
  }
}

///|
test "storage: exclude_issues_with_labels hides any issue carrying a label" {
  match open_fresh("/tmp/beads_test_exclude_labels.db") {
    Ok(storage) => {
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-a", "A")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-b", "B")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-c", "C")))
      ignore(@lib.add_label(storage, "bd-a", "internal"))
      ignore(@lib.add_label(storage, "bd-a", "urgent"))
      ignore(@lib.add_label(storage, "bd-b", "urgent"))

      let issues = match @lib.list_issues(storage) {
        Ok(issues) => issues
        Err(_) => abort("list_issues returned an error")
      }
      let kept = match
        @lib.exclude_issues_with_labels(storage, issues, ["urgent"]) {
        Ok(kept) => kept
        Err(_) => abort("exclude_issues_with_labels returned an error")
      }
      let ids : Array[String] = []
      for issue in kept {
        Array::push(ids, issue.id)
      }
      assert_eq(ids.join(","), "bd-c")

      // an empty exclusion keeps every issue, and any match hides
      match @lib.exclude_issues_with_labels(storage, issues, []) {
        Ok(kept) => assert_eq(kept.length(), 3)
        Err(_) => assert_eq(true, false)
      }
      match
        @lib.exclude_issues_with_labels(storage, issues, ["internal", "urgent"]) {
        Ok(kept) => assert_eq(kept.length(), 1)
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: load_issue_facts counts labels and blocking edges" {
  match open_fresh("/tmp/beads_test_issue_facts.db") {
    Ok(storage) => {
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-f1", "One")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-f2", "Two")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-f3", "Three")))
      ignore(@lib.add_label(storage, "bd-f1", "beta"))
      ignore(@lib.add_label(storage, "bd-f1", "alpha"))
      ignore(@lib.add_dependency(storage, "bd-f1", "bd-f2", "blocks"))
      ignore(@lib.add_dependency(storage, "bd-f1", "bd-f3", "related"))

      // labels come back sorted, and both typed edges count
      assert_eq(facts_labels(storage, "bd-f1"), "alpha,beta")
      assert_eq(facts_counts(storage, "bd-f1"), "2/0")
      assert_eq(facts_counts(storage, "bd-f2"), "0/1")
      assert_eq(facts_counts(storage, "bd-f3"), "0/1")
      assert_eq(facts_labels(storage, "bd-f2"), "")
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: search_matching_issues returns every match before the cap" {
  match open_fresh("/tmp/beads_test_search_matching.db") {
    Ok(storage) => {
      let mut index = 0
      while index < 55 {
        ignore(
          @lib.insert_issue(
            storage,
            build_issue(
              "bd-all" + index.to_string(),
              "match number " + index.to_string(),
              2,
              index,
              Option::None,
              @lib.Status::Open,
            ),
          ),
        )
        index += 1
      }
      match @lib.search_matching_issues(storage, "match") {
        Ok(matches) => assert_eq(matches.length(), 55)
        Err(_) => assert_eq(true, false)
      }
      // the capped helper still stops at beads_rust's default
      assert_eq(search_count(storage, "match"), 50)
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: blocked issues carry their blockers, including inherited ones" {
  match open_fresh("/tmp/beads_test_blockers.db") {
    Ok(storage) => {
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-b1", "Blocker")))
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-b2", "Waiting")))
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-b3", "Other blocker")),
      )
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-b4", "Child of waiting")),
      )
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-b5", "Related only")),
      )
      ignore(@lib.add_dependency(storage, "bd-b2", "bd-b3", "blocks"))
      ignore(@lib.add_dependency(storage, "bd-b2", "bd-b1", "blocks"))
      ignore(@lib.add_dependency(storage, "bd-b2", "bd-b5", "related"))
      ignore(@lib.add_dependency(storage, "bd-b4", "bd-b2", "parent-child"))

      // sorted, without the `related` target
      assert_eq(
        blocked_with_blockers(storage),
        "bd-b2(bd-b1 bd-b3),bd-b4(bd-b1 bd-b3)",
      )

      // a closed blocker drops off, and releases the inherited child too
      ignore(@lib.update_issue_status(storage, "bd-b1", "closed"))
      ignore(@lib.update_issue_status(storage, "bd-b3", "closed"))
      assert_eq(blocked_with_blockers(storage), "")
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: scheduling columns round-trip and clear back to absent" {
  match open_fresh("/tmp/beads_test_scheduling_columns.db") {
    Ok(storage) => {
      ignore(
        @lib.insert_issue(
          storage,
          @lib.make_issue(
            "bd-sched1",
            "Scheduled",
            estimate=Option::Some(90),
            due_date=Option::Some(1789117200),
            external_ref=Option::Some("gh-123"),
          ),
        ),
      )
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-sched2", "Unscheduled")),
      )

      match @lib.get_issue_by_id(storage, "bd-sched1") {
        Ok(Option::Some(issue)) => {
          assert_eq(issue.external_ref, Option::Some("gh-123"))
          assert_eq(issue.estimate, Option::Some(90))
          assert_eq(issue.due_date, Option::Some(1789117200))
        }
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }
      // no value in SQL is NULL, not 0 and not the empty string
      match @lib.get_issue_by_id(storage, "bd-sched2") {
        Ok(Option::Some(issue)) => {
          assert_eq(issue.external_ref, Option::None)
          assert_eq(issue.estimate, Option::None)
          assert_eq(issue.due_date, Option::None)
        }
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }

      ignore(@lib.update_issue_estimate(storage, "bd-sched2", Option::Some(30)))
      ignore(
        @lib.update_issue_due_date(
          storage,
          "bd-sched2",
          Option::Some(1789117200),
        ),
      )
      ignore(
        @lib.update_issue_external_ref(
          storage,
          "bd-sched2",
          Option::Some("jira-9"),
        ),
      )
      match @lib.get_issue_by_id(storage, "bd-sched2") {
        Ok(Option::Some(issue)) => {
          assert_eq(issue.external_ref, Option::Some("jira-9"))
          assert_eq(issue.estimate, Option::Some(30))
          assert_eq(issue.due_date, Option::Some(1789117200))
        }
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }

      ignore(@lib.update_issue_estimate(storage, "bd-sched2", Option::None))
      ignore(@lib.update_issue_due_date(storage, "bd-sched2", Option::None))
      ignore(@lib.update_issue_external_ref(storage, "bd-sched2", Option::None))
      match @lib.get_issue_by_id(storage, "bd-sched2") {
        Ok(Option::Some(issue)) => {
          assert_eq(issue.external_ref, Option::None)
          assert_eq(issue.estimate, Option::None)
          assert_eq(issue.due_date, Option::None)
        }
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
/// The timestamp `text` parses to, or -1 when it is rejected.
fn parsed_date(text : String) -> Int32 {
  match @lib.parse_date_to_timestamp(text) {
    Ok(value) => value
    Err(_) => -1
  }
}

///|
test "util: parse_date_to_timestamp accepts the documented forms" {
  assert_eq(parsed_date("1970-01-01"), 32400)
  assert_eq(parsed_date("2026-09-11"), 1789117200)
  assert_eq(parsed_date("2026-10-20T12:34:56Z"), 1792499696)
  assert_eq(parsed_date(" 2026-09-11 "), 1789117200)
}

///|
test "util: parse_date_to_timestamp rejects malformed dates" {
  for
    text in [
      "", "tomorow", "yesterday", "2026-13-01", "2026-09-11T12:34:56", "2026/09/11",
      "+2x", "2026-09-11T25:00:00Z",
    ] {
    assert_eq(parsed_date(text), -1)
  }
}

///|
test "util: relative dates are measured from now" {
  let before = @lib.current_timestamp()
  let in_two_days = parsed_date("+2d")
  let in_one_week = parsed_date("+1w")
  let in_three_hours = parsed_date("+3h")
  let after = @lib.current_timestamp()
  assert_eq(in_two_days >= before + 172800, true)
  assert_eq(in_two_days <= after + 172800, true)
  assert_eq(in_one_week >= before + 604800, true)
  assert_eq(in_one_week <= after + 604800, true)
  assert_eq(in_three_hours >= before + 10800, true)
  assert_eq(in_three_hours <= after + 10800, true)
}

///|
test "util: tomorrow is 09:00 UTC of the next day" {
  let now = @lib.current_timestamp()
  let tomorrow = parsed_date("tomorrow")
  assert_eq(tomorrow % 86400, 32400)
  assert_eq(tomorrow > now, true)
  assert_eq(tomorrow <= now + 2 * 86400, true)
}

///|
test "util: format_date is the inverse of the bare date form" {
  assert_eq(@lib.format_date(32400), "1970-01-01")
  assert_eq(@lib.format_date(1789117200), "2026-09-11")
  assert_eq(@lib.format_date(1792499696), "2026-10-20")
  assert_eq(@lib.format_date(parsed_date("2026-09-11")), "2026-09-11")
}

///|
/// The ready issues as a comma-separated id list including deferred ones.
fn ready_ids_with_deferred(storage : @lib.BeadsStorage) -> String {
  match @lib.get_ready_issues(storage, include_deferred=true) {
    Ok(issues) => {
      let ids : Array[String] = []
      for issue in issues {
        Array::push(ids, issue.id)
      }
      ids.join(",")
    }
    Err(_) => abort("get_ready_issues returned an error")
  }
}

///|
test "storage: a future defer gate keeps an open issue out of ready" {
  match open_fresh("/tmp/beads_test_defer_gate.db") {
    Ok(storage) => {
      let now = @lib.current_timestamp()
      ignore(
        @lib.insert_issue(
          storage,
          @lib.make_issue(
            "bd-gate1",
            "Gated",
            defer_until=Option::Some(now + 86400),
          ),
        ),
      )
      ignore(
        @lib.insert_issue(
          storage,
          @lib.make_issue(
            "bd-gate2",
            "Gate elapsed",
            defer_until=Option::Some(now - 86400),
          ),
        ),
      )
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-gate3", "Ungated")))

      assert_eq(ready_ids(storage), "bd-gate2,bd-gate3")
      // the gated issue is still open work, and --include-deferred reveals it
      assert_eq(ready_ids_with_deferred(storage).contains("bd-gate1"), true)
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: defer --until and undefer move the status and the gate" {
  match open_fresh("/tmp/beads_test_undefer.db") {
    Ok(storage) => {
      ignore(
        @lib.insert_issue(storage, @lib.make_issue("bd-u1", "Deferred work")),
      )
      let until = @lib.current_timestamp() + 86400
      ignore(@lib.defer_issue(storage, "bd-u1"))
      ignore(
        @lib.update_issue_defer_until(storage, "bd-u1", Option::Some(until)),
      )
      match @lib.get_issue_by_id(storage, "bd-u1") {
        Ok(Option::Some(issue)) => {
          assert_eq(@lib.status_to_string(issue.status), "deferred")
          assert_eq(issue.defer_until, Option::Some(until))
        }
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }

      ignore(@lib.undefer_issue(storage, "bd-u1"))
      match @lib.get_issue_by_id(storage, "bd-u1") {
        Ok(Option::Some(issue)) => {
          assert_eq(@lib.status_to_string(issue.status), "open")
          assert_eq(issue.defer_until, Option::None)
        }
        Ok(Option::None) => assert_eq(true, false)
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: comments carry their author and a real id" {
  match open_fresh("/tmp/beads_test_comments.db") {
    Ok(storage) => {
      ignore(@lib.insert_issue(storage, @lib.make_issue("bd-c1", "Commented")))
      let first = match @lib.add_comment(storage, "bd-c1", "first") {
        Ok(id) => id
        Err(_) => 0
      }
      ignore(@lib.add_comment(storage, "bd-c1", "second", author="alice"))

      match @lib.get_comments(storage, "bd-c1") {
        Ok(comments) => {
          assert_eq(comments.length(), 2)
          assert_eq(comments[0].id, first)
          assert_eq(comments[0].author, "bm")
          assert_eq(comments[0].body, "first")
          assert_eq(comments[1].author, "alice")
          assert_eq(first > 0, true)
        }
        Err(_) => assert_eq(true, false)
      }
      @lib.close(storage)
    }
    Err(_) => assert_eq(true, false)
  }
}
