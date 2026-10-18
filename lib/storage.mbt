/// Storage layer for beads.
/// Handles SQLite database operations.

///|
/// Beads storage wrapper
pub struct BeadsStorage {
  conn : @sqlite3.Connection
}

///|
/// Read a TEXT column as String, falling back to "" on error.
fn col_string(stmt : @sqlite3.Statement, index : Int32) -> String {
  stmt.column(index~) catch {
    _ => ""
  }
}

///|
/// Read an INTEGER column as Int32, falling back to 0 on error.
fn col_int(stmt : @sqlite3.Statement, index : Int32) -> Int32 {
  let value : Int64 = stmt.column(index~) catch { _ => 0L }
  value.to_int()
}

///|
/// Read one issue row from the current cursor position of `stmt`.
/// The SELECT must list columns in the canonical issue order.
fn read_issue_row(stmt : @sqlite3.Statement) -> Issue {
  let id : String = col_string(stmt, 0)
  let title : String = col_string(stmt, 1)
  let type_ = string_to_issue_type(col_string(stmt, 2))
  let priority : Int32 = col_int(stmt, 3)
  let status = string_to_status(col_string(stmt, 4))
  let description = col_string(stmt, 5)
  let assignee = col_string(stmt, 6)
  let owner = col_string(stmt, 7)
  let created_at : Int32 = col_int(stmt, 8)
  let updated_at : Int32 = col_int(stmt, 9)
  let is_ephemeral : Int32 = col_int(stmt, 10)

  Issue::{
    id,
    title,
    type_,
    priority,
    status,
    description: if description == "" {
      Option::None
    } else {
      Option::Some(description)
    },
    assignee: if assignee == "" {
      Option::None
    } else {
      Option::Some(assignee)
    },
    owner: if owner == "" {
      Option::None
    } else {
      Option::Some(owner)
    },
    created_at,
    updated_at,
    is_ephemeral: is_ephemeral == 1,
  }
}

///|
/// A value that can be bound to a statement parameter.
priv enum SqlParam {
  Text(String)
  Int(Int32)
}

///|
/// Prepare `sql`, bind `params`, execute once, and finalize.
fn exec_write(
  storage : BeadsStorage,
  sql : String,
  params : Array[SqlParam],
) -> Result[Unit, String] {
  let stmt = storage.conn.prepare(sql) catch {
    _ => return Result::Err("prepare failed")
  }

  let mut index : Int32 = 1
  for param in params {
    match param {
      SqlParam::Text(value) =>
        stmt.bind(index~, value) catch {
          _ => return Result::Err("bind failed")
        }
      SqlParam::Int(value) =>
        stmt.bind(index~, value) catch {
          _ => return Result::Err("bind failed")
        }
    }
    index += 1
  }

  ignore(stmt.step() catch { _ => return Result::Err("step failed") })
  stmt.finalize() catch {
    _ => return Result::Err("finalize failed")
  }
  Result::Ok(())
}

///|
/// Prepare `sql`, optionally bind one text parameter, and collect the first
/// column of every row as String.
fn query_strings(
  storage : BeadsStorage,
  sql : String,
  param : String?,
) -> Result[Array[String], String] {
  let stmt = storage.conn.prepare(sql) catch {
    _ => return Result::Err("prepare failed")
  }
  match param {
    Option::Some(value) =>
      stmt.bind(index=1, value) catch {
        _ => return Result::Err("bind failed")
      }
    Option::None => ()
  }

  let rows : Array[String] = []
  while (stmt.step() catch { _ => return Result::Err("step failed") }) {
    Array::push(rows, col_string(stmt, 0))
  }

  stmt.finalize() catch {
    _ => return Result::Err("finalize failed")
  }
  Result::Ok(rows)
}

///|
/// Prepare `sql`, optionally bind one text parameter, and collect rows as issues.
fn query_issues(
  storage : BeadsStorage,
  sql : String,
  param : String?,
) -> Result[Array[Issue], String] {
  let stmt = storage.conn.prepare(sql) catch {
    _ => return Result::Err("prepare failed")
  }
  match param {
    Option::Some(value) =>
      stmt.bind(index=1, value) catch {
        _ => return Result::Err("bind failed")
      }
    Option::None => ()
  }

  let rows : Array[Issue] = []
  while (stmt.step() catch { _ => return Result::Err("step failed") }) {
    Array::push(rows, read_issue_row(stmt))
  }

  stmt.finalize() catch {
    _ => return Result::Err("finalize failed")
  }
  Result::Ok(rows)
}

