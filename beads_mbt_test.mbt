///|
/// Blackbox tests run against the package's public API.
/// Prefer high-level behaviors over implementation details.
/// Run `moon test` to execute and `moon test --update` to refresh snapshots.
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
  match @lib.open("/tmp/test_schema.db") {
    Ok(storage) => @lib.close(storage)
    Err(_) => assert_eq(true, false)
  }
}

///|
test "storage: insert and get issue" {
  let r = @lib.open("/tmp/beads_test_insert.db")
  if r.is_ok() {
    let storage = r.unwrap()
    let issue = @lib.make_issue("bd-test123", "Test issue")
    let insert_result = @lib.insert_issue(
      storage,
      @lib.make_issue("bd-test123", "Test issue"),
    )
    if insert_result.is_ok() {
      let get_result = @lib.get_issue_by_id(storage, "bd-test123")
      if get_result.is_ok() {
        let issue = get_result.unwrap()
        if issue.is_some() {
          let issue = issue.unwrap()
          assert_eq(issue.id, "bd-test123")
          assert_eq(issue.title, "Test issue")
          assert_eq(@lib.issue_type_to_string(issue.type_), "other")
          assert_eq(issue.priority, 2)
          assert_eq(@lib.status_to_string(issue.status), "open")
          assert_eq(issue.is_ephemeral, false)
        } else {
          assert_eq(true, false)
        }
      } else {
        assert_eq(true, false)
      }
    } else {
      assert_eq(true, false)
    }
    @lib.close(storage)
  } else {
    assert_eq(true, false)
  }
}

///|
test "storage: list_issues returns all issues" {
  let r = @lib.open("/tmp/beads_test_list.db")
  if r.is_ok() {
    let storage = r.unwrap()
    ignore(@lib.insert_issue(storage, @lib.make_issue("bd-1", "Issue 1")))
    ignore(@lib.insert_issue(storage, @lib.make_issue("bd-2", "Issue 2")))
    ignore(@lib.insert_issue(storage, @lib.make_issue("bd-3", "Issue 3")))

    let list_result = @lib.list_issues(storage)
    if list_result.is_ok() {
      let issues = list_result.unwrap()
      assert_eq(issues.length(), 3)
      assert_eq(issues[0].title, "Issue 3")
      assert_eq(issues[1].title, "Issue 2")
      assert_eq(issues[2].title, "Issue 1")
    } else {
      assert_eq(true, false)
    }
    @lib.close(storage)
  } else {
    assert_eq(true, false)
  }
}

///|
test "storage: update_issue_status" {
  let r = @lib.open("/tmp/beads_test_status.db")
  if r.is_ok() {
    let storage = r.unwrap()
    ignore(
      @lib.insert_issue(storage, @lib.make_issue("bd-status1", "Status test")),
    )
    let u = @lib.update_issue_status(storage, "bd-status1", "closed")
    if u.is_ok() {
      let get_result = @lib.get_issue_by_id(storage, "bd-status1")
      if get_result.is_ok() {
        let issue = get_result.unwrap()
        if issue.is_some() {
          let issue = issue.unwrap()
          assert_eq(@lib.status_to_string(issue.status), "closed")
        } else {
          assert_eq(true, false)
        }
      } else {
        assert_eq(true, false)
      }
    } else {
      assert_eq(true, false)
    }
    @lib.close(storage)
  } else {
    assert_eq(true, false)
  }
}

///|
test "storage: get_ready_issues" {
  let r = @lib.open("/tmp/beads_test_ready.db")
  if r.is_ok() {
    let storage = r.unwrap()
    ignore(
      @lib.insert_issue(storage, @lib.make_issue("bd-ready1", "Ready issue")),
    )
    ignore(
      @lib.insert_issue(storage, @lib.make_issue("bd-ready2", "Closed issue")),
    )
    ignore(@lib.update_issue_status(storage, "bd-ready2", "closed"))

    let ready_result = @lib.get_ready_issues(storage)
    if ready_result.is_ok() {
      let issues = ready_result.unwrap()
      assert_eq(issues.length(), 1)
      assert_eq(issues[0].id, "bd-ready1")
      assert_eq(@lib.status_to_string(issues[0].status), "open")
    } else {
      assert_eq(true, false)
    }
    @lib.close(storage)
  } else {
    assert_eq(true, false)
  }
}

