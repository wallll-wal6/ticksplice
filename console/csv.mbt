///|
priv enum FieldState {
  Start
  Plain
  Quoted
  Closed
}

///|
suberror InputError {
  BadCsv(Int32, String)
  BadTimestamp(Int32, String)
  BadHeader(String)
  BadWidth(Int32)
  BadTolerance
  BadMinimumSpan
  BadArguments
  UnreadableInput(String)
  InvalidUtf8
}

///|
// Read UTF-8 CSV with optional BOM, escaped quotes, and LF or CRLF records.
fn read_csv(text : String) -> Array[Array[String]] raise InputError {
  let rows = []
  let mut row = []
  let mut field = StringBuilder()
  let mut state = Start
  let mut at_start = true
  let mut after_cr = false
  for ch in text {
    if at_start {
      at_start = false
      if ch == '\uFEFF' {
        continue
      }
    }
    if after_cr {
      after_cr = false
      if ch == '\n' {
        continue
      }
    }
    if state is Quoted {
      if ch == '"' {
        state = Closed
      } else {
        field.write_char(ch)
      }
      continue
    }
    match ch {
      ',' | '\n' | '\r' => {
        row.push(field.to_string())
        field = StringBuilder()
        state = Start
        if ch != ',' {
          rows.push(row)
          row = []
          after_cr = ch == '\r'
        }
      }
      '"' =>
        match state {
          Start => state = Quoted
          Closed => {
            field.write_char('"')
            state = Quoted
          }
          _ => raise BadCsv(rows.length() + 1, "quote in an unquoted field")
        }
      _ => {
        if state is Closed {
          raise BadCsv(rows.length() + 1, "text after closing quote")
        }
        field.write_char(ch)
        state = Plain
      }
    }
  }
  if state is Quoted {
    raise BadCsv(rows.length() + 1, "unterminated quoted field")
  }
  if !(state is Start) || !row.is_empty() {
    row.push(field.to_string())
    rows.push(row)
  }
  rows
}

///|
fn write_record(out : StringBuilder, fields : ArrayView[String]) -> Unit {
  for i, field in fields {
    if i > 0 {
      out.write_char(',')
    }
    // Quoting every field keeps the encoder independent of field contents.
    out.write_char('"')
    for ch in field {
      if ch == '"' {
        out.write_char('"')
      }
      out.write_char(ch)
    }
    out.write_char('"')
  }
  out.write_char('\n')
}
