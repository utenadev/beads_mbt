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

///|
/// Seconds in one day, shared by the date helpers below.
let seconds_per_day : Int32 = 86400

///|
/// Days since 1970-01-01 for a proleptic Gregorian date.
/// Howard Hinnant's `days_from_civil`. The year is positive for every date
/// `parse_date` accepts, so the negative-year branches only keep the formula
/// faithful.
fn days_from_civil(year : Int32, month : Int32, day : Int32) -> Int32 {
  let y = if month <= 2 { year - 1 } else { year }
  let era = if y >= 0 { y / 400 } else { (y - 399) / 400 }
  let yoe = y - era * 400
  let mp = if month > 2 { month - 3 } else { month + 9 }
  let doy = (153 * mp + 2) / 5 + day - 1
  let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
  era * 146097 + doe - 719468
}

///|
/// The Gregorian year, month, and day of a day count since 1970-01-01.
/// Howard Hinnant's `civil_from_days`, the inverse of `days_from_civil`.
fn civil_from_days(days : Int32) -> (Int32, Int32, Int32) {
  let z = days + 719468
  let era = (if z >= 0 { z } else { z - 146096 }) / 146097
  let doe = z - era * 146097
  let yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365
  let y = yoe + era * 400
  let doy = doe - (365 * yoe + yoe / 4 - yoe / 100)
  let mp = (5 * doy + 2) / 153
  let d = doy - (153 * mp + 2) / 5 + 1
  let m = if mp < 10 { mp + 3 } else { mp - 9 }
  (if m <= 2 { y + 1 } else { y }, m, d)
}

///|
/// Parse a non-empty run of ASCII digits. Anything else is rejected, so a
/// typo cannot silently become a different date.
fn parse_digits(text : String) -> Int32? {
  if text.is_empty() {
    return Option::None
  }
  let mut value : Int32 = 0
  for char in text {
    if char < '0' || char > '9' {
      return Option::None
    }
    value = value * 10 + (char.to_int() - '0'.to_int())
  }
  Option::Some(value)
}

///|
/// The digits of `text` between `start` and `end`, or `None` when the slice is
/// missing or not numeric.
fn number_at(text : String, start : Int32, end : Int32) -> Int32? {
  match text.get_view(start~, end~) {
    Option::Some(view) => parse_digits(view.to_owned())
    Option::None => Option::None
  }
}

///|
/// The two characters of `text` between `start` and `end`, for `-`, `T`, and
/// `Z` position checks.
fn slice_at(text : String, start : Int32, end : Int32) -> String {
  match text.get_view(start~, end~) {
    Option::Some(view) => view.to_owned()
    Option::None => ""
  }
}

