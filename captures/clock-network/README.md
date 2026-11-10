# 离线时钟图复现实验

数据为本项目构造的合成样例。令传感器时间为 s，参考时间为 r，网关时间为 g。
样例使用 r = 1.001s + 200000，g = 1.001r + 100，单位均为微秒。
先构造参考时钟和网关的同步记录，再构造传感器和网关的同步记录。所有值取样时均为整数。
`offline` 和 `peer` 是独立分量。样例随项目 MIT 许可证分发。

在仓库根目录执行：

```sh
moon run console --target js -- network-audit ref captures/clock-network/chain.csv 10 50
moon run console --target js -- network-apply ref captures/clock-network/chain.csv captures/clock-network/events.csv 10 50
moon run console --target js -- network-audit ref captures/clock-network/consistent.csv 10 50
moon run console --target js -- network-audit ref captures/clock-network/conflict.csv 10 50
moon run console --target js -- network-apply ref captures/clock-network/conflict.csv captures/clock-network/linked-events.csv 10 50
```

| 场景 | 可复验结果 |
| --- | --- |
| 稀疏同步链 | 传感器无直连参考边，路径为 sensor → gateway → ref，边编号为 2、1。读数 1000000 µs 换算为 1201000 µs，处于支持区间。2000000 µs 换算为 2202000 µs，标记为外推 |
| 分量隔离 | 同一批采集中的 offline 行原样保留，参考时间为空，状态为 disconnected |
| 冗余证据相符 | 增加传感器到参考的直连记录，备选路径在共同覆盖区间内相符 |
| 局部拟合正常、全图冲突 | 将直连边的参考读数统一加 500 µs。三条边各自均无剔除点，备选路径最大差值约 500 µs，超过 50 µs 门槛。审计返回冲突，导出退出码为 1，标准输出为空 |

`linked-events.csv` 只包含冲突图中已知的时钟 ID，用于独立验证拒绝导出行为。
`moon run captures/verify-bench.mbtx --deny-warn` 同时复验旧版双设备功能和上述时钟图行为。
