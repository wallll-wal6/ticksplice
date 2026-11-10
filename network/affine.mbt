///|
priv struct Span {
  lower : Double
  upper : Double
}

///|
priv struct Transform {
  rate : Double
  offset : Double
  span : Span?
}

///|
fn Transform::at(self : Transform, x : Double) -> Double {
  self.rate * x + self.offset
}

///|
fn finite(x : Double) -> Bool {
  !x.is_nan() && !x.is_inf()
}

///|
fn transform(
  rate : Double,
  offset : Double,
  span : Span?,
) -> Transform raise NetworkError {
  guard rate > 0.0 && finite(rate) && finite(offset) else {
    raise UnrepresentableTransform
  }
  { rate, offset, span, }
}

///|
fn domain(origin : Int64) -> Span {
  { lower: (-origin).to_double(), upper: (max_timestamp - origin).to_double(), }
}

///|
fn intersect(a : Span, b : Span) -> Span? {
  let lower = if a.lower > b.lower { a.lower } else { b.lower }
  let upper = if a.upper < b.upper { a.upper } else { b.upper }
  if lower <= upper {
    Some({ lower, upper, })
  } else {
    None
  }
}

///|
// Pull back coverage before intersecting. Timestamp rounding is done at output only.
fn Transform::then(
  self : Transform,
  next : Transform,
) -> Transform raise NetworkError {
  let span = match (self.span, next.span) {
    (Some(a), Some(b)) =>
      intersect(a, {
        lower: (b.lower - self.offset) / self.rate,
        upper: (b.upper - self.offset) / self.rate,
      })
    _ => None
  }
  transform(self.rate * next.rate, next.at(self.offset), span)
}

///|
fn Transform::inverse(
  self : Transform,
  observed : Span,
) -> Transform raise NetworkError {
  transform(1.0 / self.rate, -self.offset / self.rate, Some(observed))
}

///|
fn coverage_us(span : Span?, origin : Int64) -> (Int64, Int64)? {
  guard span is Some(interval) else { return None }
  let first = interval.lower.ceil().to_int64() + origin
  let last = interval.upper.floor().to_int64() + origin
  if first <= last {
    Some((first, last))
  } else {
    None
  }
}
