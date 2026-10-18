/// Failure reporting for the `bm` CLI.
/// The exit codes and the error envelope follow the beads_rust CLI contract, so
/// a robot caller can read one parseable stream and branch on the code.

///|
/// Failure categories, each with its own process exit code.
/// The numbering is the beads_rust "Exit Codes" table.
pub(all) enum ErrorKind {
  Internal
  Database
  Issue
  Validation
  Dependency
  Sync
  Config
  Io
}

///|
/// The process exit code of a failure category.
pub fn exit_code(kind : ErrorKind) -> Int32 {
  match kind {
    ErrorKind::Internal => 1
    ErrorKind::Database => 2
    ErrorKind::Issue => 3
    ErrorKind::Validation => 4
    ErrorKind::Dependency => 5
    ErrorKind::Sync => 6
    ErrorKind::Config => 7
    ErrorKind::Io => 8
  }
}

///|
/// A CLI failure: the machine-readable envelope plus the exit category.
pub(all) struct CliError {
  kind : ErrorKind
  code : String
  message : String
  hint : String?
  retryable : Bool
  context : Json
}

///|
/// Build a CLI failure. Failures of the current commands are never retryable,
/// so `retryable` is left at false.
pub fn cli_error(
  kind : ErrorKind,
  code : String,
  message : String,
  hint~ : String = "",
  context~ : Json = Json::null(),
) -> CliError {
  CliError::{
    kind,
    code,
    message,
    hint: if hint == "" {
      Option::None
    } else {
      Option::Some(hint)
    },
    retryable: false,
    context,
  }
}

///|
/// The failure of a public storage call, reported as a database error.
pub fn storage_error(message : String) -> CliError {
  cli_error(
    ErrorKind::Database,
    "DATABASE_ERROR",
    message,
    hint="Check that .beads/beads.db is readable and not locked.",
  )
}

///|
/// The structured error envelope. In JSON mode it is the whole of stdout on a
/// failing exit; `hint` is always present, as `null` when there is none.
pub fn error_envelope(error : CliError) -> Json {
  Json::object({
    "error": {
      "code": Json::string(error.code),
      "message": Json::string(error.message),
      "hint": match error.hint {
        Option::Some(hint) => Json::string(hint)
        Option::None => Json::null()
      },
      "retryable": Json::boolean(error.retryable),
      "context": error.context,
    },
  })
}
