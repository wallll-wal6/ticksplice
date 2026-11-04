///|
test "capture preserves quoted payloads and input record order" {
  let result = @calibration.calibrate([
    { device_us: 100L, reference_us: 120L, },
    { device_us: 200L, reference_us: 220L, },
  ])
  let source = "\uFEFFdevice_us,note\r\n201,\"line 1\r\nline \"\"2\"\"\"\r\n150,\"a,b\"\r\n150,"
  let output = project_capture(source, result.clock)
  assert_eq(read_csv(output), [
    ["device_us", "note", "reference_us", "extrapolated"],
    ["201", "line 1\r\nline \"2\"", "221", "true"],
    ["150", "a,b", "170", "false"],
    ["150", "", "170", "false"],
  ])
}

///|
test "reject malformed CSV instead of silently changing records" {
  try read_csv("device_us,note\n1,\"unclosed") catch {
    BadCsv(2, _) => ()
    error => raise error
  } noraise {
    _ => fail("expected malformed CSV error")
  }
}

///|
test "identify the logical record and column of an invalid timestamp" {
  try read_anchors("device_us,reference_us\n01,12\n2,12.5\n") catch {
    BadTimestamp(3, "reference_us") => ()
    error => raise error
  } noraise {
    _ => fail("expected invalid timestamp error")
  }
}
