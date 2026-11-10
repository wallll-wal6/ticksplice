///|
/// Matched events for an oriented edge between two clock sessions.
pub(all) struct Link {
  source : String
  target : String
  anchors : Array[@calibration.Anchor]
}

///|
pub suberror NetworkError {
  InvalidClock(String)
  MissingReference(String)
  SelfLink(Int32)
  TooManyLinks
  TooManyClocks
  OffsetOnlyLink(Int32)
  LinkFitFailed(Int32, @calibration.FitError)
  InvalidCycleTolerance
  UnknownClock(String)
  InvalidNetworkTimestamp
  UnrepresentableTransform
  InconsistentNetwork
}

///|
pub struct RouteInfo {
  clock : String
  path : ReadOnlyArray[String]
  link_ids : ReadOnlyArray[Int32]
  coverage_us : (Int64, Int64)?
}

///|
pub struct LinkInfo {
  id : Int32
  source : String
  target : String
  retained : Int32
  rejected : Int32
  tree_edge : Bool
}

///|
pub(all) enum CycleStatus {
  Consistent
  Conflict
  NoSharedCoverage
}

///|
pub struct CycleCheck {
  link_id : Int32
  status : CycleStatus
  max_gap_us : Double?
}

///|
pub struct Projection {
  reference_us : Int64
  extrapolated : Bool
}

///|
pub struct Network {
  reference : String
  routes : ReadOnlyArray[RouteInfo]
  disconnected : ReadOnlyArray[String]
  links : ReadOnlyArray[LinkInfo]
  cycles : ReadOnlyArray[CycleCheck]
  conflict_count : Int32
  priv origins : Map[String, Int64]
  priv paths : Map[String, Path]
}

///|
let max_timestamp : Int64 = 9_007_199_254_740_991L

///|
/// Convert a reading using the selected route. A known clock outside the
/// reference component returns None. Conflicting cycles block projection.
pub fn Network::project(
  self : Network,
  clock : String,
  device_us : Int64,
) -> Projection? raise NetworkError {
  guard self.conflict_count == 0 else { raise InconsistentNetwork }
  guard device_us >= 0L && device_us <= max_timestamp else {
    raise InvalidNetworkTimestamp
  }
  guard self.origins.get(clock) is Some(origin) else {
    raise UnknownClock(clock)
  }
  guard self.paths.get(clock) is Some(path) else { return None }
  let elapsed = (device_us - origin).to_double()
  let delta = path.transform.at(elapsed).round()
  let reference_origin = self.origins[self.reference]
  guard delta >= (-reference_origin).to_double() &&
    delta <= (max_timestamp - reference_origin).to_double() else {
    raise UnrepresentableTransform
  }
  let covered = match path.transform.span {
    Some(span) => elapsed >= span.lower && elapsed <= span.upper
    None => false
  }
  Some({
    reference_us: reference_origin + delta.to_int64(),
    extrapolated: !covered,
  })
}
