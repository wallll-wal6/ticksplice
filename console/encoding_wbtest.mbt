///|
test "invalid UTF-8 payload is rejected before CSV parsing" {
  try decode_input(b"device_us,note\n1,\xC3\x28\n") catch {
    InvalidUtf8 => ()
    error => raise error
  } noraise {
    _ => fail("expected invalid UTF-8 error")
  }
}

///|
test "strict UTF-8 preserves multilingual capture fields and BOM input" {
  let text = "\uFEFFdevice_us,note\r\n1,温度 α\r\n"
  let rows = read_csv(decode_input(@utf8.encode(text)))
  assert_eq(rows, [["device_us", "note"], ["1", "温度 α"]])
}
