# 将校准库接入采集工具

发布后可使用 `moon add wallll-wal6/ticksplice`，在调用包的 `moon.pkg` 中导入
`"wallll-wal6/ticksplice/calibration"`。当前也可通过本地模块依赖验证 API。
核心库接收事件对，不依赖 CSV 或文件系统。

```mbt check
///|
test "calibrate two clocks and inspect a projected event" {
  let anchors : Array[@calibration.Anchor] = [
    { device_us: 0L, reference_us: 250_000L, },
    { device_us: 10_000_000L, reference_us: 10_255_000L, },
    { device_us: 20_000_000L, reference_us: 20_260_000L, },
  ]
  let fit = @calibration.calibrate(
    anchors,
    tolerance_us=100.0,
    min_span_us=20_000_000L,
  )
  assert_eq(fit.clock.project(5_000_000L), 5_252_500L)
  assert_false(fit.clock.is_extrapolated(5_000_000L))
  assert_eq(fit.clock.coverage_span_us(), 20_000_000L)
  assert_true((fit.clock.drift_ppm().unwrap() - 500.0).abs() < 0.001)
}
```

`calibrate` 返回时钟映射和按设备时间排序的逐锚点证据。`project` 输出四舍五入到微秒的参考时间。
`is_extrapolated` 标记覆盖范围外的事件，`coverage` 返回保留锚点的首尾设备时间。
时间输入为 0 至 9007199254740991 的整数微秒。单个锚点只能确定偏移，漂移为 `None`。
默认不限制覆盖时长，调用者可通过 `min_span_us` 设置采集质量门槛。

稳健初值需要计算 n(n−1)/2 个斜率并排序，时间复杂度为 O(n² log n)，内存复杂度为 O(n²)，
最多接受 256 个同步锚点。原始采集记录可远多于锚点数量。残差阈值应依据同步事件定位误差设置，
最终拟合仍可能受高比例错配、非线性时钟和分布过于集中的锚点影响，建议检查独立留出事件。
