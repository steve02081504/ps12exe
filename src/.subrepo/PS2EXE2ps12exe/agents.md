# PS2EXE2ps12exe

## 目标

**PS2EXE2ps12exe 的唯一目标是最大兼容性**：让任何 PS2EXE 版本下的调用都能在 ps12exe 上按原样工作。

## 规则

- 参数集必须覆盖所有 PS2EXE 版本（含较旧版本）暴露过的参数。
  - 例：`-runtime20` / `-runtime40` 虽然在最新 PS2EXE 中已移除，但旧脚本仍可能使用，必须保留并映射到 `-targetRuntime Framework2.0` / `Framework4.0`。
  - 任何 PS2EXE 曾暴露的参数都不得删除；无法等价实现的优先“接受并忽略”，其次才报错。
- 所有参数都要转发或转写：
  - 能直接对应 ps12exe 新参数的，做映射后转发（`x86/x64 → architecture`、`STA/MTA → threadingModel`、资源参数 → `resourceParams`）。
  - ps12exe 没有的能力（`conHost`、`embedFiles`）以及 PS2EXE 运行时变量（`$ScriptRoot`），通过 `-minifyer` 在预处理后改写脚本实现。
- 校验行为尽量与 PS2EXE 一致（组合冲突、`runtime20` 与 longPaths/winFormsDPIAware 的互斥等）。
- 只做兼容层，不改变 ps12exe 本体的语义。
