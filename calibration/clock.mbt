///|
/// A matched event from the device and reference clocks, in integer microseconds.
pub(all) struct Anchor {
  device_us : Int64
  reference_us : Int64
}

///|
pub suberror FitError {
  InvalidTimestamp
  InvalidTolerance
  MissingAnchors
  TooManyAnchors
  DuplicateDeviceTime(Int64)
  NoConsensus
  NonMonotonicClock
  ProjectionOutOfRange
}

///|
pub struct ClockMap {
  device_origin : Int64
  reference_origin : Int64
  intercept : Double
  rate : Double
  first : Int64
  last : Int64
  offset_only : Bool
}

///|
pub struct Evidence {
  anchor : Anchor
  residual_us : Double
  accepted : Bool
}

///|
pub struct Calibration {
  clock : ClockMap
  evidence : ReadOnlyArray[Evidence]
}

///|
let max_timestamp : Int64 = 9007199254740991L

///|
fn valid_timestamp(value : Int64) -> Bool {
  value >= 0L && value <= max_timestamp
}

///|
pub fn ClockMap::drift_ppm(self : ClockMap) -> Double? {
  if self.offset_only {
    None
  } else {
    Some((self.rate - 1.0) * 1_000_000.0)
  }
}

///|
pub fn ClockMap::is_extrapolated(self : ClockMap, device_us : Int64) -> Bool {
  device_us < self.first || device_us > self.last
}

///|
/// Project a device timestamp to the nearest reference microsecond.
pub fn ClockMap::project(
  self : ClockMap,
  device_us : Int64,
) -> Int64 raise FitError {
  guard valid_timestamp(device_us) else { raise InvalidTimestamp }
  let delta = self.intercept +
    self.rate * (device_us - self.device_origin).to_double()
  let lower = -self.reference_origin
  let upper = max_timestamp - self.reference_origin
  guard delta >= lower.to_double() && delta <= upper.to_double() else {
    raise ProjectionOutOfRange
  }
  self.reference_origin + delta.round().to_int64()
}
