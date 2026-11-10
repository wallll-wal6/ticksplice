///|
fn edge(
  from : String,
  to : String,
  times : Array[(Int64, Int64)],
) -> @network.Link {
  {
    source: from,
    target: to,
    anchors: times.map(fn(pair) {
      let (device_us, reference_us) = pair
      @calibration.Anchor::{ device_us, reference_us, }
    }),
  }
}

///|
test "compose inverse and forward drift without intermediate rounding" {
  let result = @network.solve("ref", [
    edge("ref", "gateway", [
      (0L, 100L),
      (1_000_000L, 1_001_100L),
      (2_000_000L, 2_002_100L),
    ]),
    edge("sensor", "gateway", [
      (0L, 200_300L),
      (1_000_000L, 1_202_301L),
      (2_000_000L, 2_204_302L),
    ]),
    edge("island", "peer", [(0L, 10L), (1_000_000L, 1_000_010L)]),
  ])
  let sensor = result.routes
    .iter()
    .find_first(fn(route) { route.clock == "sensor" })
    .unwrap()
  assert_true(sensor.path is ["sensor", "gateway", "ref"])
  assert_true(sensor.link_ids is [2, 1])
  assert_eq(sensor.coverage_us, Some((0L, 1_798_201L)))
  let projected = result.project("sensor", 1_000_000L).unwrap()
  assert_eq(projected.reference_us, 1_201_000L)
  assert_false(projected.extrapolated)
  let start = result.project("gateway", 100L).unwrap()
  assert_eq(start.reference_us, 0L)
  assert_false(start.extrapolated)
  assert_true(result.project("sensor", 2_000_000L).unwrap().extrapolated)
  assert_true(result.project("island", 10L) is None)
}

///|
test "a clean local fit can contradict the redundant route" {
  let result = @network.solve(
    "ref",
    [
      edge("a", "ref", [(0L, 100L), (1000L, 1100L)]),
      edge("b", "a", [(0L, 100L), (1000L, 1100L)]),
      edge("b", "ref", [(0L, 250L), (1000L, 1250L)]),
    ],
    tolerance_us=1.0,
    cycle_tolerance_us=10.0,
  )
  for link in result.links {
    assert_eq(link.rejected, 0)
  }
  assert_eq(result.conflict_count, 1)
  assert_true(result.cycles[0].status is Conflict)
  assert_eq(result.cycles[0].link_id, 2)
  assert_eq(result.cycles[0].max_gap_us, Some(50.0))
  try result.project("b", 500L) catch {
    InconsistentNetwork => ()
    error => raise error
  } noraise {
    _ => fail("conflicting network must block projection")
  }
}

///|
test "consistent alternate route has an observable shared interval" {
  let result = @network.solve(
    "ref",
    [
      edge("a", "ref", [(0L, 100L), (1000L, 1100L)]),
      edge("b", "a", [(0L, 100L), (1000L, 1100L)]),
      edge("b", "ref", [(0L, 200L), (1000L, 1200L)]),
    ],
    cycle_tolerance_us=0.0,
  )
  assert_eq(result.conflict_count, 0)
  assert_true(result.cycles[0].status is Consistent)
  assert_eq(result.cycles[0].max_gap_us, Some(0.0))
  assert_eq(result.project("b", 500L).unwrap().reference_us, 700L)
}

///|
test "disjoint evidence cannot confirm a redundant route" {
  let result = @network.solve("ref", [
    edge("a", "ref", [(0L, 0L), (1000L, 1000L)]),
    edge("b", "ref", [(0L, 0L), (1000L, 1000L)]),
    edge("b", "a", [(2000L, 2000L), (3000L, 3000L)]),
  ])
  assert_true(result.cycles[0].status is NoSharedCoverage)
  assert_true(result.cycles[0].max_gap_us is None)
}

///|
test "a multihop route may have no supported interval" {
  let result = @network.solve("ref", [
    edge("a", "ref", [(0L, 0L), (1000L, 1000L)]),
    edge("b", "a", [(0L, 2000L), (1000L, 3000L)]),
  ])
  let projected = result.project("b", 500L).unwrap()
  assert_eq(projected.reference_us, 2500L)
  assert_true(projected.extrapolated)
}

///|
test "a graph edge cannot assume drift from one matched event" {
  try @network.solve("ref", [edge("a", "ref", [(0L, 100L)])]) catch {
    OffsetOnlyLink(1) => ()
    error => raise error
  } noraise {
    _ => fail("expected the one-event link to be rejected")
  }
}

///|
test "unknown capture clocks are not treated as disconnected" {
  let result = @network.solve("ref", [
    edge("a", "ref", [(0L, 100L), (1000L, 1100L)]),
  ])
  try result.project("typo", 50L) catch {
    UnknownClock("typo") => ()
    error => raise error
  } noraise {
    _ => fail("unknown clock ID must be diagnosed")
  }
}
