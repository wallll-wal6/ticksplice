///|
test "one anchor supplies an offset and no drift estimate" {
  let result = @calibration.calibrate([{ device_us: 100L, reference_us: 125L, }])
  assert_true(result.clock.drift_ppm() is None)
  assert_eq(result.clock.project(150L), 175L)
  assert_false(result.clock.is_extrapolated(100L))
  assert_true(result.clock.is_extrapolated(99L))
}

///|
test "fit epoch-scale clocks and isolate one mispaired event" {
  let origin = 1_750_000_000_000_000L
  let anchors : Array[@calibration.Anchor] = []
  for i in 0..<9 {
    let elapsed = i.to_int64() * 1_000_000L
    let noise = if i == 4 { 60_000L } else { 0L }
    anchors.push({
      device_us: origin + elapsed,
      reference_us: origin + elapsed + 250_000L + elapsed / 1000L + noise,
    })
  }
  anchors.rev_in_place()
  let result = @calibration.calibrate(anchors, tolerance_us=50.0)
  assert_eq(result.clock.project(origin + 3_500_000L), origin + 3_753_500L)
  assert_true(result.clock.drift_ppm().unwrap() > 999.99)
  assert_false(result.evidence[4].accepted)
  assert_true(result.evidence[4].residual_us > 59_999.0)
  assert_true(result.clock.is_extrapolated(origin + 10_000_000L))
}

///|
test "reject duplicate device timestamps" {
  try
    @calibration.calibrate([
      { device_us: 100L, reference_us: 125L, },
      { device_us: 100L, reference_us: 130L, },
    ])
  catch {
    DuplicateDeviceTime(100L) => ()
    error => raise error
  } noraise {
    _ => fail("expected duplicate error")
  }
}

///|
test "reject a backwards reference clock" {
  try
    @calibration.calibrate([
      { device_us: 100L, reference_us: 125L, },
      { device_us: 200L, reference_us: 50L, },
    ])
  catch {
    NonMonotonicClock => ()
    error => raise error
  } noraise {
    _ => fail("expected backwards clock error")
  }
}

///|
test "reject a projection outside the supported epoch" {
  let result = @calibration.calibrate([{ device_us: 100L, reference_us: 10L, }])
  try result.clock.project(0L) catch {
    ProjectionOutOfRange => ()
    error => raise error
  } noraise {
    _ => fail("expected out-of-range error")
  }
}
