# 三个完整使用场景

以下三个目录均为本项目构造的合成数据，随 MIT 许可证分发。数据中的设备、信号与事件是示例，
用于演示输入、计算和验收过程。配对锚点来自用户识别的同一物理事件。

## 实验室采集与参考仪器

实验人员同时记录主采集板和参考仪器的脉冲，开始时对表后仍有累积偏差。
输入 `bench-pulse/fit.csv` 的 9 条同步事件和 `device.csv` 的信号读数，
另留 5 个事件验证。运行以下命令可检查偏移、漂移、错配与校准后的测量时间。

```sh
moon run console --target js -- audit captures/bench-pulse/fit.csv 100 --min-span-us 80000000
moon run console --target js -- apply captures/bench-pulse/fit.csv captures/bench-pulse/device.csv 100
moon run console --target js -- score captures/bench-pulse/fit.csv captures/bench-pulse/holdout.csv 100
```

验收时应得到约 +500 ppm、设备时刻 40 s 的 60 ms 错配，留出最大误差为 0 µs。
校准时间可用于把信号叠加到参考仪器曲线上，超出锚点范围的读数另作复核。

## 环境记录器离线汇总

维护人员从温度记录器导出测量值，并从参考记录器取得周期同步事件。
输入 `logger-pair/fit.csv` 和 `device.csv`，参考读数按设备时间 × 0.9995 + 100000 µs 构造。
用校准后的时间作为跨设备汇总键，温度列保持原值。

```sh
moon run console --target js -- audit captures/logger-pair/fit.csv 100
moon run console --target js -- apply captures/logger-pair/fit.csv captures/logger-pair/device.csv 100
moon run console --target js -- score captures/logger-pair/fit.csv captures/logger-pair/holdout.csv 100
```

验收时应得到约 −500 ppm，设备时刻 15 s 对应 15092500 µs，45 s 对应 45077500 µs 并标记外推。
两个留出事件的最大绝对误差为 0 µs。采集超过覆盖范围后应补采同步事件。

## 同一会话中的设备事件日志

开发人员将终端相对时间日志与服务端事件对齐，仅在启动时有一次确认的共同事件。
输入 `session-offset/fit.csv` 和 `device.csv`，先以 200000 µs 固定偏移转换请求与响应时间。

```sh
moon run console --target js -- audit captures/session-offset/fit.csv
moon run console --target js -- apply captures/session-offset/fit.csv captures/session-offset/device.csv
moon run console --target js -- score captures/session-offset/fit.csv captures/session-offset/holdout.csv
```

验收时模型为 `offset`，漂移为 `null`，设备时刻 2 s 对应 2200000 µs，启动锚点之后的记录均标记外推。
这适合在短会话中人工复核事件先后次序。要判断长会话的漂移，需补采跨越整个会话的锚点。

在仓库根目录运行 `moon run captures/verify-bench.mbtx --deny-warn`，可自动验证三个场景的关键输出。
