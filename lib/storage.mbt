/// Storage layer for beads.
/// Handles SQLite database operations.

/// Beads storage wrapper
pub struct BeadsStorage {
  conn : @sqlite3.Connection
}

/// Open or create beads database
pub fn open(db_path : String) -> Result[BeadsStorage, String] {
  let conn = try @sqlite3.Connection::open(db_path) catch { _ => return Result::Err("Failed to open database") }

  // Initialize schema (ignore errors for idempotent operations)
  let stmt1 = try conn.prepare("CREATE TABLE IF NOT EXISTS config (key TEXT PRIMARY KEY, value TEXT NOT NULL);") catch { _ => return Result::Err("prepare failed") }
  try stmt1.step_once() catch { _ => () }
  try stmt1.finalize() catch { _ => () }
  
  let stmt2 = try conn.prepare("CREATE TABLE IF NOT EXISTS issues (id TEXT PRIMARY KEY, title TEXT NOT NULL, type TEXT NOT NULL DEFAULT 'other', priority INTEGER NOT NULL DEFAULT 2, status TEXT NOT NULL DEFAULT 'open', description TEXT, assignee TEXT, owner TEXT, created_at INTEGER NOT NULL, updated_at INTEGER NOT NULL, closed_at INTEGER, closed_reason TEXT, parent TEXT, estimate INTEGER, due_date INTEGER, external_ref TEXT, is_ephemeral INTEGER NOT NULL DEFAULT 0);") catch { _ => return Result::Err("prepare failed") }
  try stmt2.step_once() catch { _ => () }
  try stmt2.finalize() catch { _ => () }
  
  let stmt3 = try conn.prepare("CREATE TABLE IF NOT EXISTS issue_labels (issue_id TEXT NOT NULL, label TEXT NOT NULL, PRIMARY KEY (issue_id, label), FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE);") catch { _ => return Result::Err("prepare failed") }
  try stmt3.step_once() catch { _ => () }
  try stmt3.finalize() catch { _ => () }
  
  let stmt4 = try conn.prepare("CREATE TABLE IF NOT EXISTS issue_dependencies (issue_id TEXT NOT NULL, depends_on TEXT NOT NULL, PRIMARY KEY (issue_id, depends_on), FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE, FOREIGN KEY (depends_on) REFERENCES issues(id) ON DELETE CASCADE);") catch { _ => return Result::Err("prepare failed") }
  try stmt4.step_once() catch { _ => () }
  try stmt4.finalize() catch { _ => () }
  
  let stmt5 = try conn.prepare("CREATE TABLE IF NOT EXISTS comments (id INTEGER PRIMARY KEY AUTOINCREMENT, issue_id TEXT NOT NULL, body TEXT NOT NULL, created_at INTEGER NOT NULL, FOREIGN KEY (issue_id) REFERENCES issues(id) ON DELETE CASCADE);") catch { _ => return Result::Err("prepare failed") }
  try stmt5.step_once() catch { _ => () }
  try stmt5.finalize() catch { _ => () }
  
  let stmt6 = try conn.prepare("CREATE INDEX IF NOT EXISTS idx_issues_status ON issues(status);") catch { _ => return Result::Err("prepare failed") }
  try stmt6.step_once() catch { _ => () }
  try stmt6.finalize() catch { _ => () }
  
  let stmt7 = try conn.prepare("CREATE INDEX IF NOT EXISTS idx_issues_priority ON issues(priority);") catch { _ => return Result::Err("prepare failed") }
  try stmt7.step_once() catch { _ => () }
  try stmt7.finalize() catch { _ => () }
  
  let stmt8 = try conn.prepare("CREATE INDEX IF NOT EXISTS idx_issues_created_at ON issues(created_at);") catch { _ => return Result::Err("prepare failed") }
  try stmt8.step_once() catch { _ => () }
  try stmt8.finalize() catch { _ => () }

  Result::Ok(BeadsStorage::{ conn: conn })
}

