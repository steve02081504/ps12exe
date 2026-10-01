# 编译器内部机制（开发笔记）

主 [`AGENTS.md`](../../AGENTS.md) 只保留约定、入口与常用命令；这里是需要时再查的实现细节。

<a id="preprocessing-roundtrip"></a>

## `#_!!` 剥离与 exe21sp 往返

- `#_!!` 的剥离在 `src/ReadScriptFile.ps1` 的管道中位于 `#_pragma`/`#_require`/`#_DllExport`/`#_if` 之后、`#_include` 之前：所以 `#_!!` 能转义前者（当次编译惰性），但 `#_!!#_include` 仍会被读取（被展开的 include 不残留在产物里）。
- `exe21sp` 反编译拿到的是预处理后文本，残留的 `#_` 指令重编译时会复活。往返流程：
  1. `Remove-DerivablePragmaLines` 先删掉 `App.Windowed`/`Resources.*`/`Build.Target`/`Build.Platform`/`Os.Admin` 这些会重新推导的旧行（否则往返「转义旧行 + 追加新行」会膨胀）；
  2. `Escape-PreprocessorDirectives` 给其余残留 `#_` 指令补回 `#_!!`（`#_` 后是字母才算指令），攻击者指令因此只作为注释留存；
  3. `Restore-RequiredModulePragma` 还原活动的 `#_require`；
  4. `Restore-BalusPragma` 把 `#_balus` 展开出的自删除代码还原回 `#_balus <exitcode>`；
  5. 最后从产物补唯一一份推导配置：PE 子系统 → `App.Windowed`、无 CLR 头 → `Build.Target 'Core'`、CLR 元数据 `v2.0.50727` → `Build.Target 'Framework2.0'`、PE32+/CorFlags → `Build.Platform`、RT_MANIFEST → `Os.Admin`、版本资源/图标 → `Resources.*`。
- `#_DllExport` 不是注释：它会把声明收集进 `$DllExportList`，走原生 DLL 导出路径（见下）；访客模式下忽略。
- 目标：任意 exe 往返后有效内容不变、不膨胀。

<a id="dllexport"></a>

## 原生 DLL 导出（`#_DllExport` / `Build.DllExports`）

- 目标：一步产出可被 native `LoadLibrary`/`GetProcAddress` 调用的 Win32 DLL，导出函数转发到脚本里的同名 PowerShell 函数。
- 仅支持 Framework4.0 + x86/x64：`AnyCPU` 会自动选宿主位数并告警；`arm64`/`Framework2.0`/`Core` 直接报错；访客模式忽略该指令（避免编译期联网下载并执行工具）。
- 产物分两层（`src/CodeDomCompiler.ps1` 的 DllExport 分支）：
  1. **payload**：CodeDom 把 `default.cs` 与 `DllExport.cs` 两个源文件（同一个 `PSRunnerEntry` partial 类，现为 `public` 供 launcher 调用）按 `/target:library` 编译成普通类库；每个导出声明生成一个 `PS12ExeDllExport<i>` 包装方法，首次调用时 `DllInitChecker` 惰性建宿主并以点源方式在全局作用域运行脚本（函数定义在 `PSEXEMainFunction` 体内是局部的，导出必须走顶层/点源）。
  2. **launcher**：gzip 上面那份 payload，编译 `src/programFrames/DllExportPack.cs`（`/target:library`，编译期引用 payload，内嵌 gzip 资源 `main`，携带最终 PE 的资源/图标）。其静态构造在首次导出调用前解压并 `Assembly.Load`，再挂 `AssemblyResolve`，让生成的转发包装直接静态调用 payload 的同名包装；静态构造由 CLR 保证只跑一次，因此每个导出调用没有额外检查/加锁。
  3. 用 AsmResolver 读取 launcher，给每个转发包装设 `MethodDefinition.ExportInfo = new UnmanagedExportInfo(名字, VTableFromUnmanaged | (x86 ? VTable32Bit : VTable64Bit))`，清掉 module 的 `ILOnly` 标志后 `ModuleDefinition.Write` 重写：AsmResolver 的托管 PE 写出器据此生成 native 导出桩、`mscoree.dll!_CorDllMain` 引导桩与 CLR vtable fixup（与 ilasm 对 `.export` 的处理同机制），位数由 vtable 项的 32/64 位区分。
  4. 该路径跳过 pack 与 `ExeSinker`（后者重建 PE 会覆盖刚生成的导出表/引导桩），也不写产物缓存。
