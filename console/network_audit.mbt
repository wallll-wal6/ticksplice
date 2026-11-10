///|
fn network_audit(result : @network.Network, cycle_tolerance : Double) -> Json {
  let routes : Array[Json] = []
  for route in result.routes {
    let path : Array[Json] = []
    for clock in route.path {
      path.push(Json::string(clock))
    }
    let ids : Array[Json] = []
    for id in route.link_ids {
      ids.push(Json::number(id.to_double()))
    }
    routes.push({
      "clock": Json::string(route.clock),
      "path": Json::array(path),
      "link_ids": Json::array(ids),
      "coverage_us": match route.coverage_us {
        Some((first, last)) =>
          [Json::number(first.to_double()), Json::number(last.to_double())]
        None => Json::null()
      },
    })
  }
  let disconnected : Array[Json] = []
  for clock in result.disconnected {
    disconnected.push(Json::string(clock))
  }
  let links : Array[Json] = []
  for link in result.links {
    links.push({
      "id": Json::number(link.id.to_double()),
      "from": Json::string(link.source),
      "to": Json::string(link.target),
      "retained": Json::number(link.retained.to_double()),
      "rejected": Json::number(link.rejected.to_double()),
      "tree_edge": Json::boolean(link.tree_edge),
    })
  }
  let cycles : Array[Json] = []
  for check in result.cycles {
    cycles.push({
      "link_id": Json::number(check.link_id.to_double()),
      "status": match check.status {
        Consistent => "consistent"
        Conflict => "conflict"
        NoSharedCoverage => "no_shared_coverage"
      },
      "max_gap_us": match check.max_gap_us {
        Some(gap) => Json::number(gap)
        None => Json::null()
      },
    })
  }
  {
    "reference": Json::string(result.reference),
    "cycle_tolerance_us": Json::number(cycle_tolerance),
    "conflict_count": Json::number(result.conflict_count.to_double()),
    "routes": Json::array(routes),
    "disconnected": Json::array(disconnected),
    "links": Json::array(links),
    "cycles": Json::array(cycles),
  }
}

///|
fn solve_network(
  reference : String,
  path : String,
  args : ArrayView[String],
) -> (@network.Network, Double) raise {
  let (fit_tol, cycle_tol) = match args {
    [fit, cycle] => (tolerance_arg([fit]), tolerance_arg([cycle]))
    _ => (tolerance_arg(args), 1000.0)
  }
  let result = @network.solve(
    reference,
    read_links(read_input(path)),
    tolerance_us=fit_tol,
    cycle_tolerance_us=cycle_tol,
  )
  (result, cycle_tol)
}
