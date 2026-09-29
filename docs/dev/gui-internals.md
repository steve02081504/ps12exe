# ps12exeGUI 内部约定

<a id="gui-architecture"></a>

## 架构

GUI 界面不再由每种语言各写一份 `src/locale/*.fbs` 布局，而是由代码按 schema 动态生成。所有控件都走 `TableLayoutPanel`/`FlowLayoutPanel` + `AutoSize` 布局，译文长短不同也不会互相遮挡或截断。每个标签页是「`AutoScroll` 的 `Panel` 宿主 + `AutoSize`+`Dock=Top` 的内容表格」：`TableLayoutPanel` 的 `AutoScroll` 不会把 `AutoSize` 分组计入虚拟高度，直接用它会裁掉靠下的分组且滚不到（原生 DLL 导出表格就踩过这个坑），所以由外层 `Panel` 负责滚动。

`src/GUI/` 文件职责：

- `Schema.ps1`：唯一描述「界面上有哪些字段、参数路径、控件类型、默认值、可用条件」的地方，导出 `Get-GUISchema`（无副作用，可被测试直接调用）。
- `Layout.ps1`：按 schema 生成窗体与文件对话框。`New-GUIForm` 只构建、不显示，便于无头测试。
- `Functions.ps1`：UIData ↔ 控件 的双向映射、路径工具、配置文件读写、`Get-ps12exeArgs`。
- `Events.ps1`：事件绑定、字段联动、浏览按钮、编译按钮与窗体关闭逻辑。
- `Compile.ps1`：后台 runspace 编译，把输出流回写到日志框。
- `DarkMode.ps1`：亮/暗调色板与递归换肤（含标签页自绘）。
- `UItools.ps1`：P/Invoke、错误日志、环境初始化。
- `GUIMainScript.ps1`：加载顺序与生命周期。
- `Main.ps1`：CLI 入口（编译后作为 exe 运行时的那份）。

加载顺序（`GUIMainScript.ps1`）：`UItools.ps1 → locale 数据 → Schema.ps1 → Functions.ps1 → Layout.ps1 → Compile.ps1 → DarkMode.ps1 → Events.ps1`。

<a id="gui-schema"></a>

## Schema 与 GUI 文案

字段格式见 `src/GUI/Schema.ps1` 顶部注释。新增参数时：

1. 在 `Schema.ps1` 加字段（`Path`、`Kind`、`Default`，必要时 `Choices`/`Browse`/`EnabledWhen`）。
2. 在 7 份 `src/locale/<lang>.ps1` 的 `GUI` 里补 `Field.<Path>` 文案。
3. 如果是新参数，按 AGENTS.md 同步 locale 的 `Usage`/`PrarmsData` 与各语言 README。

`GUI` 是按语义分类的嵌套对象（`Page`/`Group`/`Field`/`Button`/`Dialog`/`Window`/`Log`/`Label`），键名拼起来就是点号路径；`Field` 下继续按参数路径嵌套（如 `Field.Build.Core.Trimmed`）。`Field.Build.DllExports` 既有自身标签又有子键，故标签放在它的 `Label` 子键下。

`Get-GUIText $Key` 按点号路径在这棵对象里取叶子字符串，三级回退：当前语言 `GUI` → en-US `GUI` → 直接返回 `$Key`。缺翻译不会崩，只是显示键名。

`Get-ParamHelp $Path`：沿 `ConsoleHelpData.PrarmsData` 的嵌套哈希按点号路径取值作为 ToolTip，去掉 markdown 反引号；字段声明了 `Help` 时优先用它。

### GUI 必需的键

- 页：`Page.General`、`Page.App`、`Page.OS`、`Page.Build`、`Page.Core`、`Page.Resources`、`Page.Signing`、`Page.Modes`
- 分组：`Group.IO`、`Group.Target`、`Group.Silence`、`Group.Console`、`Group.Windowed`、`Group.OS`、`Group.Build`、`Group.ConstEval`、`Group.DllExports`、`Group.Core`、`Group.Resources`、`Group.Signing`、`Group.Modes`
- 字段：`Field.<schema 里的 Path>`；另加 `Field.Build.DllExports.Label`、`Field.Build.DllExports.Help`、`Field.Build.DllExports.FuncName`、`Field.Build.DllExports.ReturnType`、`Field.Build.DllExports.Params`
- 按钮：`Button.Compile`、`Button.Cancel`、`Button.LoadCfg`、`Button.SaveCfg`、`Button.SaveAsCfg`、`Button.Browse`、`Button.DarkMode`、`Button.BGM`、`Button.AddExport`、`Button.EditExport`、`Button.RemoveExport`
- 对话框：`Dialog.Compile.Title`、`Dialog.Compile.Filter`、`Dialog.Output.Title`、`Dialog.Output.Filter`、`Dialog.Icon.Title`、`Dialog.Icon.Filter`、`Dialog.Certificate.Title`、`Dialog.Certificate.Filter`、`Dialog.OpenCfg.Title`、`Dialog.OpenCfg.Filter`、`Dialog.SaveCfg.Title`、`Dialog.SaveCfg.Filter`、`Dialog.Folder.Title`
- 其它：`Window.Title`、`Log.Ready`、`Log.Compiling`、`Log.Cancelled`、`Log.Done`、`Log.CfgLoadFailed`、`Label.CfgFileHead`（已有 `CfgFileLabelHead` 可复用，统一用 `Label.CfgFileHead`）

