# 来源与许可证

TickSplice 的校准模型、CSV 工作流和测试由本项目实现，采用 [MIT](LICENSE) 许可证。
Theil–Sen 斜率中位数和普通最小二乘是采用的算法方法，当前实现没有移植其他语言库的源代码。

| 来源 | 许可证 | 使用范围 |
| --- | --- | --- |
| [moonbitlang/core](https://github.com/moonbitlang/core) | Apache-2.0 | 工具链随附标准库，集合、数值、JSON、严格 UTF-8 解码 |
| [moonbitlang/x 0.5.7](https://github.com/moonbitlang/x) | Apache-2.0 | 命令行读取本机文件，通过模块依赖获取 |
| [moonbitlang/async](https://github.com/moonbitlang/async) | Apache-2.0 | 仅用于验收脚本启动子进程，来自工具链脚本运行环境 |

标准库和依赖源码通过原发布渠道获取。分发含这些组件的构建产物时，应保留对应许可和适用的版权声明。
验收脚本使用的 async 环境会提示实验性依赖，校准库本身没有该依赖。

`captures/bench-pulse`、`captures/logger-pair`、`captures/session-offset` 的数据均为本项目根据文档公式构造，
采用项目 MIT 许可证。SVG 标识由本项目以矢量代码绘制。`pkg.generated.mbti` 为 MoonBit 编译器生成的 API 摘要。
项目方向和交付要求由参赛者提出，AI 辅助实现、测试和资料整理，人工需要复核算法选择、误差解释和正式申报书。

## 相近项目与新增价值

2026 年 11 月 5 日使用 Mooncakes 的 `clock synchronization`、`temporal alignment` 关键词查询，
并核对相关仓库的公开说明。

| 项目 | 检索到的功能 | TickSplice 的交付边界 |
| --- | --- | --- |
| [warpfit](https://github.com/JQ-ai-nb/warpfit) | 可微时间序列对齐、梯度和原型拟合 | 输入有明确对应关系的事件锚点，估计物理时钟的仿射映射并输出覆盖与逐事件残差 |
| [moon-change-point](https://github.com/Zy789kl/moon-change-point) | CUSUM、Page–Hinkley、贝叶斯变点检测与告警抑制 | 将独立时钟的时间换算到参考时间，再供上层分析工具使用 |

上述项目用于选题比较，当前代码未导入或复制它们的实现。公开检索无法覆盖尚未公开的参赛项目，
申报前需再次检查同类包，参赛者应结合实际用户需求说明独立建设的理由。
