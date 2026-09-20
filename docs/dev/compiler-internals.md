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
- `#_DllExport` 功能尚未实现，只作注释。
- 目标：任意 exe 往返后有效内容不变、不膨胀。

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
- 改 `CoreCompiler.ps1` 的工程结构时同步 bump 其中的 `corecache-vN` 标记。

<a id="codedom-cache"></a>

### CodeDom 帧模板缓存（`cache\codedom`）

非常量 Framework 打包把两个**程序帧**（payload 的 `default.cs`、launcher 的 `pack.cs`）按「帧源码 + 选项 + 引用 + 编译器版本 + 占位桶」缓存成**模板**（launcher 键另含清单/图标的内容哈希，因为 csc 的 assembly name 固定为 `output`、清单/图标路径不含在键里，所以产物可跨输出名复用）。

- 资源/版本属性抽到公共片段 `src/programFrames/AssemblyInfo.cs`（无 using、全限定名），三个帧里只留标记 `/*__ASSEMBLY_ATTRIBUTES__*/`：`BuildFrame.ps1` 把片段替换 `$placeholder` 成 `$resourceAttributes`，payload 编译时标记替换为空、launcher/直编帧替换为 `$resourceAttributes`——所以 payload 帧不随资源参数变化、模板可跨资源复用；文件属性由最外层（launcher/直编自身）携带，窗口标题运行期从 `Assembly.GetEntryAssembly()` 读。
- 模板是带 bucket 大小零占位资源的原始 csc 产物；每次编译用 `Set-FrameResource` 按 PE 解析定位那份唯一托管资源，原地覆写 `[Int32 长度][数据]` 并同步 CLI 资源目录大小（纯字节补丁、不做 PE 重排），随后照旧走 ExeSinker，所以产物大小与不缓存时一致（字节不必一致：MVID/时间戳本就每次编译都变；但缓存命中同一输入时产物是确定的，与输出名无关）。
- 占位桶按 64B 粒度（`Get-CacheBucket`）。粒度决定模板里托管资源槽的大小：csc 会把资源槽按 `FileAlignment`（512）对齐进 `.text`，槽比实际资源大多少，产物就白多多少，64B 粒度把额外体积压到 <64B；脚本变大自动换更大桶的模板，超 64MB 放弃缓存直编。键哈希了全部编译输入，任何输入变化都会生成新模板，因此不需要版本号/version.txt。
- **坑**：凡返回字节数组都必须加前置逗号（`return ,$bytes`），`Get-CachedBytes` 与 `Set-FrameResource` 都踩过——否则 PowerShell 会把 `byte[]` 展开成 `Object[]`，大脚本逐字节装箱会明显变慢（原地写的那份仍正确，只是慢）。
- 结论：这缓存只省掉两次 csc，小脚本收益在噪声内、大脚本与直编持平；当前 CodeDom 编译瓶颈是 ExeSinker 每次 `Add-Type` 加载 AsmResolver，想再提速优先从那里下手。
- **不要用空 `.res`（csc `/win32res` 指向空资源）绕过 ExeSinker**——已试过并回退：「编译快 ~0.2s」换「产物更大 + 多维护一份易错的 PE 字节补丁」。AsmResolver 的 `Resources = $null` 重建 PE 会连整段 `.rsrc` 一起丢掉，而纯字节补丁只能断开资源树、`.rsrc` 仍在（产物反而大 1KB 上下）；且清 `DynamicBase` 也归 ExeSinker 管，复刻它要求 `Cache.ps1` 自解析可选头/资源根目录，还会让 `ExeSinker` 里 `-band -not`（逻辑取反，会把 `0x8540` 整个清零、连 `NX_COMPAT` 一起丢）的历史 bug 换个地方重现。

<a id="cmd-availability"></a>

## 命令可用性分析（Unknown / MayNotBeAvailable 诊断）

- `ps12exe.ps1` 在 AST 分析后对 `UsedNonConstFunctions` 做**定向解析**（只对脚本实际用到的名字各调一次 `Get-Command $_`，取代旧的全量枚举），再按解析结果的 `CommandType` 分三类：
  - `Alias`/`Function`/`Filter`/`Cmdlet`：会话内命令，静默通过；
  - `Application`/`ExternalScript`（PATH 上的程序与外部脚本）：记 `$FoundCmdlets`，打 `Warning.SomeCmdletsMayNotAvailable`——「现在能跑，但编译出的 exe 在目标机上未必还有」；
  - 解析不到且名字不含 `]::`：记 `$NotFoundCmdlets`，打 `Warning.SomeNotFoundCmdlets`；含 `]::` 的成员调用跳过（静态解析 Add-Type 太复杂）。
- **坑**：无参 `Get-Command` 只枚举 `Alias`/`Function`/`Filter`/`Cmdlet`，**不含** PATH 上的 `Application`/`ExternalScript`（`deno`/`cmd`/`node` 都属后者）。所以「`Get-Command <name>` 能解析」≠「该名字在 `(Get-Command).Name` 里」。曾据此把 `$FoundCmdlets` 当死代码连同 `SomeCmdletsMayNotAvailable` 一起删掉，会让 `deno` 这类外部依赖不再有任何提醒。判断类别务必看解析结果的 `.CommandType`。

<a id="asmresolver-trim"></a>

## AsmResolver 裁剪

`src/bin/AsmResolver` 里的 DLL 是 **illink 裁剪过的**（`tools/AsmResolver/Update-AsmResolver.ps1`：拉完整 NuGet → 以 `Root.cs` + 运行时编译的 `TinySharp.cs`/`exe21sp.cs` 为根跑 illink）。

- 运行期要用到任何**新的** AsmResolver API（例如托管资源写入 `ModuleDefinition.FromFile` / `ManifestResource.EmbeddedDataSegment` setter / `DataSegment`），必须先在 `tools/AsmResolver/Root.cs` 里镜像一段该用法，再重跑 `./tools/AsmResolver/Update-AsmResolver.ps1 -Version 6.0.1`，否则对应成员会被裁掉、运行期 `Add-Type` 后调用报 MissingMethod/TypeLoad。
- 裁剪版必须保留 netstandard2.0 引用以兼容 WinPS 5.1 与 pwsh 7。
- 该工具会在 `tools/AsmResolver/{bin,obj}` 留下无 BOM 的生成 `.cs`，`Get-RepoFiles` 已排除 `bin|obj`。