/// Close the database connection
pub fn close(storage : BeadsStorage) -> Unit {
  try storage.conn.close() catch { _ => () }
}

/// Set a config value
pub fn set_config(storage : BeadsStorage, key : String, value : String) -> Result[Unit, String] {
  let stmt = try storage.conn.prepare("INSERT OR REPLACE INTO config (key, value) VALUES (?, ?);") catch { _ => return Result::Err("prepare failed") }
  try stmt.bind(index=1, key) catch { _ => return Result::Err("bind failed") }
  try stmt.bind(index=2, value) catch { _ => return Result::Err("bind failed") }
  try stmt.step_once() catch { _ => return Result::Err("step failed") }
  try stmt.finalize() catch { _ => return Result::Err("finalize failed") }
  Result::Ok(())
}

/// Get a config value
pub fn get_config(storage : BeadsStorage, key : String) -> Result[Option[String], String] {
  let stmt = try storage.conn.prepare("SELECT value FROM config WHERE key = ?;") catch { _ => return Result::Err("prepare failed") }
  try stmt.bind(index=1, key) catch { _ => return Result::Err("bind failed") }

  let has_row = try stmt.step() catch { _ => return Result::Err("step failed") }
  
  if has_row {
    let value = stmt.column(index=0)
    try stmt.finalize() catch { _ => return Result::Err("finalize failed") }
    Result::Ok(Option::Some(value))
  } else {
    try stmt.finalize() catch { _ => return Result::Err("finalize failed") }
    Result::Ok(Option::None)
  }
}

/// Insert a new issue
pub fn insert_issue(storage : BeadsStorage, issue : Issue) -> Result[Unit, String] {
  let stmt = try storage.conn.prepare("INSERT INTO issues (id, title, type, priority, status, description, assignee, owner, created_at, updated_at, is_ephemeral) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?);") catch { _ => return Result::Err("prepare failed") }

  ignore(try stmt.bind(index=1, issue.id) catch { _ => return Result::Err("bind failed") })
  ignore(try stmt.bind(index=2, issue.title) catch { _ => return Result::Err("bind failed") })
  ignore(try stmt.bind(index=3, issue_type_to_string(issue.type_)) catch { _ => return Result::Err("bind failed") })
  ignore(try stmt.bind(index=4, issue.priority) catch { _ => return Result::Err("bind failed") })
  ignore(try stmt.bind(index=5, status_to_string(issue.status)) catch { _ => return Result::Err("bind failed") })

  match issue.description {
    Option::Some(desc) => { ignore(try stmt.bind(index=6, desc) catch { _ => return Result::Err("bind failed") }) }
    Option::None => { ignore(try stmt.bind(index=6, "") catch { _ => return Result::Err("bind failed") }) }
  }

  match issue.assignee {
    Option::Some(a) => { ignore(try stmt.bind(index=7, a) catch { _ => return Result::Err("bind failed") }) }
    Option::None => { ignore(try stmt.bind(index=7, "") catch { _ => return Result::Err("bind failed") }) }
  }

  match issue.owner {
    Option::Some(o) => { ignore(try stmt.bind(index=8, o) catch { _ => return Result::Err("bind failed") }) }
    Option::None => { ignore(try stmt.bind(index=8, "") catch { _ => return Result::Err("bind failed") }) }
  }

  ignore(try stmt.bind(index=9, issue.created_at) catch { _ => return Result::Err("bind failed") })
  ignore(try stmt.bind(index=10, issue.updated_at) catch { _ => return Result::Err("bind failed") })
  ignore(try stmt.bind(index=11, if issue.is_ephemeral { 1 } else { 0 }) catch { _ => return Result::Err("bind failed") })

  ignore(try stmt.step_once() catch { _ => return Result::Err("step failed") })
  ignore(try stmt.finalize() catch { _ => return Result::Err("finalize failed") })

  Result::Ok(())
}