<a id="gui-theme"></a>

## 主题与换肤

`DarkMode.ps1` 同时负责初始深浅判断与换肤。`Get-GUIThemePalette -Dark $bool` 返回一套语义调色板（`WindowBack`/`SurfaceBack`/`InputBack`/`Accent`/`LogBack`…，值是 `#RRGGBB` 字符串），`Set-DarkMode $bool` 把调色板递归应用到整棵控件树，并把当前调色板存到 `$Script:GUITheme` 供自绘回调读取。新增控件类型或想调整观感时，只改调色板与该函数的类型分支，不要在 Layout 里散落硬编码颜色。

- 语义分层：窗体底色（`WindowBack`）最外，分组卡片（`SurfaceBack`）略突出，输入控件（`InputBack`）内凹，强调色（`Accent`）只给编译/取消这类主操作。
- 分组卡片用 `UItools.ps1` 里的自定义类型 `ps12exeGUI.FlatGroupBox`（`GroupBox` 子类，自绘圆角边框与加粗标题）：系统 `GroupBox` 的 3D 边框在深色下会露出亮线且无法换色。换肤时通过 `BorderColor`/`TitleColor` 属性下发颜色（`$control -is [ps12exeGUI.FlatGroupBox]` 分支）；它仍是 `[System.Windows.Forms.GroupBox]`，`gui.layout` 的类型判断不受影响。
- `TableLayoutPanel`/`FlowLayoutPanel`/`Panel` 按父控件底色继承，避免系统默认灰在深色下露馅。
- TabControl 跟不了深色，由 `Initialize-GUITabTheme` 改成 `OwnerDrawFixed` 自绘（选中项加一条强调色下划线），只需挂钩一次，之后换肤靠 `Invalidate` 重绘。
- 文本类控件用 `SetWindowTheme('DarkMode_Explorer')` 让滚动条跟着变暗。
- 深色/背景音乐按钮的图标源图是 256px 纯白透明 PNG，`Set-GUIButtonIcon` 会缩到 16px 并按当前主题前景色重新着色后挂到 `Button.Image`（`TextImageRelation=ImageBeforeText`），亮/暗下都清晰；不要在 Events 里再设 `BackgroundImage`。
- 自动跟随：`UIMode=Auto` 时定时器每 2s 调 `Sync-GUIDarkMode`（读 `AppsUseLightTheme`）。只有**系统设置本身**变化才算「系统切换」；用户点深色按钮会置 `$Script:DarkModeOverride`，在系统设置不变期间保持手动结果，系统再变则清除覆盖、自动跟随重新接管（防止手动切到浅色后 2s 又被切回去）。`Sync-GUIDarkMode -SystemDark` 供测试注入系统值。
- `Get-SystemDarkMode` 读 `HKCU:\...\Themes\Personalize\AppsUseLightTheme`，读不到按浅色。
- 本主题只作用于 ps12exeGUI 自身；编译产物窗口的 `App.DarkMode` 是另一套实现，不要混用。
- `gui.theme`/`gui.darkmode-follow` 用例会用 `Invoke-GUIScriptBlock`（STA）分别断言两套调色板落点与自动跟随/手动覆盖语义。

<a id="gui-refs"></a>

## 控件引用约定

`New-GUIForm` 会填充：

- `$Script:refs`：具名控件。至少含 `MainForm`、`TabsControl`、`LogTextBox`、`CfgFileLabel`、`CompileButton`、`CancelButton`、`LoadCfgButton`、`SaveCfgButton`、`SaveCfg2OtherFileButton`、`DarkModeSetButton`、`BGMSetButton`、`CompileFileTextBox`、`OutputFileTextBox`。
- `$Script:FieldControls[$Path]`：字段的输入控件。`Bool`→`CheckBox`，`Text/Choice/ChoiceEdit/Path/Password/Script`→对应控件，`Flags`→承载 CheckBox 的容器，`DllExports`→`DataGridView`。
- `$Script:FieldBrowse[$Path]`：`Kind=Path` 时的浏览按钮（`Folder` 用 `FolderBrowserDialog`）。