///|
/// Parse a date for `--due` and `--defer` into Unix seconds.
///
/// Accepted forms:
/// - `YYYY-MM-DD`, at 09:00 UTC (beads_rust uses 09:00 local, which bm cannot
///   resolve without a time-zone database)
/// - `YYYY-MM-DDTHH:MM:SSZ`, an exact UTC instant
/// - `+N`, `+Nd`, `+Nw`, `+Nh`, relative to now (`N` days when no unit is given)
/// - `tomorrow`, at 09:00 UTC
pub fn parse_date_to_timestamp(text : String) -> Result[Int32, String] {
  let value = text.trim().to_owned()
  if value == "" {
    return Result::Err("empty date")
  }

  if value.has_prefix("+") {
    let digits = slice_at(value, 1, value.length())
    let mut number_text = digits
    let mut unit = "d"
    if digits.length() > 1 {
      let last = slice_at(value, value.length() - 1, value.length())
      if last == "d" || last == "w" || last == "h" {
        number_text = slice_at(value, 1, value.length() - 1)
        unit = last
      }
    }
    let amount = match parse_digits(number_text) {
      Option::Some(n) => n
      Option::None =>
        return Result::Err(
          "invalid relative date: " + value + " (expected +N, +Nd, +Nw, or +Nh)",
        )
    }
    let seconds = if unit == "w" {
      amount * 7 * seconds_per_day
    } else if unit == "h" {
      amount * 3600
    } else {
      amount * seconds_per_day
    }
    return Result::Ok(current_timestamp() + seconds)
  }

  if value.equal_ignore_ascii_case("tomorrow") {
    let today = current_timestamp() / seconds_per_day
    return Result::Ok((today + 1) * seconds_per_day + 9 * 3600)
  }

  if value.length() != 10 && value.length() < 19 {
    return Result::Err(invalid_date_message(value))
  }
  if slice_at(value, 4, 5) != "-" || slice_at(value, 7, 8) != "-" {
    return Result::Err(invalid_date_message(value))
  }
  let year = match number_at(value, 0, 4) {
    Option::Some(n) => n
    Option::None => return Result::Err(invalid_date_message(value))
  }
  let month = match number_at(value, 5, 7) {
    Option::Some(n) => n
    Option::None => return Result::Err(invalid_date_message(value))
  }
  let day = match number_at(value, 8, 10) {
    Option::Some(n) => n
    Option::None => return Result::Err(invalid_date_message(value))
  }
  if month < 1 || month > 12 || day < 1 || day > 31 {
    return Result::Err(invalid_date_message(value))
  }

  let mut hour : Int32 = 9
  let mut minute : Int32 = 0
  let mut second : Int32 = 0
  if value.length() > 10 {
    if value.length() < 19 ||
      slice_at(value, 10, 11) != "T" ||
      slice_at(value, 19, 20) != "Z" {
      return Result::Err(invalid_date_message(value))
    }
    hour = match number_at(value, 11, 13) {
      Option::Some(n) => n
      Option::None => return Result::Err(invalid_date_message(value))
    }
    minute = match number_at(value, 14, 16) {
      Option::Some(n) => n
      Option::None => return Result::Err(invalid_date_message(value))
    }
    second = match number_at(value, 17, 19) {
      Option::Some(n) => n
      Option::None => return Result::Err(invalid_date_message(value))
    }
    if slice_at(value, 13, 14) != ":" || slice_at(value, 16, 17) != ":" {
      return Result::Err(invalid_date_message(value))
    }
    if hour > 23 || minute > 59 || second > 59 {
      return Result::Err(invalid_date_message(value))
    }
  }

  Result::Ok(
    days_from_civil(year, month, day) * seconds_per_day +
    hour * 3600 +
    minute * 60 +
    second,
  )
}

///|
/// Parse a non-negative decimal integer, used by `--estimate`.
pub fn parse_non_negative_int(text : String) -> Result[Int32, String] {
  match parse_digits(text.trim().to_owned()) {
    Option::Some(number) => Result::Ok(number)
    Option::None =>
      Result::Err("invalid number: " + text + " (expected minutes)")
  }
}

///|
/// The message every malformed date gets, so callers do not repeat it.
fn invalid_date_message(value : String) -> String {
  "invalid date: " +
  value +
  " (expected YYYY-MM-DD, YYYY-MM-DDTHH:MM:SSZ, +Nd, +Nw, +Nh, or tomorrow)"
}

///|
/// Pad `value` to `width` digits with leading zeros.
fn pad_number(value : Int32, width : Int32) -> String {
  let mut text = value.to_string()
  while text.length() < width {
    text = "0" + text
  }
  text
}

///|
/// Format a Unix timestamp as `YYYY-MM-DD` in UTC, the inverse of the bare
/// `YYYY-MM-DD` form `parse_date_to_timestamp` accepts.
pub fn format_date(timestamp : Int32) -> String {
  let days = timestamp / seconds_per_day
  let (year, month, day) = civil_from_days(days)
  pad_number(year, 4) + "-" + pad_number(month, 2) + "-" + pad_number(day, 2)
}
