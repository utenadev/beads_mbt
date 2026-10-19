/// Data models for beads issue tracker.

///|
/// Issue status.
/// Declared `pub(all)` so callers in other packages (the `bm` CLI, tests) can
/// build one instead of going through a string.
pub(all) enum Status {
  Open
  InProgress
  Closed
  Deferred
}

///|
/// Issue priority (0-4, where 0 is critical)
pub type Priority = Int32

///|
/// Issue type.
/// Declared `pub(all)` so callers in other packages (the `bm` CLI) can build
/// one, for example from `bm create --type`.
pub(all) enum IssueType {
  Bug
  Feature
  Task
  Documentation
  Question
  Other
}

///|
/// Issue record.
/// Declared `pub(all)` so callers in other packages (the `bm` CLI, tests) can
/// build one directly when they need values `make_issue` leaves alone, such as
/// a timestamp or a description.
pub(all) struct Issue {
  id : String
  title : String
  type_ : IssueType
  priority : Priority
  status : Status
  description : String?
  assignee : String?
  owner : String?
  acceptance_criteria : String?
  prerequisites : String?
  created_at : Int32
  updated_at : Int32
  is_ephemeral : Bool
}

///|
/// Create a new issue with default values.
/// `issue_type` and `priority` can be supplied by callers that already know
/// them, such as `bm create --type` / `--priority`.
pub fn make_issue(
  id : String,
  title : String,
  issue_type~ : IssueType = IssueType::Other,
  priority~ : Priority = 2,
) -> Issue {
  let timestamp = current_timestamp()
  Issue::{
    id,
    title,
    type_: issue_type,
    priority,
    status: Status::Open,
    description: Option::None,
    assignee: Option::None,
    owner: Option::None,
    acceptance_criteria: Option::None,
    prerequisites: Option::None,
    created_at: timestamp,
    updated_at: timestamp,
    is_ephemeral: false,
  }
}

///|
/// Convert status to string
pub fn status_to_string(status : Status) -> String {
  match status {
    Status::Open => "open"
    Status::InProgress => "in_progress"
    Status::Closed => "closed"
    Status::Deferred => "deferred"
  }
}

///|
/// Convert string to status
pub fn string_to_status(s : String) -> Status {
  match s {
    "open" => Status::Open
    "in_progress" => Status::InProgress
    "closed" => Status::Closed
    "deferred" => Status::Deferred
    _ => Status::Open
  }
}

///|
/// Convert issue type to string
pub fn issue_type_to_string(t : IssueType) -> String {
  match t {
    IssueType::Bug => "bug"
    IssueType::Feature => "feature"
    IssueType::Task => "task"
    IssueType::Documentation => "documentation"
    IssueType::Question => "question"
    IssueType::Other => "other"
  }
}

///|
/// Convert string to issue type
pub fn string_to_issue_type(s : String) -> IssueType {
  match s {
    "bug" => IssueType::Bug
    "feature" => IssueType::Feature
    "task" => IssueType::Task
    "documentation" => IssueType::Documentation
    "question" => IssueType::Question
    _ => IssueType::Other
  }
}

///|
/// Parse an issue type from user input.
/// Unlike `string_to_issue_type`, unknown values are rejected instead of
/// silently falling back to `other`.
pub fn parse_issue_type(s : String) -> Result[IssueType, String] {
  match s {
    "bug" => Result::Ok(IssueType::Bug)
    "feature" => Result::Ok(IssueType::Feature)
    "task" => Result::Ok(IssueType::Task)
    "documentation" | "docs" => Result::Ok(IssueType::Documentation)
    "question" => Result::Ok(IssueType::Question)
    "other" => Result::Ok(IssueType::Other)
    _ =>
      Result::Err(
        "invalid type: " +
        s +
        " (expected bug, feature, task, documentation, question, other)",
      )
  }
}

///|
/// Parse a priority from `0`-`4` or `P0`-`P4` (case-insensitive).
/// `0` is the most critical priority.
pub fn parse_priority(s : String) -> Result[Priority, String] {
  match s {
    "0" | "P0" | "p0" => Result::Ok(0)
    "1" | "P1" | "p1" => Result::Ok(1)
    "2" | "P2" | "p2" => Result::Ok(2)
    "3" | "P3" | "p3" => Result::Ok(3)
    "4" | "P4" | "p4" => Result::Ok(4)
    _ => Result::Err("invalid priority: " + s + " (expected 0-4 or P0-P4)")
  }
}

///|
/// Dependency relationship type name.
/// Kept as a plain string so custom types survive a storage round-trip.
pub type DependencyType = String

///|
/// A dependency edge: `issue_id` depends on `depends_on` with `type_`.
pub struct Dependency {
  issue_id : String
  depends_on : String
  type_ : DependencyType
}

///|
/// The dependency type used when the caller does not specify one.
pub fn default_dependency_type() -> DependencyType {
  "blocks"
}

///|
/// Whether a dependency type makes the target block the source issue.
/// Mirrors beads_rust's `DependencyType::is_blocking` minus `parent-child`:
/// a child inherits its parent's blocked state instead of being blocked by
/// the parent edge itself.
pub fn is_blocking_dependency_type(t : DependencyType) -> Bool {
  t == "blocks" || t == "conditional-blocks" || t == "waits-for"
}