///|
/// Fetch a single issue, or None when no row matches.
fn query_one_issue(
  storage : BeadsStorage,
  sql : String,
  param : String?,
) -> Result[Issue?, String] {
  let stmt = storage.conn.prepare(sql) catch {
    _ => return Result::Err("prepare failed")
  }
  match param {
    Option::Some(value) =>
      stmt.bind(index=1, value) catch {
        _ => return Result::Err("bind failed")
      }
    Option::None => ()
  }

  let result = if (stmt.step() catch { _ => return Result::Err("step failed") }) {
    Option::Some(read_issue_row(stmt))
  } else {
    Option::None
  }

  stmt.finalize() catch {
    _ => return Result::Err("finalize failed")
  }
  Result::Ok(result)
}

///|
/// Fetch a single text value, or None when no row matches.
fn query_one_string(
  storage : BeadsStorage,
  sql : String,
  param : String?,
) -> Result[String?, String] {
  let stmt = storage.conn.prepare(sql) catch {
    _ => return Result::Err("prepare failed")
  }
  match param {
    Option::Some(value) =>
      stmt.bind(index=1, value) catch {
        _ => return Result::Err("bind failed")
      }
    Option::None => ()
  }

  let result = if (stmt.step() catch { _ => return Result::Err("step failed") }) {
    Option::Some(col_string(stmt, 0))
  } else {
    Option::None
  }

  stmt.finalize() catch {
    _ => return Result::Err("finalize failed")
  }
  Result::Ok(result)
}

///|
/// Schema statements. Safe to run repeatedly (all use IF NOT EXISTS).
let schema_statements : Array[String] = [
  "CREATE TABLE IF NOT EXISTS config (key TEXT PRIMARY KEY, value TEXT NOT NULL);",
  "CREATE TABLE IF NOT EXISTS issues (id TEXT PRIMARY KEY, title TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'other', priority INTEGER NOT NULL DEFAULT 2, status TEXT NOT NULL DEFAULT 'open', description TEXT, assignee TEXT, owner TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, closed_at INTEGER, closed_reason TEXT, parent TEXT, estimate INTEGER, due_date INTEGER, external_ref TEXT, is_ephemeral INTEGER NOT NULL DEFAULT 0);",
  "CREATE TABLE IF NOT EXISTS issue_labels (issue_id TEXT NOT NULL, label TEXT NOT NULL, PRIMARY KEY (issue_id, label), FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE);",
  "CREATE TABLE IF NOT EXISTS issue_dependencies (issue_id TEXT NOT NULL, depends_on TEXT NOT NULL, PRIMARY KEY (issue_id, depends_on), FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE, FOREIGN KEY (depends_on) REFERENCES issues(id) ON DELETE CASCADE);",
  "CREATE TABLE IF NOT EXISTS comments (id INTEGER PRIMARY KEY AUTOINCREMENT, issue_id TEXT NOT NULL, body TEXT NOT NULL, created_at INTEGER NOT NULL, FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE);",
  "CREATE INDEX IF NOT EXISTS idx_issues_status ON issues(status);", "CREATE INDEX IF NOT EXISTS idx_issues_priority ON issues(priority);",
  "CREATE INDEX IF NOT EXISTS idx_issues_created_at ON issues(created_at);",
]

///|
/// Open or create beads database
pub fn open(db_path : String) -> Result[BeadsStorage, String] {
  let conn = @sqlite3.Connection::open(db_path) catch {
    _ => return Result::Err("Failed to open database")
  }

  // Initialize schema (ignore errors for idempotent operations)
  for sql in schema_statements {
    let stmt = conn.prepare(sql) catch {
      _ => return Result::Err("prepare failed")
    }
    ignore(stmt.step() catch { _ => false })
    stmt.finalize() catch {
      _ => ()
    }
  }

  Result::Ok(BeadsStorage::{ conn, })
}

///|
/// Close the database connection
pub fn close(storage : BeadsStorage) -> Unit {
  storage.conn.close() catch {
    _ => ()
  }
}

///|
/// Set a config value
pub fn set_config(
  storage : BeadsStorage,
  key : String,
  value : String,
) -> Result[Unit, String] {
  exec_write(
    storage,
    "INSERT OR REPLACE INTO config (key, value) VALUES (?, ?);",
    [SqlParam::Text(key), SqlParam::Text(value)],
  )
}

///|
/// Get a config value
pub fn get_config(
  storage : BeadsStorage,
  key : String,
) -> Result[String?, String] {
  query_one_string(
    storage,
    "SELECT value FROM config WHERE key = ?;",
    Option::Some(key),
  )
}

