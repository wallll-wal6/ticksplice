<img src="captures/ticksplice.svg" width="420" alt="TickSplice">

# 时缝 ClockNet

**把不同设备的时间缝回同一条线。**

时缝把离线采集中的设备时钟组织成图。每条边由两台设备会话的配对事件建立。即使传感器只和网关有共同事件，也能沿传感器 → 网关 → 参考仪器的路径换算时间。审计报告列出路径、链路编号、共同支持区间和无法对齐的设备。两条路径存在足够的共同证据时，程序会检查它们是否给出相符的参考时间。

## 从同步链到参考时间

准备 [MoonBit](https://www.moonbitlang.cn/download/) 和 Node.js 22 或更新版本。在仓库根目录运行：

```sh
moon update
moon run console --target js -- network-audit ref captures/clock-network/chain.csv 10 50
moon run console --target js -- network-apply ref captures/clock-network/chain.csv captures/clock-network/events.csv 10 50
moon run console --target js -- network-audit ref captures/clock-network/conflict.csv 10 50
```

同步链样例中，传感器读数 1000000 µs 经网关换算为 1201000 µs。超出路径支持区间的记录标记为 `extrapolated`，已知但无法连到参考时钟的记录标记为 `disconnected` 并留空参考时间。冲突样例中，三条边各自均无剔除点，路径审计仍发现约 500 µs 的差值，并阻止导出。样例是合成数据。 [复现实验与预期输出](captures/clock-network/README.md)

链接表使用 `from,to,from_us,to_us`，相同有向时钟对的记录组成一条边，每边至少提供两个匹配事件。采集表以 `clock,device_us` 开头，其余列原样保留。用不同 ID 表示同一设备重启前后的会话。两个可选参数依次为边拟合残差阈值和路径冲突阈值，单位为微秒，默认均为 1000。

每条边先独立拟合仿射映射。求解器选择最少跳路径，同跳数按输入边顺序处理。逆向边使用解析逆映射及该方向保留锚点的观测区间。组合时将下一边的覆盖区间拉回当前坐标系，取沿途交集，最后输出时才取整。

对参考时钟所在分量的非树边，求解器在两条路线的共同覆盖区间内比较映射。仿射差的绝对值在区间端点之一取最大值。无正长度共同区间时标为 `no_shared_coverage`，该边无法验证。确认的冲突会使 `network-apply` 退出 1，并保持标准输出为空。审计不自动归责，树形图也没有冗余证据可用于检查路径一致性。

当前最多支持 64 个设备会话、256 条链路和每条链路 256 个匹配事件，输入是已配对的事件。不同分量需分别选择参考时钟进行审计。路径的支持区间表示观测范围，不代表误差置信区间。 [可执行图 API 示例](network/README.mbt.md)

## 双设备拟合与原台架

准备 [MoonBit](https://www.moonbitlang.cn/download/)（本轮验证版本为 moonc 0.10.19）与 Node.js 22 或更新版本。以下命令在仓库根目录执行。先审计拟合，再生成校准记录，最后用留出事件比较误差。

```sh
moon update
moon run console --target js -- audit captures/bench-pulse/fit.csv 100
moon run console --target js -- apply captures/bench-pulse/fit.csv captures/bench-pulse/device.csv 100
moon run console --target js -- score captures/bench-pulse/fit.csv captures/bench-pulse/holdout.csv 100
```

| 台架结果 | 值 |
| --- | --- |
| 覆盖起点的偏移 | 250 ms |
| 估计漂移 | 约 +500 ppm |
| 错配锚点 | 设备时刻 40 s，残差 +60 ms |
| 仅偏移校正的留出误差 | 中位 27.5 ms，最大 45 ms |
| 含漂移校正的留出误差 | 中位 0 µs，最大 0 µs |

台架数据是按已知公式生成的。最后一个验证事件位于覆盖区间外，`score` 会将其计入误差统计并另外报告外推数量。复现实验和设备采集办法见 [实验记录](captures/README.md)。

## 换成自己的数据

- **同步事件表**使用 `device_us,reference_us` 两列，每条记录代表同一个物理事件在两个时钟上的读数。输入 1–256 条锚点，设备锚点时间须唯一。参考设备侧的对应事件时间直接写在这里。
- **待校准记录表**的首列是 `device_us`，其余列按原有值和顺序保留。输出在右侧追加 `reference_us` 和 `extrapolated`。可用 shell 重定向将标准输出写到另一个文件。
- **留出事件表**与同步事件表格式相同，设备时间不得与拟合锚点或其它留出事件重复。建议留出中段和末段的同步事件。固定偏移基线取最早保留锚点的参考时间与设备时间之差。
- 文件使用严格 UTF-8 解码，非法编码将明确拒绝。CSV 时间使用十进制整数微秒，范围为 0 至 9007199254740991。支持带引号的字段、嵌入换行和双引号转义。采集记录可乱序，也可有同一设备时间的多条数据。
- 末尾参数是允许的绝对残差，单位为微秒，默认 1000。输入或拟合出错时，诊断写入标准错误，进程退出码为 1。

- 可在三个命令末尾加上 `--min-span-us N`，要求通过残差检查的首尾锚点至少相隔 N 微秒。省略时沿用原有行为。跨度不足时退出码为 1，并报告实际跨度和要求值。

## 怎么判断结果能不能用

`audit` 给出覆盖区间、覆盖时长（`coverage_span_us`）、覆盖起点偏移、漂移 ppm 和逐锚点残差。残差为观测参考时间减去预测参考时间。拟合以锚点时刻为原点，先用两两斜率的中位数估计初值，再以阈值内的锚点作中心化最小二乘拟合，最后重新检查残差。多锚点模式要求至少两个锚点通过且超过总数一半。只有一个锚点时只估计偏移，`drift_ppm` 为 `null`。

首版覆盖一对设备的一段连续采集。锚点应横跨采集区间，并尽量保留独立验证事件。两个锚点可以拟合一条直线，检出错配则依赖额外锚点提供冗余。时钟重启或随温度出现明显非线性变化时，先按连续稳定段整理数据。输出的残差和覆盖标记可用于人工复核。

三个场景的输入、输出和验收标准见[使用场景](captures/workflows.md)。库调用方法见[可执行 API 示例](calibration/README.mbt.md)。

复验台架断言请运行 `moon run captures/verify-bench.mbtx --deny-warn`。

## 仓库地图

| 路径 | 内容 |
| --- | --- |
| [calibration/](calibration/) | 无文件依赖的时钟拟合、映射和证据 API |
| [network/](network/) | 双向时钟图、路径覆盖与冗余边审计 |
| [console/](console/) | CSV 读写、Node.js 命令行、图审计与留出误差评分 |
| [captures/](captures/) | 双设备和图场景的复现实验 |

```sh
moon check --deny-warn
moon test --deny-warn
moon check --target js --deny-warn
moon test --target js --deny-warn
moon build console --target js --release
moon fmt --check
```

代码采用 [MIT](LICENSE) 许可。命令行通过 [moonbitlang/x](https://github.com/moonbitlang/x) 读取文件。
算法采用 Theil–Sen 斜率中位数与普通最小二乘。样例由本项目按公开公式构造。相近的 MoonBit 项目 [warpfit](https://github.com/JQ-ai-nb/warpfit) 处理可微时序对齐，本项目以配对同步事件校准设备时钟并记录证据。

复审材料见 [项目事实底稿](SUBMISSION.md) 和 [核对记录](REVIEW.md)。

第三方许可、样例来源和同类比较见 [THIRD_PARTY.md](THIRD_PARTY.md)。
