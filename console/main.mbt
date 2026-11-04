///|
let usage : String =
  #|TickSplice · 时缝
  #|  audit ANCHORS.csv [TOLERANCE_US]
  #|  apply ANCHORS.csv CAPTURE.csv [TOLERANCE_US]
  #|  score ANCHORS.csv HOLDOUT.csv [TOLERANCE_US]
  #|Default residual tolerance is 1000 microseconds.
  #|audit and score write JSON. apply writes CSV to standard output.

///|
extern "js" fn stderr(message : String) -> Unit =
  #| (message) => { process.exitCode = 1; process.stderr.write(message + "\n"); }

///|
extern "js" fn stdout(message : String) -> Unit =
  #| (message) => process.stdout.write(message)

///|
fn tolerance_arg(args : ArrayView[String]) -> Double raise InputError {
  match args {
    [] => 1000.0
    [arg] => @string.parse_double(arg) catch { _ => raise BadTolerance }
    _ => raise BadArguments
  }
}

///|
fn run(args : ArrayView[String]) -> Unit raise {
  match args {
    [] | ["--help"] => println(usage)
    ["audit", path, .. rest] => {
      let tolerance = tolerance_arg(rest)
      let result = @calibration.calibrate(
        read_anchors(@fs.read_file_to_string(path)),
        tolerance_us=tolerance,
      )
      println(audit(result, tolerance).stringify())
    }
    ["apply", anchors, capture, .. rest] => {
      let tolerance = tolerance_arg(rest)
      let result = @calibration.calibrate(
        read_anchors(@fs.read_file_to_string(anchors)),
        tolerance_us=tolerance,
      )
      stdout(project_capture(@fs.read_file_to_string(capture), result.clock))
    }
    ["score", anchors, holdout, .. rest] => {
      let tolerance = tolerance_arg(rest)
      let result = @calibration.calibrate(
        read_anchors(@fs.read_file_to_string(anchors)),
        tolerance_us=tolerance,
      )
      let report = score(result, read_anchors(@fs.read_file_to_string(holdout)))
      println(report.stringify())
    }
    _ => raise BadArguments
  }
}

///|
fn main {
  run(@env.args()[2:]) catch {
    error => stderr("ticksplice: \{error}")
  }
}
