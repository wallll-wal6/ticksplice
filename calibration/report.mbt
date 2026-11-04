///|
/// Inclusive device-time range covered by the retained anchors.
pub fn ClockMap::coverage(self : ClockMap) -> (Int64, Int64) {
  (self.first, self.last)
}

///|
/// Reference minus device time at the first retained anchor, before rounding.
pub fn ClockMap::offset_at_coverage_start_us(self : ClockMap) -> Double {
  (self.reference_origin - self.device_origin).to_double() +
  self.intercept +
  (self.rate - 1.0) * (self.first - self.device_origin).to_double()
}

///|
/// Elapsed device microseconds between the first and last retained anchors.
pub fn ClockMap::coverage_span_us(self : ClockMap) -> Int64 {
  self.last - self.first
}
