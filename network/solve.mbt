///|
priv struct Path {
  transform : Transform
  clocks : ReadOnlyArray[String]
  link_ids : ReadOnlyArray[Int32]
}

///|
priv struct Edge {
  id : Int32
  source : String
  target : String
  forward : Transform
  reverse : Transform
  retained : Int32
  rejected : Int32
}

///|
priv struct Arc {
  id : Int32
  neighbor : String
  into_parent : Transform
}

///|
fn remember_clock(
  origins : Map[String, Int64],
  clock : String,
  time : Int64,
) -> Unit {
  match origins.get(clock) {
    Some(old) if old <= time => ()
    _ => origins[clock] = time
  }
}

///|
fn fit_edges(
  links : ArrayView[Link],
  tolerance_us : Double,
) -> (Array[@calibration.Calibration], Map[String, Int64]) raise NetworkError {
  let fits = []
  let origins : Map[String, Int64] = Map([])
  for i, link in links {
    guard !link.source.is_empty() else { raise InvalidClock(link.source) }
    guard !link.target.is_empty() else { raise InvalidClock(link.target) }
    guard link.source != link.target else { raise SelfLink(i + 1) }
    let fit = @calibration.calibrate(link.anchors, tolerance_us~) catch {
      error => raise LinkFitFailed(i + 1, error)
    }
    guard !fit.clock.offset_only else { raise OffsetOnlyLink(i + 1) }
    for evidence in fit.evidence {
      if evidence.accepted {
        remember_clock(origins, link.source, evidence.anchor.device_us)
        remember_clock(origins, link.target, evidence.anchor.reference_us)
      }
    }
    guard origins.length() <= 64 else { raise TooManyClocks }
    fits.push(fit)
  }
  (fits, origins)
}

///|
fn make_edge(
  id : Int32,
  link : Link,
  fit : @calibration.Calibration,
  origins : Map[String, Int64],
) -> Edge raise NetworkError {
  let source_origin = origins[link.source]
  let target_origin = origins[link.target]
  let clock = fit.clock
  let rate = clock.rate
  let offset = (clock.reference_origin - target_origin).to_double() +
    clock.intercept +
    rate * (source_origin - clock.device_origin).to_double()
  let forward = transform(
    rate,
    offset,
    Some({
      lower: (clock.first - source_origin).to_double(),
      upper: (clock.last - source_origin).to_double(),
    }),
  )
  let mut retained = 0
  let mut first_target = max_timestamp
  let mut last_target = 0L
  for item in fit.evidence {
    if item.accepted {
      retained += 1
      let time = item.anchor.reference_us
      if time < first_target {
        first_target = time
      }
      if time > last_target {
        last_target = time
      }
    }
  }
  {
    id,
    source: link.source,
    target: link.target,
    forward,
    reverse: forward.inverse({
      lower: (first_target - target_origin).to_double(),
      upper: (last_target - target_origin).to_double(),
    }),
    retained,
    rejected: fit.evidence.length() - retained,
  }
}

///|
fn check_cycle(
  edge : Edge,
  from_path : Path,
  to_path : Path,
  tolerance : Double,
) -> CycleCheck raise NetworkError {
  let alternative = edge.forward.then(to_path.transform)
  guard from_path.transform.span is Some(a) &&
    alternative.span is Some(b) &&
    intersect(a, b) is Some(overlap) &&
    overlap.lower < overlap.upper else {
    return { link_id: edge.id, status: NoSharedCoverage, max_gap_us: None, }
  }
  // The difference of the two affine maps is affine. Its largest absolute
  // value over this interval is attained at an endpoint.
  let rate = from_path.transform.rate - alternative.rate
  let offset = from_path.transform.offset - alternative.offset
  let start_gap = (rate * overlap.lower + offset).abs()
  let end_gap = (rate * overlap.upper + offset).abs()
  let gap = if start_gap > end_gap { start_gap } else { end_gap }
  guard finite(start_gap) && finite(end_gap) else {
    raise UnrepresentableTransform
  }
  {
    link_id: edge.id,
    status: if gap > tolerance {
      Conflict
    } else {
      Consistent
    },
    max_gap_us: Some(gap),
  }
}

///|
/// Align a reference component using minimum-hop paths and audit redundant
/// links over shared coverage. Input link order breaks shortest-path ties.
pub fn solve(
  reference : String,
  links : ArrayView[Link],
  tolerance_us~ : Double = 1000.0,
  cycle_tolerance_us~ : Double = 1000.0,
) -> Network raise NetworkError {
  guard cycle_tolerance_us >= 0.0 &&
    cycle_tolerance_us <= max_timestamp.to_double() else {
    raise InvalidCycleTolerance
  }
  guard links.length() <= 256 else { raise TooManyLinks }
  let (fits, origins) = fit_edges(links, tolerance_us)
  guard origins.get(reference) is Some(reference_origin) else {
    raise MissingReference(reference)
  }
  let adj : Map[String, Array[Arc]] = Map([])
  for clock, _ in origins {
    adj[clock] = []
  }
  let edges = []
  for i, link in links {
    let edge = make_edge(i + 1, link, fits[i], origins)
    edges.push(edge)
    adj[link.target].push({
      id: edge.id,
      neighbor: link.source,
      into_parent: edge.forward,
    })
    adj[link.source].push({
      id: edge.id,
      neighbor: link.target,
      into_parent: edge.reverse,
    })
  }

  let root : Path = {
    transform: { rate: 1.0, offset: 0.0, span: Some(domain(reference_origin)), },
    clocks: [reference],
    link_ids: [],
  }
  let paths : Map[String, Path] = Map([(reference, root)])
  let tree : Set[Int32] = Set([])
  let queue = [reference]
  let mut head = 0
  while head < queue.length() {
    let parent = queue[head]
    let path = paths[parent]
    head += 1
    for arc in adj[parent] {
      if !paths.contains(arc.neighbor) {
        paths[arc.neighbor] = {
          transform: if parent == reference {
            arc.into_parent
          } else {
            arc.into_parent.then(path.transform)
          },
          clocks: ReadOnlyArray::from_array([arc.neighbor, ..path.clocks]),
          link_ids: ReadOnlyArray::from_array([arc.id, ..path.link_ids]),
        }
        tree.add(arc.id)
        queue.push(arc.neighbor)
      }
    }
  }

  let routes : Array[RouteInfo] = []
  let disconnected = []
  for clock, origin in origins {
    match paths.get(clock) {
      Some(path) =>
        routes.push({
          clock,
          path: path.clocks,
          link_ids: path.link_ids,
          coverage_us: coverage_us(path.transform.span, origin),
        })
      None => disconnected.push(clock)
    }
  }
  let mut conflict_count = 0
  let cycles = []
  let link_info : Array[LinkInfo] = []
  for edge in edges {
    let tree_edge = tree.contains(edge.id)
    link_info.push({
      id: edge.id,
      source: edge.source,
      target: edge.target,
      retained: edge.retained,
      rejected: edge.rejected,
      tree_edge,
    })
    if !tree_edge &&
      paths.get(edge.source) is Some(a) &&
      paths.get(edge.target) is Some(b) {
      let check = check_cycle(edge, a, b, cycle_tolerance_us)
      if check.status is Conflict {
        conflict_count += 1
      }
      cycles.push(check)
    }
  }
  {
    reference,
    routes: ReadOnlyArray::from_array(routes),
    disconnected: ReadOnlyArray::from_array(disconnected),
    links: ReadOnlyArray::from_array(link_info),
    cycles: ReadOnlyArray::from_array(cycles),
    conflict_count,
    origins,
    paths,
  }
}