- 必须清 `DotNetDirectoryFlags.ILOnly`，否则不写 CLR 引导桩、`LoadLibrary` 起不来 CLR。
- 导出名指针表必须按字典序升序（Windows 才能二分查找），`Sort-DllExports` 以序数、区分大小写排好元数据方法顺序作为兜底。`src/bin/AsmResolver.dll` 目前是含上游修复（[Washi1337/AsmResolver#793](https://github.com/Washi1337/AsmResolver/pull/793)：导出名指针表按名排序）的本地构建；若换回不含该修复的版本，这一步就是必需的，否则 `GetProcAddress` 按名解析会漏掉部分导出。
- 用到的 AsmResolver.DotNet 写出器 API 需镜像在 `tools/AsmResolver/Root.cs`，否则会被 illink 裁掉（见 `#asmresolver-trim`）。
- 导出包装方法把异常挡在 native 边界内：出错写 stderr 并返回默认值（托管异常穿过 native 边界会变成进程级崩溃）。

<a id="sandbox-guest"></a>

## 访客（Sandbox）模式

- 远程抓取只允许 http(s)，且逐跳校验重定向：`src/GuestUrlGuard.ps1` 的 `Test-GuestUrlAllowed` 拒绝 loopback/私网/CGNAT/link-local/组播/IPv6 隧道（6to4/Teredo/NAT64/映射）地址；`Invoke-GuestHttpRequest` 关闭 `Invoke-WebRequest` 的自动重定向、手工校验每个 `Location` 并按实际下载字节数限流（脚本/图标均 1mb）。`ReadScriptFile.ps1`/`InitCompileThings.ps1` 的访客分支都走它。
- 预处理侧禁止 `outputFile`/`Build.TempDir`/`Build.Minify`/`Signing.Certificate`；访客的本地 `Resources.Icon` 仅放行 `%windir%`/`%SystemRoot%` 下的文件（其余本地路径 GDI+ 任意读文件 / UNC SMB 外连一律拒绝）；`Signing` 整体禁用（本地 PFX / 时间戳 SSRF）；env 仅放行 `windir`/`SystemRoot`（常量分析里 `env:` 一律非 const）。
- 已知残余风险 DNS rebinding（校验时解析公网、连接时改内网）：彻底缓解需连接固定的已校验 IP，会破坏 HTTPS 的 SNI/证书校验，故未实现。
- 验证行为要用 CLI `-Sandbox`；WebServer 对 `127.0.0.1` 客户端自动关闭 Sandbox，本地起服务打请求测到的是非访客路径，别据此判断沙箱已生效。

<a id="compile-caches"></a>

## 编译缓存

所有临时缓存统一挂在 `%TEMP%\ps12exe\`（`src/Cache.ps1` 的 `Get-TempRoot`/`Get-CacheRoot <name>`/`Clear-StaleCache`；更新检查的 txt 在根下 `version.txt`）。清对应目录即强制冷编译。

### 产物结果缓存（`cache\output`）

- `src/OutputCache.ps1`：非常量 Framework 构建按「最终脚本文本 + 序列化后的具名参数 + 编译器源码指纹」内容寻址，命中即拷贝上次产物、跳过编译。指纹 `Get-CompilerSourceFingerprint` 覆盖 `ps12exe.ps1`、`src/*.ps1`、`programFrames/*.cs`、`RuntimePwsh2.0/*.ps1`，编译器自身改动自动失效，不依赖程序帧。
- 产物内部 AssemblyName 固定为 `output`，不随输出名变化（控制台 `$PSCommandPath` 取自 exe 路径；窗口化标题运行期取 exe 文件名），因此全部产物都能跨输出名复用。
- 长期未用条目会自动清理。

### Core 工程缓存（`cache\core`）

- 按「TFM/RID/选项/程序集名」缓存生成的 dotnet 工程，命中即 `dotnet publish/build --no-restore`（省一次 NuGet 还原）。
- `Build.Core.Backend` 决定用哪个后端：`Shared`（默认）走 `CoreCompiler.ps1`，从目标机 `$PSHOME` 解析 SMA；`Bundled` 走 `CoreBundledCompiler.ps1`，打包 `Microsoft.PowerShell.SDK`，支持 `SelfContained`/`Trimmed`/`ReadyToRun`/`InvariantGlobalization`/`Aot` 与 `PowerShellVersion`。两个后端的工程文件每次编译都会重写，缓存键只收录还原输入，且 `--no-restore` 失败会自动退回完整还原，因此无需手动 bump 版本标记。
- 两者共用 `Get-CacheRoot 'core'` 目录与 `Clear-StaleCache`：`src/CoreProject.ps1` 提供 `Get-CoreDotnet`/`Get-CoreBuildKey`/`Enter-CoreProject`（缓存工程目录 + 命名互斥量 + stale 清理）/`Invoke-CoreDotnet`（`--no-restore` 与失败重试）/`Copy-CorePublishOutput`（`SingleFile=$false` 时发布整个目录并拷到 `outputFile` 所在目录）与 `Get-GuiFrameworkUsage`。

### 打包压缩与 LZMA（`cache\gzip` / `cache\lzma`）

- 非常量产物 = launcher（`src/programFrames/pack.cs`）+ 「main」资源（压缩后的 payload）。默认压缩是 Windows PowerShell（CodeDom）下 gzip、Core 下 Brotli。
- Framework 的 gzip 由 `src/Gzip.ps1` 调用内置纯 C# 编码器 `src/programFrames/GzipEncode.cs`（移植自 7-Zip 的标准 Deflate 核心：level 9、fast bytes 258、passes 15，保留 Bt3Zip 二叉树匹配与多轮 Huffman），`GzipWrapper.cs` 写固定 gzip 头（无文件名、时间戳 0、XFL=2、OS=255）。无需原生辅助 EXE/P-Invoke/unsafe/本机 7-Zip；失败显式报错，不切换算法。普通 EXE 和原生导出 DLL 共用此路径，产物用 GZipStream 解码。
- 编码器与 wrapper 按需 `Add-Type`，缓存到 `%TEMP%\ps12exe\cache\gzip`（键含固定源码与宿主 PowerShell 版本，受命名互斥量保护），压缩全在内存完成、不写临时文件；类型名含源码哈希避免模块重载误用旧实现，自编译时内嵌两份 C# 源码。LGPL-2.1-or-later 许可随 `GzipLicense.txt`/`GzipCopying.txt` 发布。
- 已确定的帧裁剪：去掉未引用的私有 CredUI/控制台枚举字段与 `SetConsoleMode`；诊断流被 `App.Silence` 全禁用时不编译其上色 helper；原生导出 DLL 不编入 EXE 的私有 Main/命令行 PSD 入口。公共宿主接口不能仅凭 AST 未出现某个命令就移除（模块、动态命令和 `$Host.UI` 运行期可调用）。
- `src/Cache.ps1` 的 `Set-DeterministicPeIdentity` 在 gzip/LZMA 前规范化 CodeDom 负载、在最终 ExeSinker/DLL 导出之后与签名之前规范化产物（清 COFF/资源目录/导出表时间戳、旧校验和与随机 MVID，用完整规范化镜像的 SHA-256 前 16 字节派生 MVID）；调试/KeepSource 跳过，Core/TinySharp 各走各的。固定工具链/引用/选项下可复现，但不同工具链、依赖版本、签名时间戳与外部资源仍属不同构建输入。
- 大脚本长距重复超出 gzip 32KB 窗口，故打包时还尝试 LZMA1：编解码器来自 7-Zip LZMA SDK 19.00 C# 源码（public domain），拆成 `LzmaCommon.cs`（共用接口/常量）、`LzmaDecode.cs`（解码器，随 launcher 编入）、`LzmaEncode.cs`（编码器，仅打包用）。`src/Lzma.ps1` 把共用定义与编码器按需 `Add-Type` 编译并缓存成 `cache\lzma` 下的 DLL（键含 PSEdition/版本/源码内容），失败回退默认压缩；解码器只保留独立流解码入口。
- `pack.cs` 用 `#if CodecLzma` 选择 `LzmaCodec.DecompressStream`；负载容器是 `PS12LZMA` 魔数 + LZMA props + 未压缩长度 + 数据，`exe21sp.cs` 靠魔数识别（gzip 靠 `1F 8B`，否则按 Brotli 反射解压）。
- 启用判据：CodeDom 生成 gzip/LZMA 两版 launcher 取最终字节小者（LZMA 解码器约增 10KB，小脚本通常回退 gzip）；Core 无帧模板可原地补丁、双次 `dotnet publish` 太贵，改用「LZMA 流 + 12KB 开销预算 < Brotli 流」。两条路径都只对 >=32KB 负载尝试 LZMA 以控制编码成本。RangeCoder Encoder/BitEncoder/BitTreeEncoder 仅放在 `LzmaEncode.cs`。
- 编码器类型名是 `LzmaPackCodec`（不是 `LzmaCodec`）：ps12exe 自身被编成 exe 且其 launcher 走 LZMA 时，产物里会带一个只有解码器的 `LzmaCodec`，按名字找编码器会误命中。

<a id="core-gui-and-addtype"></a>

## Core 目标的 GUI 框架与 Add-Type

- **WinForms/WPF**：console 应用默认不引用 WindowsDesktop 框架。`src/CoreProject.ps1` 的 `Get-GuiFrameworkUsage` 从预处理后的脚本文本粗判（宁可多开也不漏，误判只让产物多带框架引用）：
  - 命中 `System.Windows.Forms`/`System.Drawing` → `UseWindowsForms`。仅 `Bundled` 需要（Shared 下 WinForms 由 CoreHost 从 `$PSHOME` 解析，不额外依赖 Desktop 共享运行时）；`noConsole` 本来就用。
  - 命中 `System.Windows.*`/`PresentationFramework`/`PresentationCore`/`WindowsBase` → `UseWPF`（Shared/Bundled 都需要）。否则 `Add-Type -AssemblyName PresentationFramework` 会解析到 .NET Framework 的 GAC 版本，`[System.Windows.Window]` 找不到。`UseWPF` 要求 TFM 带 `-windows`。
- **Add-Type**：`AddTypeCommand` 的静态初始化器把「入口程序集目录 `\ref`」当引用程序集目录（`Shared` 的宿主应用里入口程序集是用户的 exe，单文件下其 `Location` 还为空，会直接 `ArgumentNullException`）。`CoreCompiler.ps1` 在脚本命中 `Add-Type` 且 `$PSHOME\ref` 存在时，把 `$PSHOME\ref\*.dll` 作为 `Content` 随 launcher 发布，单文件下再加 `IncludeAllContentForSelfExtract`（自解压后入口程序集 `Location` 指向解压目录、ref 就在旁边）。没用 Add-Type 就不带（ref 约 6MB，Shared 的卖点是小）。`Bundled` 后端由 SDK 自带 ref；缓存键相应含 `needsRef`。详见 PS2EXE.Core #6/#24。

<a id="codedom-cache"></a>

### CodeDom 帧模板缓存（`cache\codedom`）

非常量 Framework 打包把两个**程序帧**（payload 的 `default.cs`、launcher 的 `pack.cs`）按「帧源码 + 选项 + 引用 + 编译器版本 + 占位桶」缓存成**模板**（launcher 键另含清单/图标的内容哈希，因为 csc 的 assembly name 固定为 `output`、清单/图标路径不含在键里，所以产物可跨输出名复用）。

- 资源/版本属性抽到公共片段 `src/programFrames/AssemblyInfo.cs`（无 using、全限定名），三个帧里只留标记 `/*__ASSEMBLY_ATTRIBUTES__*/`：`BuildFrame.ps1` 把片段替换 `$placeholder` 成 `$resourceAttributes`，payload 编译时标记替换为空、launcher/直编帧替换为 `$resourceAttributes`——所以 payload 帧不随资源参数变化、模板可跨资源复用；文件属性由最外层（launcher/直编自身）携带，窗口标题运行期从 `Assembly.GetEntryAssembly()` 读。
- 模板是带 bucket 大小零占位资源的原始 csc 产物；每次编译用 `Set-FrameResource` 按 PE 解析定位那份唯一托管资源，原地覆写 `[Int32 长度][数据]` 并同步 CLI 资源目录大小（纯字节补丁、不做 PE 重排），随后照旧走 ExeSinker，所以产物大小与不缓存时一致（字节不必一致：MVID/时间戳本就每次编译都变；但缓存命中同一输入时产物是确定的，与输出名无关）。
- 占位桶按 64B 粒度（`Get-CacheBucket`）。粒度决定模板里托管资源槽的大小：csc 会把资源槽按 `FileAlignment`（512）对齐进 `.text`，槽比实际资源大多少，产物就白多多少，64B 粒度把额外体积压到 <64B；脚本变大自动换更大桶的模板，超 64MB 放弃缓存直编。键哈希了全部编译输入，任何输入变化都会生成新模板，因此不需要版本号/version.txt。
- **坑**：凡返回字节数组都必须加前置逗号（`return ,$bytes`），`Get-CachedBytes` 与 `Set-FrameResource` 都踩过——否则 PowerShell 会把 `byte[]` 展开成 `Object[]`，大脚本逐字节装箱会明显变慢（原地写的那份仍正确，只是慢）。
- 结论：这缓存只省掉两次 csc，小脚本收益在噪声内、大脚本与直编持平；当前 CodeDom 编译瓶颈是 ExeSinker 每次 `Add-Type` 加载 AsmResolver，想再提速优先从那里下手。
- **不要用空 `.res`（csc `/win32res` 指向空资源）绕过 ExeSinker**（已试过并回退）：只快 ~0.2s，却要额外维护一份易错的 PE 字节补丁，产物反而更大（AsmResolver 重建 PE 会丢整段 `.rsrc`，纯字节补丁只能断开资源树、`.rsrc` 仍在）。

<a id="cmd-availability"></a>

## 命令可用性分析（Unknown / MayNotBeAvailable 诊断）

- `ps12exe.ps1` 在 AST 分析后对 `UsedNonConstFunctions` 做**定向解析**（只对脚本实际用到的名字各调一次 `Get-Command $_`，取代旧的全量枚举），再按解析结果的 `CommandType` 分三类：
  - `Alias`/`Function`/`Filter`/`Cmdlet`：会话内命令，静默通过；
  - `Application`/`ExternalScript`（PATH 上的程序与外部脚本）：记 `$FoundCmdlets`，打 `Warning.SomeCmdletsMayNotAvailable`——「现在能跑，但编译出的 exe 在目标机上未必还有」；
  - 解析不到且名字不含 `]::`：记 `$NotFoundCmdlets`，打 `Warning.SomeNotFoundCmdlets`；含 `]::` 的成员调用跳过（静态解析 Add-Type 太复杂）。
- **坑**：无参 `Get-Command` 只枚举 `Alias`/`Function`/`Filter`/`Cmdlet`，**不含** PATH 上的 `Application`/`ExternalScript`（`deno`/`cmd`/`node` 都属后者）。所以「`Get-Command <name>` 能解析」≠「该名字在 `(Get-Command).Name` 里」；判断类别务必看解析结果的 `.CommandType`，别把 `$FoundCmdlets` 当死代码删（否则 `deno` 这类外部依赖不再有任何提醒）。

<a id="asmresolver-trim"></a>

## AsmResolver 裁剪与合并

`src/bin/AsmResolver.dll` 是单个合并后的程序集：由 `tools/AsmResolver/Update-AsmResolver.ps1` 先拉一份完整 AsmResolver，以 `Root.cs` + 运行时编译的 `TinySharp.cs`/`exe21sp.cs`/`LzmaDecode.cs` 为根跑 illink 裁剪，再用 ILRepack（`dotnet tool install --tool-path <work>/tools/ilrepack dotnet-ilrepack`）把裁剪后的 5 个程序集合并成单文件，直接写到 `src/bin` 下。

- 合并省掉 4 份程序集清单/元数据表/重定位（nupkg 约小 30 KB）；产物仍是 netstandard2.0，PS 5.1 与 PS 7 都能加载，跨程序集 `internal` 调用不受影响。
- 常量字段不再整类保留：`LinkerRoots` 用 SDK 自带 Roslyn 绑定根源码实际引用的 const/enum 字段（含别名、`using static`、嵌套类型），生成逐字段 linker descriptor。C# 会把常量内联进 IL，只从 IL 推导可达性会误删运行期 `Add-Type` 所需的字段；PowerShell 直接访问的常量同样须在 `Root.cs` 镜像。
- 发布包由 `tools/Packaging/New-Package.ps1` 在临时目录构建：按 Git 跟踪文件及发布排除规则取材，Windows PowerShell 5.1 的 `Publish-Module` 生成元数据，再用 7-Zip 标准 ZIP Deflate（`-mx=9 -mfb=258 -mpass=15`）重压缩并逐条校验文件名、长度与 SHA-256；`.github/workflows/Publish.ps1` 直接推送验证后的 nupkg。可用 `pwsh tools/Packaging/New-Package.ps1 -OutputDirectory <目录>` 本地重现（需 WinPS 5.1、Git、7-Zip）。
- 加载点统一 `Add-Type -LiteralPath (Join-Path <...>/bin/AsmResolver.dll)`（`ExeSinker.ps1` 曾按分体文件名 `AsmResolver.PE*.dll` 枚举，合并后已改为直接加载单个文件）；新增加载点请沿用同一路径。
- `AsmResolverTrimmer.csproj` 必须把 `LzmaCommon.cs` 和 `LzmaDecode.cs` 一起编译（`exe21sp.cs` 引用 `LzmaCodec`），否则根程序集构建失败。

- 来源用 `-Source` 选：`NuGet`（默认，`-Version` 指定版本）、`Ci`/`Pr`（CI 构建产物，缺失或过期自动回退 `Source`）、`Source`（本地 `dotnet build`）、`Local`（`-AssemblyDirectory` 复用已有完整程序集）；`-RunId` 可指定某次 CI run。
- 当前 `src/bin/AsmResolver.dll` 是 `-Source Source -Pr 793` 的本地构建（含导出名排序修复，上游 PR 未合并）；上游合并后应改回 `./Update-AsmResolver.ps1 -Source NuGet` 重跑。
- 运行期要用到任何**新的** AsmResolver API（例如托管资源写入 `ModuleDefinition.FromFile` / `ManifestResource.EmbeddedDataSegment` setter / `DataSegment`），必须先在 `tools/AsmResolver/Root.cs` 里镜像一段该用法，再重跑 `./tools/AsmResolver/Update-AsmResolver.ps1 -Version 6.0.1`，否则对应成员会被裁掉、运行期 `Add-Type` 后调用报 MissingMethod/TypeLoad。
- 裁剪版必须保留 netstandard2.0 引用以兼容 WinPS 5.1 与 pwsh 7。
- 从 PowerShell 驱动 AsmResolver.DotNet 的两个坑：`MethodDefinition.Name`/`TypeDefinition.Name` 是 `Utf8String`，用 `-eq 'X'` 比较会失败（PS 会把它当字符枚举），要写 `$_.Name.ToString() -eq 'X'`；`[Flags]` 枚举的 `-bor`/`-bnot` 在本仓库的 StrictMode 下会抛 InvalidCastException，位运算前先 `[int]` 转换再用 `[枚举类型](...)` 转回。
- 该工具会在 `tools/AsmResolver/{bin,obj}` 留下无 BOM 的生成 `.cs`，`Get-RepoFiles` 已排除 `bin|obj`。

<a id="darkmode"></a>

## Windowed 产物的深色模式（`App.DarkMode`）

`default.cs` 里的 `DarkMode` 只在 windowed（`noConsole`）且非 `Off` 时编译：`InitCompileThings.ps1` 最多追加 `darkModeOff`/`darkModeOn` 两个常量，`Auto` 不定义额外常量——`Off` 整段不编译（零开销），`On` 跳过系统探测直接置 `IsDark`，`Auto` 运行时读 `HKCU\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize\AppsUseLightTheme`。

- 进程级开启：uxtheme 未公开序号 `132`=`ShouldAppsUseDarkMode`、`133`=`AllowDarkModeForWindow`、`135`=`SetPreferredAppMode`（<18362 为 `AllowDarkModeForApp`）、`136`=`FlushMenuThemes`、`104`=`RefreshImmersiveColorPolicyState`（编号取自 [ysc3839/win32-darkmode](https://github.com/ysc3839/win32-darkmode)，勿依早期文档把 132/133 当成 SetPreferredAppMode/FlushMenuThemes）；标题栏 `DwmSetWindowAttribute`（attr 20，旧 build 19）。
- 控件染色：目标 TFM 为 .NET 9+ 且运行于 Win11 时，编译产物包含官方 `Application.SetColorMode(Dark)` 反射调用（绕过 `WFO5001` 实验性诊断），官方实现天然覆盖所有 WinForms 控件；Framework 和较旧 Core 目标会在编译期剔除这段不可能使用的代码，其余运行时走 `ThemeForm` 递归改色 + `SetWindowTheme("DarkMode_Explorer"...)`，Button 转 Flat、TextBox/ListBox 用 FixedSingle 边框。
- **Auto 实时跟随系统深浅切换**：`Auto` 时在 UI 线程建一个隐藏窗口（`ThemeChangeWindow`）监听 `WM_SETTINGCHANGE`，lParam 含 `ImmersiveColorSet`（广播带 lParam=0 时保守重探）就重新读注册表并 `ApplySystemDark`：官方路径再调 `SetColorMode(Dark/Classic)`；手动路径遍历本进程窗口重绘——深色时按原色判断染色、浅色时用记录的原始颜色精确还原（`ControlOriginalColors`），因此双向都能即时切换。`On` 编译期强制暗色，不需要监听器。
  - 坑：改 `Form.BackColor` 会把「仍用系统色」的子控件一起带上（WinForms 行为），所以 `ThemeForm` 必须**先遍历整棵树记录原始色、再统一应用**，否则记录到的是被污染的值，浅色还原失效。
- **内置对话框**：`DarkMode='Off'` 时消息输出使用系统 `MessageBox.Show`，窗口化常量提示也恢复系统消息框；`On`/`Auto` 使用自绘 `MessageBoxHelper` / `constexpr.cs` 窗体。`Input_Box`、`Choice_Box`、`ReadKey_Box` 和 `Progress_Form` 在父提交中就已是 WinForms 窗体，因此不随 `DarkMode` 切换为系统对话框；进度条使用自绘 `FlatProgressBar`。`Progress_Form` 在独立 STA 消息线程运行并接收跨线程进度更新，本地化的 Cancel 按钮可在脚本执行期间停止当前 PowerShell 流水线。`Credential_Form` 仍通过系统 CredUI 提示凭据。标题栏深浅统一走 `SystemDialogText`（`SetDarkTitleBar` 处理 DWM，`ApplyTitleBar` 在暗色可用时转交 `DarkMode.DarkTitleBar`），勿在各对话框里重复声明 `DwmSetWindowAttribute`。
- **窗口化产物的体积裁剪**：`noConsole` 时不少控制台专用代码在编译期剔除——`Console_Info` 仅在 `!noConsole || ReadInput` 时编译（`SupportsVirtualTerminal` 对窗口化直接返回 `false`），`getPassword` 仅在 `!noConsole` 时编译，4 参数的 `PromptForCredential` 在窗口化下复用 6 参数重载。另一坑：`$Host.PrivateData` 直接包装 `PSRunnerUI`（不再经 `ConsoleColorProxy`），因此 `rawUI` 字段**必须保持私有**，否则与 `RawUI` 属性形成仅大小写不同的成员、`PSObject.AsPSObject` 会抛 CLS 冲突。
  - 量体积的经验：产物（launcher + gz 负载）按 512 字节 `FileAlignment` 与 64 字节占位桶对齐，gzip 省下的零头会被填充吃掉，所以只有累计省够约一个 512 字节块，文件才会真正变小；调试时把 payload 解压出来对比 `gz`/`payload` 字节数比直接看 exe 大小灵敏。判断某段代码是否可剪，先用「删掉它再编译对比」验证收益，别靠直觉。
- **消除首帧闪白**：WinEvent（异步）和 timer（太慢）都晚于首次绘制，不可用。改为在脚本线程用 `RegisterShellHookWindow` 监听 `HSHELL_WINDOWCREATED`——hook 窗口必须由脚本线程创建；窗口化暗色产物将 runspace 设为 `PSThreadOptions.UseCurrentThread`，宿主在 `BeginInvoke` 前由 C# 调用 `DarkMode.StartOnCurrentThread`，确保 hook 与用户脚本及其窗口同线程；再 `SetWindowSubclass` 拦截首个 `WM_PAINT`/`WM_ERASEBKGND`，在 WinForms 绘制前同步染色；且 `ThemeForm` 必须先改颜色再动 DWM/主题，否则设置标题栏触发的重绘会让首帧仍是亮色。托管 `SetWindowsHookEx(WH_CBT)` 不会回调、`SetWinEventHook(EVENT_OBJECT_CREATE)` 是异步的，都不可用。
- 常量 GUI（`constexpr.cs` / TinySharp）：TinySharp 是裸 IL 壳、无法在运行时探测/自绘暗色；窗口化 Framework 常量在 `DarkMode='Off'` 时走 TinySharp 的原生 `MessageBoxW` 精简壳，`On`/`Auto` 及 `requireAdmin` 走 `constexpr.cs` WinForms 信息窗体。控制台常量脚本仍走 ~1KB 的 TinySharp 壳；Core 常量脚本走 constexpr。
- 局限：只暗化本 exe 自己创建的 WinForms 窗口，不碰系统的运行框/控制面板（那需要在 explorer 等进程里注入 + subclass，参考 StartAllBack 的 `DarkMagicX64.dll`）；自绘/第三方控件、图片资源不跟随。
