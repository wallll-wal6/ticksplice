///|
test "report absent drift as JSON null in offset-only mode" {
  let result = @calibration.calibrate([{ device_us: 100L, reference_us: 90L, }])
  json_inspect(audit(result, 1000.0), content={
    "model": "offset",
    "drift_ppm": null,
    "tolerance_us": 1000,
    "coverage_span_us": 0,
    "coverage_device_us": [100, 100],
    "offset_at_coverage_start_us": -10,
    "anchors": [
      {
        "device_us": 100,
        "reference_us": 90,
        "residual_us": 0,
        "accepted": true,
      },
    ],
  })
}
