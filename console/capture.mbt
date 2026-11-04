///|
fn timestamp(
  text : String,
  record : Int32,
  column : String,
) -> Int64 raise InputError {
  guard !text.is_empty() else { raise BadTimestamp(record, column) }
  for ch in text {
    guard ch >= '0' && ch <= '9' else { raise BadTimestamp(record, column) }
  }
  let parsed = @string.parse_int64(text) catch {
    _ => raise BadTimestamp(record, column)
  }
  guard parsed >= 0L && parsed <= 9_007_199_254_740_991L else {
    raise BadTimestamp(record, column)
  }
  parsed
}

///|
fn read_anchors(text : String) -> Array[@calibration.Anchor] raise InputError {
  let rows = read_csv(text)
  guard rows is [["device_us", "reference_us"], .. records] else {
    raise BadHeader("expected device_us,reference_us")
  }
  let anchors : Array[@calibration.Anchor] = []
  for i, row in records {
    let record = i + 2
    guard row is [device, reference] else { raise BadWidth(record) }
    anchors.push({
      device_us: timestamp(device, record, "device_us"),
      reference_us: timestamp(reference, record, "reference_us"),
    })
  }
  anchors
}

///|
fn project_capture(
  text : String,
  clock : @calibration.ClockMap,
) -> String raise {
  let rows = read_csv(text)
  guard rows is [header, .. records] && header is ["device_us", ..] else {
    raise BadHeader("capture header must start with device_us")
  }
  let names : Set[String] = Set([])
  for name in header {
    if name.is_empty() ||
      names.contains(name) ||
      name == "reference_us" ||
      name == "extrapolated" {
      raise BadHeader(
        "capture column names must be unique and cannot be empty or reserved",
      )
    }
    names.add(name)
  }
  let output = StringBuilder()
  write_record(output, [..header, "reference_us", "extrapolated"])
  for i, row in records {
    guard row.length() == header.length() else { raise BadWidth(i + 2) }
    let device = timestamp(row[0], i + 2, "device_us")
    let reference = clock.project(device)
    let extrapolated = clock.is_extrapolated(device)
    write_record(
      output,
      [..row, reference.to_string(), extrapolated.to_string()],
    )
  }
  output.to_string()
}
