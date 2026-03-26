/// Utility functions for beads.

/// Generate a short random ID (6 characters, lowercase alphanumeric)
pub fn generate_short_id() -> String {
  // TODO: Implement proper random generation
  // For now, return a placeholder
  "xxxxxx"
}

/// Generate an issue ID with prefix
pub fn generate_issue_id(prefix : String) -> String {
  prefix + "-" + generate_short_id()
}

/// Get current timestamp (seconds since epoch)
pub fn current_timestamp() -> Int {
  // TODO: Use system time when available
  0
}
