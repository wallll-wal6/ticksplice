///|
fn audit(result : @calibration.Calibration, tolerance : Double) -> Json {
  let anchors : Array[Json] = []
  for item in result.evidence {
    anchors.push({
      "device_us": item.anchor.device_us.to_double().to_json(),
      "reference_us": item.anchor.reference_us.to_double().to_json(),
      "residual_us": item.residual_us.to_json(),
      "accepted": item.accepted.to_json(),
    })
  }
  let drift = result.clock.drift_ppm()
  let (first, last) = result.clock.coverage()
  {
    "model": (if drift is None { "offset" } else { "affine" }).to_json(),
    "drift_ppm": match drift {
      Some(value) => value.to_json()
      None => Json::null()
    },
    "tolerance_us": tolerance.to_json(),
    "coverage_device_us": [
      first.to_double().to_json(),
      last.to_double().to_json(),
    ],
    "offset_at_coverage_start_us": result.clock
    .offset_at_coverage_start_us()
    .to_json(),
    "anchors": anchors.to_json(),
  }
}