<a id="gui-functions"></a>

## 函数契约

`Functions.ps1`：

- `Get-NestedValue $UIData $Path` / `Set-NestedValue $UIData $Path $Value`：点号路径读写嵌套哈希，中间层不存在则创建。
- `Get-DefaultUIData`：按 schema 的 `Default` 构造完整 UIData（含被禁用字段）。
- `Get-UIData`：从控件读值，返回完整 UIData，附 `SchemaVersion = 2`。
- `Set-UIData -UIData`：写回控件后调用 `Update-UIState`。
- `Update-UIState`：按每个字段的 `EnabledWhen` 刷新 `Enabled`；`Choice` 字段按 `ChoicesWhen` 重建选项（保留当前值，若被过滤掉则回退到首项）。
- `Get-ps12exeArgs`：只输出「字段可用且值与默认不同」的项，组装成 ps12exe 对象式 API（`inputFile`/`outputFile`/`App`/`Os`/`Build`/`Resources`/`Signing`/模式开关）。`Build.Minify` 转 scriptblock；`Build.DllExports` 直接是数组。被 `EnabledWhen` 判为不可用的字段不输出。
- `Resolve-ProjectPath $Path $BaseDir`：URL（`^[a-z]+://`）原样返回；`,N` 形式的资源图标索引只解析路径部分；相对路径以 `$BaseDir`（配置文件所在目录）为基准转绝对路径。
- `Get-RelativePath $Path $BaseDir`：用 `Uri.MakeRelativeUri` 实现，兼容 Windows PowerShell 5.1（不用 `Resolve-Path -RelativeBasePath`）。
- `Get-ps12exeArgs` 里所有相对路径都解析成绝对路径，因此调用 ps12exe 时不必再 `Set-Location`。
- 配置文件：`SetCfgFile`、`LoadCfgFile`、`SaveCfgFileAs`、`SaveCfgFile`、`AskSaveCfg`、`Test-UIDirty`。对话框取消（`FileName` 为空或与调用前相同）时直接返回；`Import-Clixml` 失败弹窗提示并写日志。
- `Write-GUILog $Text`：把一行追加进 `LogTextBox` 并滚到底。

`Layout.ps1`：`Resolve-NestedText`、`Get-GUIText`、`Get-ParamHelp`、`New-GUIForm`、`New-GUIDialogs`（返回哈希表，键 `Compile`/`Output`/`Icon`/`Certificate`/`Folder`/`OpenCfg`/`SaveCfg`）。

`Compile.ps1`：

- `Initialize-GUICompiler`：在后台 runspace 里 `Import-Module ps12exe.psm1`。UI runspace 不再导入模块。
- `Start-GUICompile`：`BeginInvoke` 执行 `ps12exe @Params -Locale $Locale`，用 WinForms `Timer` 轮询输出集合写入 `LogTextBox`；编译中 `CompileButton` 显示取消并调用 `Stop`；结束弹结果框（沿用旧逻辑区分 ParserError）。
- `Stop-GUICompile`、`Test-GUICompileRunning`。
- 为便于测试，`Start-GUICompile` 接受 `-Params` 覆盖默认取参（测试可传 `@{ PreprocessOnly = $true; inputFile = ... }` 走快速路径）。

`Events.ps1`：`Register-GUIEvents`（绑定所有处理器，供 GUIMainScript 调用）；不再有 `SizeChanged` 缩放与 `AutoFixer`。其中 `MainForm.Shown` 会把窗体拉到前台（隐藏控制台后进程可能拿不到前台权限，窗体会躲在后面不弹出）：短暂 `TopMost` + `Activate`/`BringToFront` + `SetForegroundWindow`。

<a id="gui-config-format"></a>

## psccfg 格式

配置就是 `Get-UIData` 返回的哈希表，`Export-Clixml` 存盘，含 `SchemaVersion = 2`。**不向后兼容**旧的扁平格式（`noConsole`/`resourceParams`/`CodeSigning.Path` 等）；加载到无 `SchemaVersion` 的文件时，按 schema 默认值填充缺失键，不做旧键名迁移。

<a id="gui-paths"></a>

## 路径与 URL 细则

- `inputFile`、`Resources.Icon` 可以是 URL，解析时原样保留。
- `Resources.Icon` 可以是 `x.dll,N`（资源图标索引），只把 `x.dll` 部分相对化/绝对化。
- `Build.Minify` 在多行框里是文本，转 scriptblock；为空则整个字段不输出。