///|
test "storage: update_issue_title" {
  let r = @lib.open("/tmp/beads_test_title.db")
  if r.is_ok() {
    let storage = r.unwrap()
    ignore(
      @lib.insert_issue(storage, @lib.make_issue("bd-title1", "Old title")),
    )
    let u = @lib.update_issue_title(storage, "bd-title1", "New title")
    if u.is_ok() {
      let get_result = @lib.get_issue_by_id(storage, "bd-title1")
      if get_result.is_ok() {
        let issue = get_result.unwrap()
        if issue.is_some() {
          let issue = issue.unwrap()
          assert_eq(issue.title, "New title")
        } else {
          assert_eq(true, false)
        }
      } else {
        assert_eq(true, false)
      }
    } else {
      assert_eq(true, false)
    }
    @lib.close(storage)
  } else {
    assert_eq(true, false)
  }
}

///|
test "storage: update_issue_priority" {
  let r = @lib.open("/tmp/beads_test_priority.db")
  if r.is_ok() {
    let storage = r.unwrap()
    ignore(
      @lib.insert_issue(
        storage,
        @lib.make_issue("bd-priority1", "Priority test"),
      ),
    )
    let u = @lib.update_issue_priority(storage, "bd-priority1", 0)
    if u.is_ok() {
      let get_result = @lib.get_issue_by_id(storage, "bd-priority1")
      if get_result.is_ok() {
        let issue = get_result.unwrap()
        if issue.is_some() {
          let issue = issue.unwrap()
          assert_eq(issue.priority, 0)
        } else {
          assert_eq(true, false)
        }
      } else {
        assert_eq(true, false)
      }
    } else {
      assert_eq(true, false)
    }
    @lib.close(storage)
  } else {
    assert_eq(true, false)
  }
}

///|
test "storage: defer_issue" {
  let r = @lib.open("/tmp/beads_test_defer.db")
  if r.is_ok() {
    let storage = r.unwrap()
    ignore(
      @lib.insert_issue(storage, @lib.make_issue("bd-defer1", "Defer test")),
    )
    let d = @lib.defer_issue(storage, "bd-defer1")
    if d.is_ok() {
      let get_result = @lib.get_issue_by_id(storage, "bd-defer1")
      if get_result.is_ok() {
        let issue = get_result.unwrap()
        if issue.is_some() {
          let issue = issue.unwrap()
          assert_eq(@lib.status_to_string(issue.status), "deferred")
        } else {
          assert_eq(true, false)
        }
      } else {
        assert_eq(true, false)
      }
    } else {
      assert_eq(true, false)
    }
    @lib.close(storage)
  } else {
    assert_eq(true, false)
  }
}

///|
test "storage: add_dependency" {
  let r = @lib.open("/tmp/beads_test_dep.db")
  if r.is_ok() {
    let storage = r.unwrap()
    ignore(@lib.insert_issue(storage, @lib.make_issue("bd-dep1", "Dep 1")))
    ignore(@lib.insert_issue(storage, @lib.make_issue("bd-dep2", "Dep 2")))
    let dep_result = @lib.add_dependency(storage, "bd-dep1", "bd-dep2")
    if dep_result.is_err() {
      assert_eq(true, false)
    }
    @lib.close(storage)
  } else {
    assert_eq(true, false)
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
test "util: current_timestamp returns non-negative" {
  let ts = @lib.current_timestamp()
  assert_eq(ts >= 0, true)
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
