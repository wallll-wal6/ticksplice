///|
test "time translation leaves the fitted drift and relative projections intact" {
  let relative : Array[@calibration.Anchor] = [
    { device_us: 0L, reference_us: 5000L, },
    { device_us: 1_000_000L, reference_us: 1_005_200L, },
    { device_us: 2_000_000L, reference_us: 2_005_400L, },
  ]
  let origin = 1_750_000_000_000_000L
  let shifted = relative.map(fn(a) {
    @calibration.Anchor::{
      device_us: a.device_us + origin,
      reference_us: a.reference_us + origin,
    }
  })
  let a = @calibration.calibrate(relative, tolerance_us=1.0)
  let b = @calibration.calibrate(shifted, tolerance_us=1.0)
  for time in [500_000L, 1_500_000L, 3_000_000L] {
    assert_eq(b.clock.project(origin + time) - origin, a.clock.project(time))
  }
  assert_eq(a.clock.drift_ppm(), b.clock.drift_ppm())
}

///|
test "the maximum supported integer timestamp projects without overflow" {
  let maximum = 9_007_199_254_740_991L
  let fit = @calibration.calibrate([
    { device_us: maximum, reference_us: maximum, },
  ])
  assert_eq(fit.clock.project(maximum), maximum)
  assert_eq(fit.clock.project(maximum - 1L), maximum - 1L)
  try fit.clock.project(maximum + 1L) catch {
    InvalidTimestamp => ()
    error => raise error
  } noraise {
    _ => fail("expected unsupported timestamp rejection")
  }
}

///|
test "reject nonfinite tolerance and unsupported minimum span" {
  let anchors : Array[@calibration.Anchor] = [
    { device_us: 10L, reference_us: 20L, },
  ]
  for tolerance in [0.0, -1.0, 0.0 / 0.0, 1.0 / 0.0] {
    try @calibration.calibrate(anchors, tolerance_us=tolerance) catch {
      InvalidTolerance => ()
      error => raise error
    } noraise {
      _ => fail("expected invalid tolerance rejection")
    }
  }
  try @calibration.calibrate(anchors, min_span_us=-1L) catch {
    InvalidMinimumSpan => ()
    error => raise error
  } noraise {
    _ => fail("expected invalid span rejection")
  }
}

///|
test "support the maximum anchor count and reject larger fits" {
  let anchors : Array[@calibration.Anchor] = []
  for i in 0..<256 {
    anchors.push({
      device_us: i.to_int64() * 100L,
      reference_us: i.to_int64() * 100L + 50L,
    })
  }
  assert_eq(@calibration.calibrate(anchors).clock.project(12_345L), 12_395L)
  anchors.push({ device_us: 25_600L, reference_us: 25_650L, })
  try @calibration.calibrate(anchors) catch {
    TooManyAnchors => ()
    error => raise error
  } noraise {
    _ => fail("expected oversized fit rejection")
  }
}

///|
test "empty fits and a failed consensus produce explicit errors" {
  try @calibration.calibrate([]) catch {
    MissingAnchors => ()
    error => raise error
  } noraise {
    _ => fail("expected missing anchors rejection")
  }
  let inconsistent : Array[@calibration.Anchor] = [
    { device_us: 0L, reference_us: 0L, },
    { device_us: 1L, reference_us: 10L, },
    { device_us: 2L, reference_us: 100L, },
    { device_us: 3L, reference_us: 1000L, },
  ]
  try @calibration.calibrate(inconsistent, tolerance_us=0.01) catch {
    NoConsensus => ()
    error => raise error
  } noraise {
    _ => fail("expected insufficient consensus rejection")
  }
}
