///|
test "minimum span uses retained endpoints and accepts the exact boundary" {
  let anchors : Array[@calibration.Anchor] = [
    { device_us: 0L, reference_us: 5000L, },
    { device_us: 100L, reference_us: 110L, },
    { device_us: 200L, reference_us: 210L, },
    { device_us: 300L, reference_us: 310L, },
    { device_us: 400L, reference_us: 410L, },
  ]
  let fit = @calibration.calibrate(anchors, tolerance_us=1.0, min_span_us=300L)
  assert_eq(fit.clock.coverage_span_us(), 300L)
  try
    @calibration.calibrate(anchors, tolerance_us=1.0, min_span_us=301L)
  catch {
    InsufficientSpan(300L, 301L) => ()
    error => raise error
  } noraise {
    _ => fail("expected the rejected endpoint to leave insufficient coverage")
  }
}

///|
test "offset-only mode has zero coverage duration" {
  let anchors : Array[@calibration.Anchor] = [
    { device_us: 5L, reference_us: 7L, },
  ]
  assert_eq(@calibration.calibrate(anchors).clock.coverage_span_us(), 0L)
  try @calibration.calibrate(anchors, min_span_us=1L) catch {
    InsufficientSpan(0L, 1L) => ()
    error => raise error
  } noraise {
    _ => fail("expected offset-only coverage to fail a positive minimum")
  }
}
