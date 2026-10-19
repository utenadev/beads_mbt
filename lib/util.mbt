/// Utility functions for beads.

///|
/// Generate a short random ID (6 characters, lowercase alphanumeric)
pub fn generate_short_id() -> String {
  let alphabet : Array[Char] = [
    '0', '1', '2', '3', '4', '5', '6', '7', '8', '9', 'a', 'b', 'c', 'd', 'e', 'f',
    'g', 'h', 'i', 'j', 'k', 'l', 'm', 'n', 'o', 'p', 'q', 'r', 's', 't', 'u', 'v',
    'w', 'x', 'y', 'z',
  ]
  let rng = @random.Rand()
  let mut id = ""
  for _i in 0..<6 {
    id = id + alphabet[rng.int(limit=36)].to_string()
  }
  id
}

///|
/// Generate an issue ID with prefix
pub fn generate_issue_id(prefix : String) -> String {
  prefix + "-" + generate_short_id()
}

///|
/// Get current timestamp (seconds since epoch)
pub fn current_timestamp() -> Int32 {
  (@env.now() / 1000UL).to_int()
}