/// Get an issue by ID
pub fn get_issue_by_id(storage : BeadsStorage, id : String) -> Result[Option[Issue], String] {
  let stmt = try storage.conn.prepare("SELECT id, title, type, priority, status, description, assignee, owner, created_at, updated_at, is_ephemeral FROM issues WHERE id = ?;") catch { _ => return Result::Err("prepare failed") }
  
  try stmt.bind(index=1, id) catch { _ => return Result::Err("bind failed") }
  
  let result = if (try stmt.step() catch { _ => return Result::Err("step failed") }) {
    let issue_id : String = stmt.column(index=0)
    let title : String = stmt.column(index=1)
    let type_str : String = stmt.column(index=2)
    let priority : Int = stmt.column(index=3)
    let status_str : String = stmt.column(index=4)
    let description : String = stmt.column(index=5)
    let assignee : String = stmt.column(index=6)
    let owner : String = stmt.column(index=7)
    let created_at : Int = stmt.column(index=8)
    let updated_at : Int = stmt.column(index=9)
    let is_ephemeral : Int = stmt.column(index=10)
    
    let issue = Issue::{
      id: issue_id,
      title: title,
      type_: string_to_issue_type(type_str),
      priority: priority,
      status: string_to_status(status_str),
      description: if description == "" { Option::None } else { Option::Some(description) },
      assignee: if assignee == "" { Option::None } else { Option::Some(assignee) },
      owner: if owner == "" { Option::None } else { Option::Some(owner) },
      created_at: created_at,
      updated_at: updated_at,
      is_ephemeral: is_ephemeral == 1
    }
    
    Option::Some(issue)
  } else {
    Option::None
  }
  
  try stmt.finalize() catch { _ => return Result::Err("finalize failed") }
  
  Result::Ok(result)
}

/// List all issues
pub fn list_issues(storage : BeadsStorage) -> Result[Array[Issue], String] {
  let stmt = try storage.conn.prepare("SELECT id, title, type, priority, status, description, assignee, owner, created_at, updated_at, is_ephemeral FROM issues ORDER BY created_at DESC;") catch { _ => return Result::Err("prepare failed") }
  
  let issues : Array[Issue] = []
  
  while (try stmt.step() catch { _ => return Result::Err("step failed") }) {
    let id : String = stmt.column(index=0)
    let title : String = stmt.column(index=1)
    let type_str : String = stmt.column(index=2)
    let priority : Int = stmt.column(index=3)
    let status_str : String = stmt.column(index=4)
    let description : String = stmt.column(index=5)
    let assignee : String = stmt.column(index=6)
    let owner : String = stmt.column(index=7)
    let created_at : Int = stmt.column(index=8)
    let updated_at : Int = stmt.column(index=9)
    let is_ephemeral : Int = stmt.column(index=10)
    
    let issue = Issue::{
      id: id,
      title: title,
      type_: string_to_issue_type(type_str),
      priority: priority,
      status: string_to_status(status_str),
      description: if description == "" { Option::None } else { Option::Some(description) },
      assignee: if assignee == "" { Option::None } else { Option::Some(assignee) },
      owner: if owner == "" { Option::None } else { Option::Some(owner) },
      created_at: created_at,
      updated_at: updated_at,
      is_ephemeral: is_ephemeral == 1
    }
    
    Array::push(issues, issue)
  }
  
  try stmt.finalize() catch { _ => return Result::Err("finalize failed") }
  
  Result::Ok(issues)
}

/// Update issue status
pub fn update_issue_status(storage : BeadsStorage, id : String, status : String) -> Result[Unit, String] {
  let stmt = try storage.conn.prepare("UPDATE issues SET status = ?, updated_at = strftime('%s', 'now') WHERE id = ?;") catch { _ => return Result::Err("prepare failed") }
  
  try stmt.bind(index=1, status) catch { _ => return Result::Err("bind failed") }
  try stmt.bind(index=2, id) catch { _ => return Result::Err("bind failed") }
  
  try stmt.step_once() catch { _ => return Result::Err("step failed") }
  try stmt.finalize() catch { _ => return Result::Err("finalize failed") }
  
  Result::Ok(())
}

