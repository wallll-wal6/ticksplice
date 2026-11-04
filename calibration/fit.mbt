///|
priv struct Sample {
  x : Double
  y : Double
}

///|
fn median(values : Array[Double]) -> Double {
  values.sort()
  let middle = values.length() / 2
  if values.length() % 2 == 0 {
    (values[middle - 1] + values[middle]) / 2.0
  } else {
    values[middle]
  }
}

///|
fn seed(samples : Array[Sample]) -> (Double, Double) {
  let slopes = []
  for i in 0..<samples.length() {
    for j in (i + 1)..<samples.length() {
      slopes.push((samples[j].y - samples[i].y) / (samples[j].x - samples[i].x))
    }
  }
  let rate = median(slopes)
  let intercept = median(samples.map(fn(p) { p.y - rate * p.x }))
  (rate, intercept)
}

///|
fn least_squares(samples : Array[Sample]) -> (Double, Double) {
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  for p in samples {
    sum_x += p.x
    sum_y += p.y
  }
  let mean_x = sum_x / samples.length().to_double()
  let mean_y = sum_y / samples.length().to_double()
  let mut covariance = 0.0
  let mut variance = 0.0
  for p in samples {
    let dx = p.x - mean_x
    covariance += dx * (p.y - mean_y)
    variance += dx * dx
  }
  let rate = covariance / variance
  (rate, mean_y - rate * mean_x)
}

///|
/// Fit paired events with a Theil–Sen seed and a least-squares refit.
/// The tolerance is the maximum accepted absolute residual in microseconds.
pub fn calibrate(
  anchors : ArrayView[Anchor],
  tolerance_us~ : Double = 1000.0,
  min_span_us~ : Int64 = 0L,
) -> Calibration raise FitError {
  guard tolerance_us > 0.0 && tolerance_us <= max_timestamp.to_double() else {
    raise InvalidTolerance
  }
  guard valid_timestamp(min_span_us) else { raise InvalidMinimumSpan }
  let count = anchors.length()
  guard count > 0 else { raise MissingAnchors }
  guard count <= 256 else { raise TooManyAnchors }
  let ordered = anchors.to_owned()
  ordered.sort_by(fn(a, b) { a.device_us.compare(b.device_us) })
  for i in 0..<count {
    let a = ordered[i]
    guard valid_timestamp(a.device_us) && valid_timestamp(a.reference_us) else {
      raise InvalidTimestamp
    }
    if i > 0 && a.device_us == ordered[i - 1].device_us {
      raise DuplicateDeviceTime(a.device_us)
    }
  }
  let origin = ordered[0]
  if count == 1 {
    if min_span_us > 0L {
      raise InsufficientSpan(0L, min_span_us)
    }
    return {
      clock: {
        device_origin: origin.device_us,
        reference_origin: origin.reference_us,
        intercept: 0.0,
        rate: 1.0,
        first: origin.device_us,
        last: origin.device_us,
        offset_only: true,
      },
      evidence: [{ anchor: origin, residual_us: 0.0, accepted: true, }],
    }
  }
  let samples = ordered.map(fn(a) {
    {
      x: (a.device_us - origin.device_us).to_double(),
      y: (a.reference_us - origin.reference_us).to_double(),
    }
  })
  let (seed_rate, seed_intercept) = seed(samples)
  let inliers = samples.filter(fn(p) {
    (p.y - (seed_intercept + seed_rate * p.x)).abs() <= tolerance_us
  })
  guard inliers.length() >= 2 && inliers.length() > count / 2 else {
    raise NoConsensus
  }
  let (rate, intercept) = least_squares(inliers)
  guard rate > 0.0 else { raise NonMonotonicClock }
  let evidence = []
  let mut first = origin.device_us
  let mut last = first
  let mut accepted = 0
  for i in 0..<count {
    let p = samples[i]
    let residual = p.y - (intercept + rate * p.x)
    let within = residual.abs() <= tolerance_us
    if within {
      if accepted == 0 {
        first = ordered[i].device_us
      }
      last = ordered[i].device_us
      accepted += 1
    }
    evidence.push({
      anchor: ordered[i],
      residual_us: residual,
      accepted: within,
    })
  }
  guard accepted >= 2 && accepted > count / 2 else { raise NoConsensus }
  let span = last - first
  guard span >= min_span_us else { raise InsufficientSpan(span, min_span_us) }
  {
    clock: {
      device_origin: origin.device_us,
      reference_origin: origin.reference_us,
      intercept,
      rate,
      first,
      last,
      offset_only: false,
    },
    evidence: ReadOnlyArray::from_array(evidence),
  }
}