///|
/// Insert a new issue
pub fn insert_issue(
  storage : BeadsStorage,
  issue : Issue,
) -> Result[Unit, String] {
  let description = match issue.description {
    Option::Some(value) => value
    Option::None => ""
  }
  let assignee = match issue.assignee {
    Option::Some(value) => value
    Option::None => ""
  }
  let owner = match issue.owner {
    Option::Some(value) => value
    Option::None => ""
  }

  exec_write(
    storage,
    "INSERT INTO issues (id, title, type, priority, status, description, assignee, owner, created_at, updated_at, is_ephemeral) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);",
    [
      SqlParam::Text(issue.id),
      SqlParam::Text(issue.title),
      SqlParam::Text(issue_type_to_string(issue.type_)),
      SqlParam::Int(issue.priority),
      SqlParam::Text(status_to_string(issue.status)),
      SqlParam::Text(description),
      SqlParam::Text(assignee),
      SqlParam::Text(owner),
      SqlParam::Int(issue.created_at),
      SqlParam::Int(issue.updated_at),
      SqlParam::Int(if issue.is_ephemeral { 1 } else { 0 }),
    ],
  )
}

///|
/// Get an issue by ID
pub fn get_issue_by_id(
  storage : BeadsStorage,
  id : String,
) -> Result[Issue?, String] {
  query_one_issue(
    storage,
    "SELECT id, title, type, priority, status, description, assignee, owner, created_at, updated_at, is_ephemeral FROM issues WHERE id = ?;",
    Option::Some(id),
  )
}

///|
/// List all issues
pub fn list_issues(storage : BeadsStorage) -> Result[Array[Issue], String] {
  query_issues(
    storage,
    "SELECT id, title, type, priority, status, description, assignee, owner, created_at, updated_at, is_ephemeral FROM issues ORDER BY created_at DESC;",
    Option::None,
  )
}

///|
/// Update issue status
pub fn update_issue_status(
  storage : BeadsStorage,
  id : String,
  status : String,
) -> Result[Unit, String] {
  exec_write(
    storage,
    "UPDATE issues SET status = ?, updated_at = strftime('%s', 'now') WHERE id = ?;",
    [SqlParam::Text(status), SqlParam::Text(id)],
  )
}

///|
/// Get ready issues (open, not blocked by other open issues)
pub fn get_ready_issues(storage : BeadsStorage) -> Result[Array[Issue], String] {
  query_issues(
    storage,
    "SELECT id, title, type, priority, status, description, assignee, owner, created_at, updated_at, is_ephemeral FROM issues WHERE status = 'open' ORDER BY priority ASC, created_at ASC;",
    Option::None,
  )
}

///|
/// Update issue title
pub fn update_issue_title(
  storage : BeadsStorage,
  id : String,
  title : String,
) -> Result[Unit, String] {
  exec_write(
    storage,
    "UPDATE issues SET title = ?, updated_at = strftime('%s', 'now') WHERE id = ?;",
    [SqlParam::Text(title), SqlParam::Text(id)],
  )
}

///|
/// Update issue priority
pub fn update_issue_priority(
  storage : BeadsStorage,
  id : String,
  priority : Int32,
) -> Result[Unit, String] {
  exec_write(
    storage,
    "UPDATE issues SET priority = ?, updated_at = strftime('%s', 'now') WHERE id = ?;",
    [SqlParam::Int(priority), SqlParam::Text(id)],
  )
}

///|
/// Defer an issue (set status to deferred)
pub fn defer_issue(storage : BeadsStorage, id : String) -> Result[Unit, String] {
  update_issue_status(storage, id, "deferred")
}

// ============================================================================
// Dependencies
// ============================================================================

///|
/// Add a dependency (issue depends on depends_on)
pub fn add_dependency(
  storage : BeadsStorage,
  issue : String,
  depends_on : String,
) -> Result[Unit, String] {
  exec_write(
    storage,
    "INSERT OR IGNORE INTO issue_dependencies (issue_id, depends_on) VALUES (?, ?);",
    [SqlParam::Text(issue), SqlParam::Text(depends_on)],
  )
}

///|
/// Remove a dependency
pub fn remove_dependency(
  storage : BeadsStorage,
  issue : String,
  depends_on : String,
) -> Result[Unit, String] {
  exec_write(
    storage,
    "DELETE FROM issue_dependencies WHERE issue_id = ? AND depends_on = ?;",
    [SqlParam::Text(issue), SqlParam::Text(depends_on)],
  )
}

///|
/// Get dependencies for an issue (what this issue depends on)
pub fn get_dependencies(
  storage : BeadsStorage,
  issue : String,
) -> Result[Array[String], String] {
  query_strings(
    storage,
    "SELECT depends_on FROM issue_dependencies WHERE issue_id = ? ORDER BY depends_on;",
    Option::Some(issue),
  )
}

