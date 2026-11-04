///|
fn read_input(path : String) -> String raise InputError {
  @fs.read_file_to_string(path) catch {
    _ => raise UnreadableInput(path)
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
    EmptyHoldout => "the holdout file has no events"
    MissingBaseline => "the fit has no accepted anchor for the offset baseline"
    OverlappingHoldout(device) =>
      "device timestamp \{device} appears more than once across the fit and holdout inputs"
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
    _ => "unexpected failure: \{error}"
  }
}
