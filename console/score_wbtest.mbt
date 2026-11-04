///|
test "held-out events expose accumulated error in the offset baseline" {
  let fit = @calibration.calibrate([
    { device_us: 0L, reference_us: 200L, },
    { device_us: 10_000L, reference_us: 10_210L, },
  ])
  let report = score(fit, [
    { device_us: 5_000L, reference_us: 5_205L, },
    { device_us: 15_000L, reference_us: 15_215L, },
  ])
  json_inspect(report, content={
    "events": 2,
    "extrapolated_events": 1,
    "offset_only": { "median_absolute_us": 10, "max_absolute_us": 15 },
    "calibrated": { "median_absolute_us": 0, "max_absolute_us": 0 },
  })
}

///|
test "holdout cannot include a training anchor" {
  let anchor : @calibration.Anchor = { device_us: 10L, reference_us: 20L, }
  let fit = @calibration.calibrate([anchor])
  try score(fit, [anchor]) catch {
    OverlappingHoldout(10L) => ()
    error => raise error
  } noraise {
    _ => fail("expected holdout leakage error")
  }
}
