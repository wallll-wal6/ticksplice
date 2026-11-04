///|
suberror ScoreError {
  EmptyHoldout
  MissingBaseline
  OverlappingHoldout(Int64)
}

///|
fn summarize(errors : Array[Double]) -> Json {
  errors.sort()
  let count = errors.length()
  let middle = count / 2
  let median = if count % 2 == 0 {
    (errors[middle - 1] + errors[middle]) / 2.0
  } else {
    errors[middle]
  }
  {
    "median_absolute_us": median.to_json(),
    "max_absolute_us": errors[count - 1].to_json(),
  }
}

///|
fn score(
  result : @calibration.Calibration,
  holdout : ArrayView[@calibration.Anchor],
) -> Json raise {
  guard !holdout.is_empty() else { raise EmptyHoldout }
  let used : Set[Int64] = Set([])
  let mut offset = None
  for item in result.evidence {
    used.add(item.anchor.device_us)
    if item.accepted && offset is None {
      offset = Some(item.anchor.reference_us - item.anchor.device_us)
    }
  }
  guard offset is Some(baseline_offset) else { raise MissingBaseline }
  let baseline = []
  let calibrated = []
  let mut extrapolated = 0
  for pair in holdout {
    let device = pair.device_us
    if used.contains(device) {
      raise OverlappingHoldout(device)
    }
    used.add(device)
    let projected = result.clock.project(device)
    baseline.push(
      (pair.reference_us - device - baseline_offset).abs().to_double(),
    )
    calibrated.push((pair.reference_us - projected).abs().to_double())
    if result.clock.is_extrapolated(device) {
      extrapolated += 1
    }
  }
  {
    "events": holdout.length().to_json(),
    "extrapolated_events": extrapolated.to_json(),
    "offset_only": summarize(baseline),
    "calibrated": summarize(calibrated),
  }
}
