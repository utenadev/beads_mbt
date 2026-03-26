/// Data models for beads issue tracker.

/// Issue status
pub enum Status {
  Open
  InProgress
  Closed
  Deferred
}

/// Issue priority (0-4, where 0 is critical)
pub type Priority = Int

/// Issue type
pub enum IssueType {
  Bug
  Feature
  Task
  Documentation
  Question
  Other
}

/// Issue record
pub struct Issue {
  id : String
  title : String
  type_ : IssueType
  priority : Priority
  status : Status
  description : Option[String]
  assignee : Option[String]
  owner : Option[String]
  created_at : Int
  updated_at : Int
  is_ephemeral : Bool
}

/// Create a new issue with default values
pub fn make_issue(id : String, title : String) -> Issue {
  Issue::{
    id: id,
    title: title,
    type_: IssueType::Other,
    priority: 2,
    status: Status::Open,
    description: Option::None,
    assignee: Option::None,
    owner: Option::None,
    created_at: 0,
    updated_at: 0,
    is_ephemeral: false
  }
}

/// Convert status to string
pub fn status_to_string(status : Status) -> String {
  match status {
    Status::Open => "open"
    Status::InProgress => "in_progress"
    Status::Closed => "closed"
    Status::Deferred => "deferred"
  }
}

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
