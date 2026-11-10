///|
// Each oriented pair is one fitted edge. First appearance assigns the link ID.
fn read_links(text : String) -> Array[@network.Link] raise InputError {
  guard read_csv(text) is [["from", "to", "from_us", "to_us"], .. rows] else {
    raise BadHeader("expected from,to,from_us,to_us")
  }
  let links : Array[@network.Link] = []
  let groups : Map[(String, String), Int32] = Map([])
  for i, row in rows {
    let record = i + 2
    guard row is [source, target, a, b] else { raise BadWidth(record) }
    let anchor : @calibration.Anchor = {
      device_us: timestamp(a, record, "from_us"),
      reference_us: timestamp(b, record, "to_us"),
    }
    let key = (source, target)
    match groups.get(key) {
      Some(id) => links[id].anchors.push(anchor)
      None => {
        groups[key] = links.length()
        links.push({ source, target, anchors: [anchor], })
      }
    }
  }
  links
}

///|
fn network_capture(text : String, result : @network.Network) -> String raise {
  guard result.conflict_count == 0 else {
    raise NetworkConflict(result.conflict_count)
  }
  guard read_csv(text) is [header, .. rows] &&
    header is ["clock", "device_us", ..] else {
    raise BadHeader("capture header must start with clock,device_us")
  }
  validate_columns(header, ["reference_us", "alignment"])
  let output = StringBuilder()
  write_record(output, [..header, "reference_us", "alignment"])
  for i, row in rows {
    guard row.length() == header.length() else { raise BadWidth(i + 2) }
    let time = timestamp(row[1], i + 2, "device_us")
    let (reference, status) = match result.project(row[0], time) {
      None => ("", "disconnected")
      Some(p) =>
        (
          p.reference_us.to_string(),
          if p.extrapolated {
            "extrapolated"
          } else {
            "covered"
          },
        )
    }
    write_record(output, [..row, reference, status])
  }
  output.to_string()
}
