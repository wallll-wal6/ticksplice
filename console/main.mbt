///|
let usage : String =
  #|TickSplice · 时缝
  #|  audit ANCHORS.csv [TOLERANCE_US]
  #|  apply ANCHORS.csv CAPTURE.csv [TOLERANCE_US]
  #|  score ANCHORS.csv HOLDOUT.csv [TOLERANCE_US]
  #|Append --min-span-us N to require a minimum accepted anchor span.
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
fn fit_file(
  path : String,
  args : ArrayView[String],
) -> (@calibration.Calibration, Double) raise {
  let (tolerance, span) = match args {
    ["--min-span-us", span] => (1000.0, span_arg(span))
    [tolerance, "--min-span-us", span] =>
      (tolerance_arg([tolerance]), span_arg(span))
    _ => (tolerance_arg(args), 0L)
  }
  let fit = @calibration.calibrate(
    read_anchors(read_input(path)),
    tolerance_us=tolerance,
    min_span_us=span,
  )
  (fit, tolerance)
}

///|
fn span_arg(value : String) -> Int64 raise InputError {
  timestamp(value, 0, "min-span-us") catch {
    _ => raise BadMinimumSpan
  }
}

///|
fn run(args : ArrayView[String]) -> Unit raise {
  match args {
    [] | ["--help"] => println(usage)
    ["audit", path, .. rest] => {
      let (result, tolerance) = fit_file(path, rest)
      println(audit(result, tolerance).stringify())
    }
    ["apply", anchors, capture, .. rest] => {
      let (result, _) = fit_file(anchors, rest)
      stdout(project_capture(read_input(capture), result.clock))
    }
    ["score", anchors, holdout, .. rest] => {
      let (result, _) = fit_file(anchors, rest)
      let report = score(result, read_anchors(read_input(holdout)))
      println(report.stringify())
    }
    _ => raise BadArguments
  }
}

///|
fn main {
  run(@env.args()[2:]) catch {
    error => stderr("ticksplice: \{diagnostic(error)}")
  }
}
