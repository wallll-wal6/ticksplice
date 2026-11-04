///|
fn audit(result : @calibration.Calibration, tolerance : Double) -> Json {
  let anchors : Array[Json] = []
  for item in result.evidence {
    anchors.push({
      "device_us": Json::number(item.anchor.device_us.to_double()),
      "reference_us": Json::number(item.anchor.reference_us.to_double()),
      "residual_us": Json::number(item.residual_us),
      "accepted": Json::boolean(item.accepted),
    })
  }
  let drift = result.clock.drift_ppm()
  let (first, last) = result.clock.coverage()
  {
    "model": if drift is None {
      "offset"
    } else {
      "affine"
    },
    "drift_ppm": match drift {
      Some(value) => Json::number(value)
      None => Json::null()
    },
    "tolerance_us": Json::number(tolerance),
    "coverage_device_us": [
      Json::number(first.to_double()),
      Json::number(last.to_double()),
    ],
    "offset_at_coverage_start_us": Json::number(
      result.clock.offset_at_coverage_start_us(),
    ),
    "anchors": Json::array(anchors),
  }
}
