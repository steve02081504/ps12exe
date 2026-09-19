# AGENTS.md

## 项目结构

- `ps12exe.ps1`：CLI 入口与参数解析；公开的对象式参数在此适配为内部规范变量。
- `src/`：编译器与运行时（`CoreCompiler.ps1`、`CodeDomCompiler.ps1`、`TinySharpCompiler.ps1`、`BuildFrame.ps1`、`programFrames/*.cs`）、GUI、WebServer、Interact、locale。
- `src/locale/<lang>.ps1`：各语言界面文案与帮助数据。
- `src/.subrepo/`：内置子项目（`PS2EXE2ps12exe` 兼容层、`vscode-plug` 扩展、在线 Web 版）。
- `docs/README_*.md`：各语言文档；根 `README.md` 为英文主文档。

## 参数 API 约定（重要）

- 对外统一使用对象式参数：`-App @{…}`、`-Os @{…}`、`-Build @{…}`、`-Resources @{…}`、`-Signing @{…}`，外加模式开关 `-PreprocessOnly -Golf -Sandbox -NoUpdateCheck -Locale -ConfigFile -help`。
- **行为型开关只允许改名/归类，不允许删除**；新增参数优先放进最贴近的对象里。
- 公开 API 在 `ps12exe.ps1` 内经 `Get-Opt` / `ConvertTo-OptBool` 适配为内部规范变量（`$noConsole`、`$resourceParams`、`$targetRuntime` 等），下游编译器与 C# 帧只认这些内部变量。
- `#_pragma` 使用对象点号路径（如 `#_pragma App.Windowed`、`#_pragma Build.ConstEval.Enabled 0`）；支持无值形式（等价 `$true`）与任意层级。
- 宿主嵌套状态通过 `PS12EXE_NESTED` 环境变量传递，不用参数；读取方立即 `Remove-Item Env:PS12EXE_NESTED`。
- `src/.subrepo/PS2EXE2ps12exe` 是**唯一**的兼容层，只有它接受 PS2EXE 参数名；其余代码、文档、扩展一律只用上面的对象式 API。

## 帮助数据与展示

- 控制台帮助数据位于各 `src/locale/<lang>.ps1` 的 `ConsoleHelpData.PrarmsData`；对象参数（`App`/`Os`/`Build`/`Resources`/`Signing`）的值是**嵌套哈希表**，逐键给出详细说明。
- `src/HelpShower.ps1` 负责渲染：标量逐行输出，嵌套对象先打分组标题，再把子键缩进并对齐。
- 改动参数时必须同步三处：locale 的 `Usage`/`PrarmsData`、各语言 `docs/README_*.md` 的参数表、必要时 VS Code 扩展的 `lib/definition.mjs` 与 hover/l10n。

## 编码

- `.ps1/.psd1/.psm1/.cs` 用 **UTF-8 with BOM**（Windows PowerShell 5.1 对无 BOM 的 UTF-8 中文会乱码/解析失败；C# 源码含中文同理）。写入用 `[System.IO.File]::WriteAllText($f,$t,[System.Text.UTF8Encoding]::new($true))`；不要用会剥掉 BOM 的 `Set-Content -Encoding utf8`。
- 其它文件（`.md/.json/.yaml/...`）一律 **UTF-8 无 BOM**。
- 验证：`[System.IO.File]::ReadAllBytes($f)[0..2]`——脚本与 `.cs` 应为 `EF BB BF`；其余文件不应以 `EF BB BF` 开头。

## 测试与校验

- 统一入口：`pwsh tests/run.ps1`。默认按本地 git 改动增量选择用例；`-All` 全量，`-Filter '*xxx*' -Group ps12exe -List` 查看/筛选，`-NoCache` 忽略构建缓存，`-ChangedPathsFile f.txt` 指定改动清单。用例全部通过时退出码 0。
- 框架：`tests/run.ps1`（编排：依赖选择 / 构建去重 / 并行 / 缓存 / GitHub 报告），`tests/lib/`（公共库、断言、worker），`tests/cases/*.ps1`（数据驱动用例）。
- 用例声明 `Deps`（改动的源文件/目录前缀）、`Build`/`Builds`（`InputText` 或 `InputFile`、`Params` 具名参数哈希、`Compiler='ps2exe'` 走兼容层）、`Run`（断言脚本块，收 `$ctx`：`RepoRoot`/`WorkDir`/`Builds`）。`Deps` 为空表示常跑；改动 `tests/**` 或 `.github/workflows/**` 触发全量。
- 构建按「组件源码指纹 + 输入 + 参数 + 输出名」内容哈希去重并缓存到 `tests/.cache/builds`。组件划分见 `tests/lib/common.ps1` 的 `$script:BuildComponentPatterns`（`common`/`codeDom`/`tinySharp`/`core`/`ps2exe`，只收录进入产物的文件），所以改 `CoreCompiler.ps1` 只失效 Core 构建、改 `exe21sp.ps1`/locale/GUI 等不影响任何构建缓存。
- 并行度：构建默认约 `min(CPU*2,8)`（超订以掩盖进程创建/杀毒/dotnet publish 的 I/O 等待），测试默认 `min(CPU,4)`；`-BuildThrottleLimit`/`-ThrottleLimit` 覆盖。`-ShardCount N -ShardIndex i` 按构建数贪心把用例稳定分到 N 片，配合 CI matrix 跨 runner 并行。
- 语法自检：`[System.Management.Automation.Language.Parser]::ParseFile($f,[ref]$null,[ref]$e)`，`$e.Count` 应为 0（`static.powershell-parses` 用例已覆盖）。
- 帮助渲染：`. .\src\HelpShower.ps1 -HelpData (& .\src\locale\zh-CN.ps1).ConsoleHelpData | Write-Host`。
- 新增/修改用例后记得本地跑一次相关 `-Filter`，并在提交前 `pwsh tests/run.ps1 -All` 过一遍。
- VS Code 扩展：在 `src/.subrepo/vscode-plug/ps12exe` 下运行 `npm test`。
