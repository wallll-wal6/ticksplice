<img src="captures/ticksplice.svg" width="420" alt="TickSplice">

# 时缝

**把不同设备的时间缝回同一条线。**

同一次实验里，两台设备各记各的时间。只在开始时对表，后半段仍可能逐渐错开。TickSplice 用共同观测到的同步事件估计偏移和漂移，将设备读数换算成参考时间。每个同步事件的残差都可以回查，锚点范围之外的换算结果会单独标记。

适用于实验室多设备采集、传感器离线回放和设备日志对齐。参考时钟可以是另一台设备的相对时间，双方无需使用同一个时间原点。

## 跑一次台架实验

准备 [MoonBit](https://www.moonbitlang.cn/download/) 与 Node.js 22 或更新版本。以下命令在仓库根目录执行。先审计拟合，再生成校准记录，最后用留出事件比较误差。

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
- 文件为 UTF-8 CSV，时间使用十进制整数微秒，范围为 0 至 9007199254740991。支持带引号的字段、嵌入换行和双引号转义。采集记录可乱序，也可有同一设备时间的多条数据。
- 末尾参数是允许的绝对残差，单位为微秒，默认 1000。输入或拟合出错时，诊断写入标准错误，进程退出码为 1。

## 怎么判断结果能不能用

`audit` 给出覆盖区间、覆盖起点偏移、漂移 ppm 和逐锚点残差。残差为观测参考时间减去预测参考时间。拟合以锚点时刻为原点，先用两两斜率的中位数估计初值，再以阈值内的锚点作中心化最小二乘拟合，最后重新检查残差。多锚点模式要求至少两个锚点通过且超过总数一半。只有一个锚点时只估计偏移，`drift_ppm` 为 `null`。

首版覆盖一对设备的一段连续采集。锚点应横跨采集区间，并尽量保留独立验证事件。两个锚点可以拟合一条直线，检出错配则依赖额外锚点提供冗余。时钟重启或随温度出现明显非线性变化时，先按连续稳定段整理数据。输出的残差和覆盖标记可用于人工复核。

## 仓库地图

| 路径 | 内容 |
| --- | --- |
| [calibration/](calibration/) | 无文件依赖的时钟拟合、映射和证据 API |
| [console/](console/) | CSV 读写、Node.js 命令行及留出误差评分 |
| [captures/](captures/) | 实验记录和可复现的台架数据 |

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
