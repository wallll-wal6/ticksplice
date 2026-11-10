# 多设备时钟图 API

导入 `wallll-wal6/ticksplice/network`。每条边输入两台设备会话间已经配对的事件。
校准完成后，调用者可以查阅所选路径、支持区间和冗余边检查，再换算采集记录。

```mbt check
///|
test "align a sensor that only shares events with a gateway" {
  let links : Array[@network.Link] = [
    {
      source: "gateway",
      target: "ref",
      anchors: [
        { device_us: 100L, reference_us: 200L, },
        { device_us: 1100L, reference_us: 1200L, },
      ],
    },
    {
      source: "sensor",
      target: "gateway",
      anchors: [
        { device_us: 0L, reference_us: 100L, },
        { device_us: 1000L, reference_us: 1100L, },
      ],
    },
  ]
  let network = @network.solve("ref", links)
  assert_eq(network.conflict_count, 0)
  let sample = network.project("sensor", 500L).unwrap()
  assert_eq(sample.reference_us, 700L)
  assert_false(sample.extrapolated)
  assert_true(network.project("sensor", 1200L).unwrap().extrapolated)
}
```

同一输入顺序下，求解器选取可复现的最少跳路径。调用者可从 `routes` 读取节点和链路编号，
从 `cycles` 查看未选入树的冗余边是否可比较及最大差值。存在已检测到的冲突时，
`project` 会拒绝换算。已知但不在参考分量中的时钟返回 `None`，未知 ID 则报错。