/// Get ready issues (open, not blocked by other open issues)
pub fn get_ready_issues(storage : BeadsStorage) -> Result[Array[Issue], String] {
  let stmt = try storage.conn.prepare("SELECT id, title, type, priority, status, description, assignee, owner, created_at, updated_at, is_ephemeral FROM issues WHERE status = 'open' ORDER BY priority ASC, created_at ASC;") catch { _ => return Result::Err("prepare failed") }
  
  let issues : Array[Issue] = []
  
  while (try stmt.step() catch { _ => return Result::Err("step failed") }) {
    let issue_id : String = stmt.column(index=0)
    let title : String = stmt.column(index=1)
    let type_str : String = stmt.column(index=2)
    let priority : Int = stmt.column(index=3)
    let status_str : String = stmt.column(index=4)
    let description : String = stmt.column(index=5)
    let assignee : String = stmt.column(index=6)
    let owner : String = stmt.column(index=7)
    let created_at : Int = stmt.column(index=8)
    let updated_at : Int = stmt.column(index=9)
    let is_ephemeral : Int = stmt.column(index=10)
    
    let issue = Issue::{
      id: issue_id,
      title: title,
      type_: string_to_issue_type(type_str),
      priority: priority,
      status: string_to_status(status_str),
      description: if description == "" { Option::None } else { Option::Some(description) },
      assignee: if assignee == "" { Option::None } else { Option::Some(assignee) },
      owner: if owner == "" { Option::None } else { Option::Some(owner) },
      created_at: created_at,
      updated_at: updated_at,
      is_ephemeral: is_ephemeral == 1
    }
    
    Array::push(issues, issue)
  }
  
  try stmt.finalize() catch { _ => return Result::Err("finalize failed") }
  
  Result::Ok(issues)
}

/// Update issue title
pub fn update_issue_title(storage : BeadsStorage, id : String, title : String) -> Result[Unit, String] {
  let stmt = try storage.conn.prepare("UPDATE issues SET title = ?, updated_at = strftime('%s', 'now') WHERE id = ?;") catch { _ => return Result::Err("prepare failed") }
  
  try stmt.bind(index=1, title) catch { _ => return Result::Err("bind failed") }
  try stmt.bind(index=2, id) catch { _ => return Result::Err("bind failed") }
  
  try stmt.step_once() catch { _ => return Result::Err("step failed") }
  try stmt.finalize() catch { _ => return Result::Err("finalize failed") }
  
  Result::Ok(())
}

/// Update issue priority
pub fn update_issue_priority(storage : BeadsStorage, id : String, priority : Int) -> Result[Unit, String] {
  let stmt = try storage.conn.prepare("UPDATE issues SET priority = ?, updated_at = strftime('%s', 'now') WHERE id = ?;") catch { _ => return Result::Err("prepare failed") }
  
  try stmt.bind(index=1, priority) catch { _ => return Result::Err("bind failed") }
  try stmt.bind(index=2, id) catch { _ => return Result::Err("bind failed") }
  
  try stmt.step_once() catch { _ => return Result::Err("step failed") }
  try stmt.finalize() catch { _ => return Result::Err("finalize failed") }
  
  Result::Ok(())
}

/// Defer an issue (set status to deferred)
pub fn defer_issue(storage : BeadsStorage, id : String) -> Result[Unit, String] {
  update_issue_status(storage, id, "deferred")
}

/// Initialize beads workspace
pub fn init_workspace(db_path : String, prefix : Option[String]) -> Result[String, String] {
  // Create .beads directory
  try @fs.create_dir("./.beads") catch { _ => () }
  
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
