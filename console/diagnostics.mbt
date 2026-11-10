///|
fn read_input(path : String) -> String raise InputError {
  let bytes = @fs.read_file_to_bytes(path) catch {
    _ => raise UnreadableInput(path)
  }
  decode_input(bytes)
}

///|
fn decode_input(bytes : BytesView) -> String raise InputError {
  @utf8.decode(bytes) catch {
    _ => raise InvalidUtf8
  }
}

///|
fn diagnostic(error : Error) -> String {
  match error {
    BadCsv(record, reason) => "CSV record \{record}: \{reason}"
    BadTimestamp(record, column) =>
      "CSV record \{record}: \{column} must be a nonnegative integer in the supported microsecond range"
    BadHeader(reason) => "CSV header: \{reason}"
    BadWidth(record) => "CSV record \{record}: field count differs from header"
    BadTolerance | @calibration.InvalidTolerance =>
      "residual tolerance must be finite, positive and at most 9007199254740991 microseconds"
    BadArguments =>
      "invalid arguments; use --help to see the available commands"
    UnreadableInput(path) => "cannot read input file: \{path}"
    InvalidUtf8 => "input must be valid UTF-8; export the capture as UTF-8 CSV"
    EmptyHoldout => "the holdout file has no events"
    MissingBaseline => "the fit has no accepted anchor for the offset baseline"
    OverlappingHoldout(device) =>
      "device timestamp \{device} appears more than once across the fit and holdout inputs"
    BadMinimumSpan | @calibration.InvalidMinimumSpan =>
      "minimum span must be a nonnegative integer in the supported microsecond range"
    @calibration.InsufficientSpan(actual, minimum) =>
      "accepted anchor span is \{actual} us; required at least \{minimum} us"
    @calibration.MissingAnchors => "the anchor file has no events"
    @calibration.TooManyAnchors => "at most 256 anchors are supported"
    @calibration.DuplicateDeviceTime(device) =>
      "multiple anchors share device timestamp \{device}"
    @calibration.InvalidTimestamp =>
      "a timestamp is outside the supported microsecond range"
    @calibration.NoConsensus =>
      "fewer than two anchors or no majority of anchors fit within tolerance"
    @calibration.NonMonotonicClock =>
      "the fitted reference clock does not advance"
    @calibration.ProjectionOutOfRange =>
      "a projected timestamp falls outside the supported microsecond range"
    NetworkConflict(count) =>
      "network has \{count} conflicting cycle(s); run network-audit"
    @network.InvalidClock(clock) => "invalid clock ID: \{clock}"
    @network.MissingReference(clock) => "reference clock \{clock} has no links"
    @network.SelfLink(id) => "link \{id} connects a clock session to itself"
    @network.TooManyLinks => "network supports at most 256 links"
    @network.TooManyClocks => "network supports at most 64 clock sessions"
    @network.OffsetOnlyLink(id) =>
      "link \{id} requires at least two matched events"
    @network.LinkFitFailed(id, cause) => "link \{id}: \{diagnostic(cause)}"
    @network.InvalidCycleTolerance =>
      "cycle tolerance must be nonnegative and in the microsecond range"
    @network.UnknownClock(clock) =>
      "capture contains unknown clock session \{clock}"
    @network.InvalidNetworkTimestamp =>
      "network timestamp is outside the supported microsecond range"
    @network.UnrepresentableTransform =>
      "network mapping or projected timestamp is out of range"
    @network.InconsistentNetwork =>
      "projection blocked by conflicting clock routes"
    _ => "unexpected failure: \{error}"
  }
}
