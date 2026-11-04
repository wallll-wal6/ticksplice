///|
test "negative drift stays within the holdout budget despite jitter and mismatches" {
  let epoch = 1_750_000_000_000_000L
  let anchors : Array[@calibration.Anchor] = []
  let jitter : Array[Int64] = [
    12L, -22L, 8L, 31L, -16L, 2L, -6L, 19L, -28L, 10L, -4L,
  ]
  for i, noise in jitter {
    let elapsed = i.to_int64() * 10_000_000L
    let mismatch = match i {
      2 => 90_000L
      8 => -80_000L
      _ => 0L
    }
    anchors.push({
      device_us: epoch + elapsed,
      reference_us: epoch +
      elapsed -
      elapsed / 4000L -
      180_000L +
      noise +
      mismatch,
    })
  }
  let fit = @calibration.calibrate(anchors, tolerance_us=100.0)
  assert_true((fit.clock.drift_ppm().unwrap() + 250.0).abs() <= 0.5)
  for i, item in fit.evidence {
    assert_eq(item.accepted, i != 2 && i != 8)
  }
  let holdout : Array[Int64] = [5_000_000L, 45_000_000L, 95_000_000L]
  for elapsed in holdout {
    let truth = epoch + elapsed - elapsed / 4000L - 180_000L
    assert_true((fit.clock.project(epoch + elapsed) - truth).abs() <= 35L)
  }
}
