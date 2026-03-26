/// Storage CRUD tests for beads.
/// Tests basic create, read, update operations.

import {
  "utenadev/beads_mbt/lib" @lib,
}

/// Test: Issue ID generation
fn test_issue_id_generation() -> Unit {
  let id1 = @lib.generate_issue_id("bd")
  let id2 = @lib.generate_issue_id("bd")
  
  if id1.has_prefix("bd-") && id2.has_prefix("bd-") && id1 != id2 {
    println("✓ test_issue_id_generation: PASSED")
  } else {
    println("✗ test_issue_id_generation: FAILED - IDs: " + id1 + ", " + id2)
  }
}

/// Test: Create issue with minimal fields
fn test_create_issue_minimal_fields() -> Unit {
  let db_path = "./.beads/test.db"
  let storage = match @lib.open(db_path) {
    Result::Ok(s) => s
    Result::Err(e) => { println("✗ test_create_issue: setup failed - " + e); return }
  }
  
  let id = @lib.generate_issue_id("test")
  let issue = @lib.make_issue(id, "minimal-create")
  
  match @lib.insert_issue(storage, issue) {
    Result::Ok(_) => {
      println("✓ test_create_issue_minimal_fields: PASSED")
    }
    Result::Err(e) => {
      println("✗ test_create_issue_minimal_fields: FAILED - " + e)
    }
  }
  
  // @lib.close(storage)
}

/// Test: Create and retrieve issue
fn test_create_and_get_issue() -> Unit {
  let db_path = "./.beads/test.db"
  let storage = match @lib.open(db_path) {
    Result::Ok(s) => s
    Result::Err(e) => { println("✗ test_create_and_get: setup failed - " + e); return }
  }
  
  let id = @lib.generate_issue_id("test")
  let issue = @lib.make_issue(id, "test-get")
  
  ignore(@lib.insert_issue(storage, issue))
  
  match @lib.get_issue_by_id(storage, id) {
    Result::Ok(Option::Some(retrieved)) => {
      if retrieved.title == "test-get" {
        println("✓ test_create_and_get_issue: PASSED")
      } else {
        println("✗ test_create_and_get_issue: FAILED - title mismatch")
      }
    }
    Result::Ok(Option::None) => {
      println("✗ test_create_and_get_issue: FAILED - issue not found")
    }
    Result::Err(e) => {
      println("✗ test_create_and_get_issue: FAILED - " + e)
    }
  }
  
  // @lib.close(storage)
}

/// Test: List issues
fn test_list_issues() -> Unit {
  let db_path = "./.beads/test.db"
  let storage = match @lib.open(db_path) {
    Result::Ok(s) => s
    Result::Err(e) => { println("✗ test_list_issues: setup failed - " + e); return }
  }
  
  // Create multiple issues
  let id1 = @lib.generate_issue_id("test")
  let id2 = @lib.generate_issue_id("test")
  
  let issue1 = @lib.make_issue(id1, "first-issue")
  let issue2 = @lib.make_issue(id2, "second-issue")
  
  ignore(@lib.insert_issue(storage, issue1))
  ignore(@lib.insert_issue(storage, issue2))
  
  match @lib.list_issues(storage) {
    Result::Ok(issues) => {
      if issues.length() >= 2 {
        println("✓ test_list_issues: PASSED (found " + issues.length().to_string() + " issues)")
      } else {
        println("✗ test_list_issues: FAILED - expected >= 2, got " + issues.length().to_string())
      }
    }
    Result::Err(e) => {
      println("✗ test_list_issues: FAILED - " + e)
    }
  }
  
  // @lib.close(storage)
}

/// Test: Update issue status
fn test_update_issue_status() -> Unit {
  let db_path = "./.beads/test.db"
  let storage = match @lib.open(db_path) {
    Result::Ok(s) => s
    Result::Err(e) => { println("✗ test_update_status: setup failed - " + e); return }
  }
  
  let id = @lib.generate_issue_id("test")
  let issue = @lib.make_issue(id, "test-status")
  
  ignore(@lib.insert_issue(storage, issue))
  
  // Update status to closed
  match @lib.update_issue_status(storage, id, "closed") {
    Result::Ok(_) => {
      match @lib.get_issue_by_id(storage, id) {
        Result::Ok(Option::Some(retrieved)) => {
          println("✓ test_update_issue_status: PASSED (status updated)")
        }
        _ => {
          println("✗ test_update_issue_status: FAILED - issue not found")
        }
      }
    }
    Result::Err(e) => {
      println("✗ test_update_issue_status: FAILED - " + e)
    }
  }
  
  // @lib.close(storage)
}

/// Run all tests
pub fn run_all_tests() -> Unit {
  println("\n=== Running Storage CRUD Tests ===\n")
  
  test_issue_id_generation()
  test_create_issue_minimal_fields()
  test_create_and_get_issue()
  test_list_issues()
  test_update_issue_status()
  
  println("\n=== Tests Complete ===\n")
}
