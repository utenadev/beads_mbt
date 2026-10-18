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
/// Read one dependency row from the current cursor position of `stmt`.
/// The SELECT must list columns as `issue_id, depends_on, type`.
fn read_dependency_row(stmt : @sqlite3.Statement) -> Dependency {
  Dependency::{
    issue_id: col_string(stmt, 0),
    depends_on: col_string(stmt, 1),
    type_: col_string(stmt, 2),
  }
}

///|
/// Prepare `sql`, optionally bind one text parameter, and collect rows as
/// dependencies.
fn query_dependencies(
  storage : BeadsStorage,
  sql : String,
  param : String?,
) -> Result[Array[Dependency], String] {
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

  let rows : Array[Dependency] = []
  while (stmt.step() catch { _ => return Result::Err("step failed") }) {
    Array::push(rows, read_dependency_row(stmt))
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
  "CREATE TABLE IF NOT EXISTS issue_dependencies (issue_id TEXT NOT NULL, depends_on TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'blocks', PRIMARY KEY (issue_id, depends_on, type), FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE, FOREIGN KEY (depends_on) REFERENCES issues(id) ON DELETE CASCADE);",
  "CREATE TABLE IF NOT EXISTS comments (id INTEGER PRIMARY KEY AUTOINCREMENT, issue_id TEXT NOT NULL, body TEXT NOT NULL, created_at INTEGER NOT NULL, FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE);",
  "CREATE INDEX IF NOT EXISTS idx_issues_status ON issues(status);", "CREATE INDEX IF NOT EXISTS idx_issues_priority ON issues(priority);",
  "CREATE INDEX IF NOT EXISTS idx_issues_created_at ON issues(created_at);",
]

///|
/// Schema version recorded in `PRAGMA user_version`.
/// 1 - typed dependencies: `issue_dependencies.type` is part of the key.
let schema_version : Int32 = 1

///|
/// Execute a statement that takes no parameters.
fn exec_sql(conn : @sqlite3.Connection, sql : String) -> Result[Unit, String] {
  let stmt = conn.prepare(sql) catch {
    _ => return Result::Err("prepare failed")
  }
  ignore(stmt.step() catch { _ => return Result::Err("step failed") })
  stmt.finalize() catch {
    _ => return Result::Err("finalize failed")
  }
  Result::Ok(())
}

///|
/// Whether `table` has a column named `column`.
fn column_exists(
  conn : @sqlite3.Connection,
  table : String,
  column : String,
) -> Result[Bool, String] {
  let stmt = conn.prepare("PRAGMA table_info(" + table + ");") catch {
    _ => return Result::Err("prepare failed")
  }
  let mut found = false
  while (stmt.step() catch { _ => return Result::Err("step failed") }) {
    if col_string(stmt, 1) == column {
      found = true
    }
  }
  stmt.finalize() catch {
    _ => return Result::Err("finalize failed")
  }
  Result::Ok(found)
}

///|
/// Read `PRAGMA user_version`, which is 0 for databases written before the
/// schema was versioned.
fn user_version(conn : @sqlite3.Connection) -> Result[Int32, String] {
  let stmt = conn.prepare("PRAGMA user_version;") catch {
    _ => return Result::Err("prepare failed")
  }
  let version = if (stmt.step() catch {
      _ => return Result::Err("step failed")
    }) {
    col_int(stmt, 0)
  } else {
    0
  }
  stmt.finalize() catch {
    _ => return Result::Err("finalize failed")
  }
  Result::Ok(version)
}

///|
/// Bring an existing database up to `schema_version`.
/// Databases written before typed dependencies carry an `issue_dependencies`
/// table without `type`. Rebuilding the table adds the column, makes it part
/// of the primary key, and keeps existing rows as `blocks` edges. The DDL is
/// spelled out instead of reusing `schema_statements` so that a later change
/// to the current schema cannot rewrite this migration.
fn migrate_schema(conn : @sqlite3.Connection) -> Result[Unit, String] {
  let version = match user_version(conn) {
    Result::Ok(v) => v
    Result::Err(e) => return Result::Err(e)
  }
  if version >= schema_version {
    return Result::Ok(())
  }

  let typed = match column_exists(conn, "issue_dependencies", "type") {
    Result::Ok(v) => v
    Result::Err(e) => return Result::Err(e)
  }

  if !typed {
    let steps : Array[String] = [
      "ALTER TABLE issue_dependencies RENAME TO issue_dependencies_legacy;", "CREATE TABLE issue_dependencies (issue_id TEXT NOT NULL, depends_on TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'blocks', PRIMARY KEY (issue_id, depends_on, type), FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE, FOREIGN KEY (depends_on) REFERENCES issues(id) ON DELETE CASCADE);",
      "INSERT OR IGNORE INTO issue_dependencies (issue_id, depends_on, type) SELECT issue_id, depends_on, 'blocks' FROM issue_dependencies_legacy;",
      "DROP TABLE issue_dependencies_legacy;",
    ]
    for sql in steps {
      match exec_sql(conn, sql) {
        Result::Ok(_) => ()
        Result::Err(e) => return Result::Err(e)
      }
    }
  }

  exec_sql(conn, "PRAGMA user_version = " + schema_version.to_string() + ";")
}

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

  match migrate_schema(conn) {
    Result::Ok(_) => ()
    Result::Err(e) => return Result::Err(e)
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
/// Get ready issues: open issues that no blocking dependency holds back.
/// Ordered like beads_rust (priority, then newest, then id).
pub fn get_ready_issues(storage : BeadsStorage) -> Result[Array[Issue], String] {
  let open_issues = match
    query_issues(
      storage,
      "SELECT id, title, type, priority, status, description, assignee, owner, created_at, updated_at, is_ephemeral FROM issues WHERE status = 'open' ORDER BY priority ASC, created_at DESC, id ASC;",
      Option::None,
    ) {
    Result::Ok(issues) => issues
    Result::Err(e) => return Result::Err(e)
  }

  let blocked = match compute_blocked_set(storage) {
    Result::Ok(set) => set
    Result::Err(e) => return Result::Err(e)
  }

  let ready : Array[Issue] = []
  for issue in open_issues {
    match blocked.get(issue.id) {
      Some(_) => ()
      None => Array::push(ready, issue)
    }
  }
  Result::Ok(ready)
}

///|
/// Ids of every currently blocked issue, as a lookup set.
/// A blocking edge (`blocks`, `conditional-blocks`, `waits-for`) holds the
/// source issue back while its target is not closed; an unknown target keeps
/// blocking, like beads_rust. A child then inherits a blocked parent through
/// `parent-child` edges, which is why the propagation below repeats until it
/// reaches a fixed point.
fn compute_blocked_set(
  storage : BeadsStorage,
) -> Result[Map[String, Bool], String] {
  let issues = match list_issues(storage) {
    Result::Ok(issues) => issues
    Result::Err(e) => return Result::Err(e)
  }
  let statuses : Map[String, String] = Map([])
  for issue in issues {
    statuses.set(issue.id, status_to_string(issue.status))
  }

  let edges = match get_all_dependencies(storage) {
    Result::Ok(edges) => edges
    Result::Err(e) => return Result::Err(e)
  }

  let blocked : Map[String, Bool] = Map([])
  for edge in edges {
    if is_blocking_dependency_type(edge.type_) {
      let target_open = match statuses.get(edge.depends_on) {
        Some(status) => status != "closed"
        None => true
      }
      if target_open {
        blocked.set(edge.issue_id, true)
      }
    }
  }

  let mut changed = true
  while changed {
    changed = false
    for edge in edges {
      if edge.type_ == "parent-child" {
        match blocked.get(edge.depends_on) {
          Some(_) =>
            match blocked.get(edge.issue_id) {
              Some(_) => ()
              None => {
                blocked.set(edge.issue_id, true)
                changed = true
              }
            }
          None => ()
        }
      }
    }
  }

  Result::Ok(blocked)
}

///|
/// List blocked issues, most recently created first.
/// Closed issues are left out: they are done, not waiting.
pub fn get_blocked_issues(
  storage : BeadsStorage,
) -> Result[Array[Issue], String] {
  let issues = match list_issues(storage) {
    Result::Ok(issues) => issues
    Result::Err(e) => return Result::Err(e)
  }
  let blocked = match compute_blocked_set(storage) {
    Result::Ok(set) => set
    Result::Err(e) => return Result::Err(e)
  }

  let result : Array[Issue] = []
  for issue in issues {
    if status_to_string(issue.status) != "closed" {
      match blocked.get(issue.id) {
        Some(_) => Array::push(result, issue)
        None => ()
      }
    }
  }
  Result::Ok(result)
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
/// Add a dependency (issue depends on depends_on with the given type).
/// Adding the same typed edge twice is a no-op.
pub fn add_dependency(
  storage : BeadsStorage,
  issue : String,
  depends_on : String,
  dep_type : DependencyType,
) -> Result[Unit, String] {
  exec_write(
    storage,
    "INSERT OR IGNORE INTO issue_dependencies (issue_id, depends_on, type) VALUES (?, ?, ?);",
    [
      SqlParam::Text(issue),
      SqlParam::Text(depends_on),
      SqlParam::Text(dep_type),
    ],
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
) -> Result[Array[Dependency], String] {
  query_dependencies(
    storage,
    "SELECT issue_id, depends_on, type FROM issue_dependencies WHERE issue_id = ? ORDER BY depends_on, type;",
    Option::Some(issue),
  )
}

///|
/// Get every dependency edge in the database.
fn get_all_dependencies(
  storage : BeadsStorage,
) -> Result[Array[Dependency], String] {
  query_dependencies(
    storage,
    "SELECT issue_id, depends_on, type FROM issue_dependencies ORDER BY issue_id, depends_on, type;",
    Option::None,
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
/// Check whether an issue is blocked by open issues.
/// See `compute_blocked_set` for the exact rules.
pub fn is_blocked(
  storage : BeadsStorage,
  issue : String,
) -> Result[Bool, String] {
  let blocked = match compute_blocked_set(storage) {
    Result::Ok(set) => set
    Result::Err(e) => return Result::Err(e)
  }
  match blocked.get(issue) {
    Some(_) => Result::Ok(true)
    None => Result::Ok(false)
  }
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
/// Maximum number of search results, mirroring beads_rust's default.
let search_limit : Int32 = 50

///|
/// Search issues by id, title, or description, ignoring ASCII case.
/// Rows are matched in MoonBit rather than with SQL `LIKE` so the field set
/// stays explicit, and a local tracker is small enough that scanning the
/// ordered table is cheap. Ordering matches beads_rust: priority, then newest,
/// then id. beads_rust also folds non-ASCII case; MoonBit's `to_lower` only
/// folds ASCII, so accented text has to match verbatim.
pub fn search_issues(
  storage : BeadsStorage,
  query : String,
) -> Result[Array[Issue], String] {
  let issues = match
    query_issues(
      storage,
      "SELECT id, title, type, priority, status, description, assignee, owner, created_at, updated_at, is_ephemeral FROM issues ORDER BY priority ASC, created_at DESC, id ASC;",
      Option::None,
    ) {
    Result::Ok(issues) => issues
    Result::Err(e) => return Result::Err(e)
  }

  let needle = query.to_lower()
  let matches : Array[Issue] = []
  let mut index = 0
  while index < issues.length() && matches.length() < search_limit {
    let issue = issues[index]
    if issue_matches(issue, needle) {
      Array::push(matches, issue)
    }
    index += 1
  }
  Result::Ok(matches)
}

///|
/// Whether an issue's id, title, or description contains `needle`.
fn issue_matches(issue : Issue, needle : String) -> Bool {
  if contains_ignoring_case(issue.id, needle) ||
    contains_ignoring_case(issue.title, needle) {
    return true
  }
  match issue.description {
    Option::Some(description) => contains_ignoring_case(description, needle)
    Option::None => false
  }
}

///|
/// Case-insensitive substring test (ASCII case only).
/// An empty needle matches everything.
fn contains_ignoring_case(haystack : String, needle : String) -> Bool {
  if needle == "" {
    true
  } else {
    haystack.to_lower().contains(needle)
  }
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