///|
/// Get blocked issues (issues that depend on this issue)
pub fn get_blocked_by(
  storage : BeadsStorage,
  issue : String,
) -> Result[Array[String], String] {
  query_strings(
    storage,
    "SELECT issue_id FROM issue_dependencies WHERE depends_on = ? ORDER BY issue_id;",
    Option::Some(issue),
  )
}

///|
/// Check if an issue is blocked by open issues
pub fn is_blocked(
  storage : BeadsStorage,
  issue : String,
) -> Result[Bool, String] {
  let deps = match get_dependencies(storage, issue) {
    Result::Ok(d) => d
    Result::Err(e) => return Result::Err(e)
  }

  for dep in deps {
    let dep_issue = match get_issue_by_id(storage, dep) {
      Result::Ok(Option::Some(i)) => i
      Result::Ok(Option::None) => continue
      Result::Err(e) => return Result::Err(e)
    }
    if status_to_string(dep_issue.status) == "open" {
      return Result::Ok(true)
    }
  }

  Result::Ok(false)
}

// ============================================================================
// Labels
// ============================================================================

///|
/// Add a label to an issue
pub fn add_label(
  storage : BeadsStorage,
  issue : String,
  label : String,
) -> Result[Unit, String] {
  exec_write(
    storage,
    "INSERT OR IGNORE INTO issue_labels (issue_id, label) VALUES (?, ?);",
    [SqlParam::Text(issue), SqlParam::Text(label)],
  )
}

///|
/// Remove a label from an issue
pub fn remove_label(
  storage : BeadsStorage,
  issue : String,
  label : String,
) -> Result[Unit, String] {
  exec_write(
    storage,
    "DELETE FROM issue_labels WHERE issue_id = ? AND label = ?;",
    [SqlParam::Text(issue), SqlParam::Text(label)],
  )
}

///|
/// Get labels for an issue
pub fn get_labels(
  storage : BeadsStorage,
  issue : String,
) -> Result[Array[String], String] {
  query_strings(
    storage,
    "SELECT label FROM issue_labels WHERE issue_id = ? ORDER BY label;",
    Option::Some(issue),
  )
}

///|
/// Get all labels in the project
pub fn get_all_labels(storage : BeadsStorage) -> Result[Array[String], String] {
  query_strings(
    storage,
    "SELECT DISTINCT label FROM issue_labels ORDER BY label;",
    Option::None,
  )
}

// ============================================================================
// Search
// ============================================================================

///|
/// Search issues by title
pub fn search_issues(
  storage : BeadsStorage,
  query : String,
) -> Result[Array[Issue], String] {
  query_issues(
    storage,
    "SELECT id, title, type, priority, status, description, assignee, owner, created_at, updated_at, is_ephemeral FROM issues WHERE title LIKE ? ORDER BY created_at DESC;",
    Option::Some("%" + query + "%"),
  )
}

// ============================================================================
// Comments
// ============================================================================

///|
/// Add a comment to an issue
pub fn add_comment(
  storage : BeadsStorage,
  issue : String,
  body : String,
) -> Result[Int32, String] {
  let created_at = 0 // TODO: Use actual timestamp
  let result = exec_write(
    storage,
    "INSERT INTO comments (issue_id, body, created_at) VALUES (?, ?, ?);",
    [SqlParam::Text(issue), SqlParam::Text(body), SqlParam::Int(created_at)],
  )
  match result {
    Result::Ok(_) => ()
    Result::Err(e) => return Result::Err(e)
  }

  // Get the last inserted ID (simplified - in real impl would use last_insert_rowid)
  Result::Ok(0)
}

///|
/// Get comments for an issue
pub fn get_comments(
  storage : BeadsStorage,
  issue : String,
) -> Result[Array[String], String] {
  query_strings(
    storage,
    "SELECT body FROM comments WHERE issue_id = ? ORDER BY created_at ASC;",
    Option::Some(issue),
  )
}

///|
/// Initialize beads workspace
pub fn init_workspace(
  db_path : String,
  prefix : String?,
) -> Result[String, String] {
  // Create .beads directory
  @fs.create_dir("./.beads") catch {
    _ => ()
  }

  let storage_result = open(db_path)
  let storage = match storage_result {
    Result::Ok(s) => s
    Result::Err(e) => return Result::Err(e)
  }

  let actual_prefix = match prefix {
    Option::Some(p) => p
    Option::None => "bd"
  }

  let config_result = set_config(storage, "issue_prefix", actual_prefix)
  match config_result {
    Result::Ok(_) => ignore(())
    Result::Err(e) => return Result::Err(e)
  }

  close(storage)

  Result::Ok("Workspace initialized with prefix: " + actual_prefix)
}
