# ps12exe

> [!CAUTION]
> 不要在源代码中存储密码！  
> 参阅[这里](#密码安全)了解更多详情。

## 简介

ps12exe 是一个 PowerShell 模块，用于从 .ps1 脚本生成可执行文件。

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery download num](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![CodeFactor](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![repo img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

[![English (United Kingdom)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-Kingdom.png)](./README_EN_UK.md)
[![English (United States)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-States.png)](./README_EN_US.md)
[![日本語](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Japan.png)](./README_JP.md)
[![Français](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/France.png)](./README_FR.md)
[![Español](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Spain.png)](./README_ES.md)
[![हिन्दी](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/India.png)](./README_HI.md)

## 使用它的项目

- [fount](https://github.com/steve02081504/fount)
- [SessionTracker](https://github.com/quinncthirtyone/SessionTracker)
- [GStreamer-Glass](https://github.com/Geofferey/GStreamer-Glass)
- [MailboxManager](https://github.com/TestGroundControl/MailboxManager)
- [always-accompany](https://github.com/beilusaiying/always-accompany)

## 安装

```powershell
Install-Module ps12exe #安装ps12exe模块
Set-ps12exeIntegration #设置右键菜单、Agent Skill 与 VS Code 扩展
```

（也可以克隆本仓库后直接运行 `.\ps12exe.ps1`。）

**从 PS2EXE 迁到 ps12exe 很麻烦？不用担心。**  
PS2EXE2ps12exe 会把对 PS2EXE 的调用转到 ps12exe。卸载 PS2EXE、安装本模块后，仍可按以往方式使用 PS2EXE。  
它最大程度兼容各版本 PS2EXE 的参数（含 `conHost`、`embedFiles` 和旧版的 `runtime20`/`runtime40`），ps12exe 缺少的能力会在编译期转写为等价实现。

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## 使用方法

### 右键菜单

运行 `Set-ps12exeIntegration` 后，在任意 `.ps1` 文件上右键即可快速编译为 exe，或以此文件启动 ps12exeGUI。  
![图片](https://github.com/steve02081504/ps12exe/assets/31927825/24e7caf7-2bd8-46aa-8e1d-ee6da44c2dcc)

### GUI 模式

```powershell
ps12exeGUI
```

### 控制台模式

```powershell
ps12exe .\source.ps1 .\target.exe
```

将`source.ps1`编译为`target.exe`（如果省略`.\target.exe`，输出将写入`.\source.exe`）。

```powershell
'"Hello World!"' | ps12exe
```

将`"Hello World!"`编译为可执行文件输出到`.\a.exe`。

```powershell
ps12exe https://raw.githubusercontent.com/steve02081504/ps12exe/master/src/GUI/Main.ps1
```

将来自互联网的`Main.ps1`编译为可执行文件输出到`.\Main.exe`。

### 从 exe 还原 ps1（exe21sp）

```powershell
exe21sp -inputFile .\target.exe -outputFile .\target.ps1
```

`exe21sp` 用于从 ps12exe 生成的 exe（本地路径或 URL）中提取其中的 PowerShell 脚本，并写入 `.ps1` 文件或输出到标准输出。与 ps12exe 相同，exe21sp 使用 `$LastExitCode` 表示结果：0 = 成功，1 = 输入/解析错误（如不是 ps12exe 生成的 exe），2 = 调用错误（如重定向时无输入），3 = 资源/内部错误（如文件不存在）。

### 管道与重定向

- **ps12exe**：当标准输出（或标准输入/标准错误）被重定向时，ps12exe 仅将生成的 exe 路径写入标准输出，便于捕获（如 `$exe = ps12exe .\a.ps1`）。
- **exe21sp**：可从管道接收 exe 路径或 URL（如 `Get-ChildItem *.exe | exe21sp` 或 `".\app.exe" | exe21sp`）。
- **exe21sp**：未指定 `-outputFile` 且标准输出**未**被重定向时，将反编译结果保存为与 exe 同目录、同主文件名的 `.ps1` 文件。
- **exe21sp**：未指定 `-outputFile` 且标准输出**已**被重定向时，将反编译结果写入标准输出。

### 自托管Web服务

```powershell
Start-ps12exeWebServer
```

启动 Web 服务，便于在浏览器中在线编译 PowerShell 脚本。

### VS Code 插件

[ps12exe VS Code 插件](https://marketplace.visualstudio.com/items?itemName=steve02081504.ps12exe)让你无需离开编辑器即可把 `.ps1` 脚本编译为可执行文件或打开 ps12exeGUI，并为预处理指令提供语法高亮、诊断、`#_if` 自动闭合、折叠、转到定义、悬停、补全和格式化等编辑支持。

![image](https://github.com/user-attachments/assets/5cace798-2737-479a-8d1e-882484f26f31)

`Set-ps12exeIntegration` 会自动安装它，你也可以手动安装 `steve02081504.ps12exe`。

### Agent Skill

`Set-ps12exeIntegration` 还会把 `ps12exe` 的 Agent Skill 写入 `~/.agents/skills`，让支持 Agent Skill 的编码 agent（opencode、Codex、Cursor、GitHub Copilot 等）在需要把 PowerShell 脚本编译为可执行文件时知道使用 ps12exe。执行 `Set-ps12exeIntegration -action disable` 会将其移除，`Set-ps12exeIntegration -Skip AgentSkill` 则跳过它。

## 参数

### GUI参数

```powershell
ps12exeGUI [[-ConfigFile] '<配置文件>'] [-PS1File '<脚本文件>'] [-Locale '<语言代码>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<脚本文件>'] [-Locale '<语言代码>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : 要加载的配置文件。
PS1File    : 要编译的脚本文件。
Locale     : 要使用的语言代码。
UIMode     : 要使用的用户界面模式。
help       : 显示此帮助信息。
```

### 控制台参数

<a id="console-parameters"></a>

```powershell
[input |] ps12exe [[-inputFile] '<文件名|url>' | -Content '<脚本>'] [-outputFile '<文件名>']
        [-App @{Windowed=$true; Silence=@('Output','Error'); OutputEncoding='UTF8'|'UTF16LE'|'Default'; VisualStyles=$true; DarkMode='Auto'|'On'|'Off';
        ExitOnCancel=$true; CredentialGUI=$true; DpiAware=$true; WinFormsDpiAware=$true; ConHost=$true}]
        [-Os @{Admin=$true; ModernOS=$true; LongPaths=$true; Virtualize=$true}]
        [-Build @{Target='Framework4.0'|'Framework2.0'|'Core'; Platform='AnyCpu'|'x64'|'x86'|'arm64'; Apartment='STA'|'MTA';
        Culture='<文化>'; Options='<选项>'; KeepSource=$true; Minify={<scriptblock>}; TempDir='<文件夹>';
        Core=@{Backend='Shared'|'Bundled'; TargetOs='Windows'|'Linux'|'MacOS'; TargetFramework='<net8.0>'; PowerShellVersion='<version>'; SingleFile=$true; SelfContained=$true; Trimmed=$true; TrimMode='partial'|'full'; ReadyToRun=$true; InvariantGlobalization=$true; Aot=$true}}]
        [-Resources @{Icon='<文件名|url>'; Title='<标题>'; Description='<简介>'; Company='<公司>';
        Product='<产品>'; Copyright='<版权>'; Trademark='<水印>'; Version='<版本>'}]
        [-Signing @{Certificate='<PFX文件路径>'; Password='<PFX密码>'; Thumbprint='<证书指纹>'; Timestamp='<时间戳服务器>'}]
        [-PreprocessOnly] [-Golf] [-Sandbox] [-NoUpdateCheck] [-Quiet] [-Locale '<语言代码>'] [-ConfigFile] [-help]
```

```text
input            : PowerShell脚本文件内容的字符串，与-Content相同。
inputFile        : 您想要转换为可执行文件的PowerShell脚本文件路径或URL（文件必须是UTF8或UTF16编码）
Content          : 您想要转换为可执行文件的PowerShell脚本内容
outputFile       : 目标可执行文件名或文件夹，默认为带有'.exe'扩展名的inputFile
App              : 描述生成的应用程序行为的哈希表。支持的键：
                   Windowed         : 生成的可执行文件将是一个没有控制台窗口的Windows Forms应用程序。
                   Silence          : 要静默的输出流；可取 'Output'、'Verbose'、'Error'、'Warning'、'Debug' 中的一个或多个，或 '*' 表示全部。
                   OutputEncoding   : 控制台输出编码；'Default'、'UTF8' 或 'UTF16LE'。
                   VisualStyles     : 为GUI应用程序启用视觉样式（默认 $true）。
                   DarkMode         : 窗口化 GUI 产物的 WinForms 深色主题；'Auto' 跟随系统主题，'On'/'Off' 强制。
                   ExitOnCancel     : 当在Read-Host输入框中选择Cancel或'X'时退出程序。
                   CredentialGUI    : 在控制台模式下使用GUI提示凭据。
                   DpiAware         : 将编译的可执行文件标记为DPI感知。
                   WinFormsDpiAware : 让WinForms使用DPI缩放（需要Windows 10和.Net 4.7或更高版本）。
                   ConHost          : 强制使用 conhost 控制台而非 Windows 终端；会禁用输入/输出/错误重定向。
Os               : 操作系统集成选项的哈希表。支持的键：
                   Admin            : 如果启用了UAC，编译的可执行文件只能在提升的上下文中运行（如果需要，会出现UAC对话框）。
                   ModernOS         : 使用最新Windows版本的功能（执行[Environment]::OSVersion以查看差异）。
                   LongPaths        : 如果在OS上启用，启用长路径（> 260个字符）（仅适用于Windows 10或更高版本）。
                   Virtualize       : 已激活应用程序虚拟化（强制x86运行时）。
Build            : 构建选项的哈希表。支持的键：
                   Target           : 目标运行时版本，默认为 'Framework4.0'，支持 'Framework2.0' 与 'Core'；'Core' 编译为 PowerShell Core (.NET) 可执行程序（需要编译机与目标机都装有 PowerShell Core 与 .NET，且产物体积大很多）。
                   Platform         : 仅为特定运行时编译。可能的值为 'AnyCpu'、'x64'、'x86' 和 'arm64'（arm64 仅对 'Core' 有效）。
                   Apartment        : 'STA'（单线程单元）或 'MTA'（多线程单元）模式。
                   Culture          : 编译的可执行文件的文化。如果未指定，则为当前用户文化。
                   Options          : 额外的编译器选项（参见 https://msdn.microsoft.com/en-us/library/78f4aasd.aspx）。
                   KeepSource       : 创建有助于调试的信息。
                   Minify           : 在编译之前缩小脚本的脚本块。
                   TempDir          : 存储临时文件的目录（默认为%temp%中随机生成的临时目录）。
                   Core             : 'Core' 目标构建的选项。支持的键：
                                      Backend                : 'Shared'（默认）从目标机的 pwsh 安装中解析 PowerShell，产物较小；'Bundled' 打包 PowerShell SDK（Microsoft.PowerShell.SDK），目标机无需 pwsh，且 SelfContained/Trimmed/ReadyToRun/InvariantGlobalization/Aot 可用，代价是产物体积大很多。
                                      TargetOs               : 目标操作系统：'Windows'、'Linux' 或 'MacOS'（默认：构建机所在系统）。GUI/窗口化输出需要 'Windows'。
                                      TargetFramework        : 目标 .NET 框架名字对象（例如 'net8.0'）。默认为构建机的运行时（Shared）或映射到 PowerShellVersion 的框架（Bundled）。
                                      PowerShellVersion      : 打包的 PowerShell SDK 版本（仅 Bundled）。默认为构建机的 PowerShell 版本。
                                      SingleFile             : 发布单文件可执行程序（默认 $true）。为 $false 时，可执行文件及其依赖会以文件夹形式写出。
                                      SelfContained          : 包含 .NET 运行时（仅 Bundled；默认 $false）。体积大很多，但无需安装运行时。
                                      Trimmed                : 启用 IL 裁剪以减小体积（仅 Bundled；默认 $false）。
                                      TrimMode               : 设置 Trimmed 时的裁剪力度：'partial'（默认，安全）或 'full'（激进，可能破坏反射）。
                                      ReadyToRun             : 预编译程序集以加快启动（仅 Bundled）。
                                      InvariantGlobalization : 使用固定全球化，从自包含构建中移除 ICU 库（仅 Bundled）。
                                      Aot                    : 实验性 Native AOT 编译（仅 Bundled；需要 SelfContained）。PowerShell 大量使用反射，可能破坏某些脚本。
Resources        : 编译的可执行文件的版本资源哈希表（Icon、Title、Description、Company、Product、Copyright、Trademark、Version）。Icon 可以是图标文件路径或URL；对 .exe/.dll 可用 ,<索引> 指定资源图标（默认 0），如 shell32.dll,3。
Signing          : 编译的可执行文件的代码签名选项哈希表（Certificate、Password、Thumbprint、Timestamp）。必须指定 Certificate 或 Thumbprint 之一。
PreprocessOnly   : 预处理输入脚本并在不编译的情况下返回它。
Golf             : 启用golf模式，添加缩写和常用函数。
Sandbox          : 在额外的保护下编译脚本，避免本机文件被访问。
NoUpdateCheck    : 跳过ps12exe的新版本检查。
Quiet            : 编译期间抑制信息性（主机）输出；错误和警告仍会显示。
Locale           : 指定本地化语言。
ConfigFile       : 写一个配置文件（<outputfile>.exe.config）。
Help             : 显示此帮助信息。
```

## 备注

### 错误处理

和大部分powershell函数不同，ps12exe设置`$LastExitCode`变量以表明错误，但不保证完全不抛出异常。  
你可以使用类似以下的方式检查错误的发生：

```powershell
$LastExitCodeBackup = $LastExitCode
try {
	'"some code!"' | ps12exe
	if ($LastExitCode -ne 0) {
		throw "ps12exe failed with exit code $LastExitCode"
	}
}
finally {
	$LastExitCode = $LastExitCodeBackup
}
```

不同的`$LastExitCode`值代表了不同的错误类型：

| 错误类型 | `$LastExitCode`值 |
| -------- | ----------------- |
| 0        | 没有错误          |
| 1        | 输入代码错误      |
| 2        | 调用格式错误      |
| 3        | ps12exe内部错误   |

### 预处理

<a id="preprocessing-overview"></a>

ps12exe 会在编译前对脚本进行预处理。

```powershell
# Read the program frame from the ps12exe.cs file
#_if PSEXE #这是该脚本被ps12exe编译时使用的预处理代码
	#_include_as_value programFrame "$PSScriptRoot/ps12exe.cs" #将ps12exe.cs中的内容内嵌到该脚本中
#_else #否则正常读取cs文件
	[string]$programFrame = Get-Content $PSScriptRoot/ps12exe.cs -Raw -Encoding UTF8
#_endif
```

#### `#_if <condition>`/`#_else`/`#_endif`

<a id="preprocessing-if"></a>

```powershell
$LocalizeData =
	#_if PSScript
		. $PSScriptRoot\src\LocaleLoader.ps1
	#_else
		#_include "$PSScriptRoot/src/locale/en-UK.psd1"
	#_endif
```

现在只支持以下条件： `PSEXE` 和 `PSScript`。  
`PSEXE` 为 true；`PSScript` 为 false。

#### `#_include <filename|url>`/`#_include_as_value <valuename> <file|url>`

<a id="preprocessing-include"></a>

```powershell
#_include <filename|url>
#_include_as_value <valuename> <file|url>
```

将文件 `<filename|url>` 或 `<file|url>` 的内容包含到脚本中。文件内容会插入到 `#_include`/`#_include_as_value` 命令的位置。

与 `#_if` 不同：若文件名未加引号，`#_include` 系列会把行尾空格和 `#` 也当作文件名的一部分。

```powershell
#_include $PSScriptRoot/super #weird filename.ps1
#_include "$PSScriptRoot/filename.ps1" #safe comment!
```

使用 `#_include` 时，文件内容会经过预处理，这允许你多级包含文件。

`#_include_as_value` 会将文件内容作为字符串值插入脚本。文件内容不会被预处理。

在大多数情况下你不需要使用 `#_if` 和 `#_include` 预处理命令来使得脚本在转换为exe后子脚本被正确包含，ps12exe会自动处理类似以下这些情况并认为目标脚本应当被包含处理：

```powershell
. $PSScriptRoot/another.ps1
& $PSScriptRoot/another.ps1
$result = & "$PSScriptRoot/another.ps1" -args
```

#### `#_include_as_(base64|bytes) <valuename> <file|url>`

<a id="preprocessing-include-as"></a>

```powershell
#_include_as_base64 <valuename> <file|url>
#_include_as_bytes <valuename> <file|url>
```

将文件内容在预处理阶段转换为base64字符串或bytes数组插入脚本。文件内容不会被预处理。

以下是一个简单的packer示例：

```powershell
#_include_as_bytes mydata $PSScriptRoot/data.bin
[System.IO.File]::WriteAllBytes("data.bin", $mydata)
```

该exe将在运行后释放编译时被内嵌到脚本中的`data.bin`文件。

#### `#_!!`

<a id="preprocessing-bang"></a>

```powershell
$Script:eshDir =
#_if PSScript #在PSEXE中不可能有$EshellUI
if (Test-Path "$($EshellUI.Sources.Path)/path/esh") { $EshellUI.Sources.Path }
elseif (Test-Path $PSScriptRoot/../path/esh) { "$PSScriptRoot/.." }
elseif
#_else
	#_!!if
#_endif
(Test-Path $env:LOCALAPPDATA/esh) { "$env:LOCALAPPDATA/esh" }
```

任何以`#_!!`开头的行，其开头的`#_!!`会被去除。

#### `#_require <modulesList>`

<a id="preprocessing-require"></a>

```powershell
#_require ps12exe
#_pragma App.Windowed
$Number = [bigint]::Parse('0')
$NextNumber = $Number+1
$NextScript = $PSEXEscript.Replace("Parse('$Number')", "Parse('$NextNumber')")
$NextScript | ps12exe -outputFile $PSScriptRoot/$NextNumber.exe *> $null
$Number
```

`#_require` 统计整个脚本中需要的模块，并在第一次`#_require`前加入等价以下代码的脚本：

```powershell
$modules | ForEach-Object{
	if(!(Get-Module $_ -ListAvailable -ea SilentlyContinue)) {
		Install-Module $_ -Scope CurrentUser -Force -ea Stop
	}
}
```

值得注意的是，它所生成的代码只会安装模块，而不会导入模块。
请视情况使用`Import-Module`。

当你需要require多个模块时，可以使用空格、逗号或分号、顿号作为分隔符，而不必写多行require语句。

```powershell
#_require module1 module2;module3、module4,module5
```

#### `#_pragma`

<a id="preprocessing-pragma"></a>

pragma预处理指令对脚本内容没有任何影响，但会修改编译所使用的参数。  
以下是一个例子：

```powershell
PS C:\Users\steve02081504> '12' | ps12exe
Compiled file written -> 1024 bytes
PS C:\Users\steve02081504> ./a.exe
12
PS C:\Users\steve02081504> '#_pragma App.Windowed
>> 12' | ps12exe
Preprocessed script -> 23 bytes
Compiled file written -> 2560 bytes
```

可以看到，`#_pragma App.Windowed` 使得生成的exe文件以窗口模式运行，即使我们在编译时没有指定`-App @{Windowed=$true}`。
pragma命令可以设置任何编译参数；参数名用 `.` 可以设置嵌套值：

```powershell
#_pragma App.Windowed #窗口模式
#_pragma App.Windowed $false #控制台模式
#_pragma Resources.Icon $PSScriptRoot/icon.ico #设置图标
#_pragma Resources.Title "title" #设置exe标题
#_pragma Signing.Certificate "C:\Cert\mycert.pfx" #设置代码签名证书
```

字符串类型的 pragma 值也可以包含 `$(...)` 子表达式，并在预处理时求值，例如 `#_pragma Resources.Icon $(Join-Path $env:USERPROFILE 'foo.ico')`。仅允许白名单内的 path 相关命令（`Get-Command`、`Join-Path`、`Split-Path`、`Resolve-Path`、`Convert-Path`、`Get-Item`、`Test-Path`、`Get-ChildItem`，以及非沙箱模式下的 `Get-Content`）、变量（`$env:*`（沙箱内仅 `$env:windir`/`$env:SystemRoot`）、`$PSScriptRoot`、`$ScriptRoot`、`$HOME`、`$PWD`、`$PSCommandPath`）和常见无害实例方法（如 `ToUpper`、`Trim`、`Split`、`ToString`）；其他内容将中止编译。单引号值保持完全字面。沙箱模式还会忽略 `#_pragma outputFile`、`Build.TempDir`、`Build.Minify`、`Signing.Certificate`，且只抓取解析到公网地址的 http(s) URL（重定向目标同样受此限制）。本地 `Resources.Icon` 仅放行 Windows 目录下的文件。

#### `#_DllExport`

<a id="preprocessing-dllexport"></a>

```powershell
#_DllExport int Add(int a, int b)
#_DllExport Add(int a, int b)
#_DllExport DoSomething(int value)

function Add($a, $b) { return $a + $b }
function DoSomething($value) { ... }
```

`#_DllExport` 会把脚本编译成原生 Win32 DLL 而非 exe，并把列出的函数导出，让 native 调用方可以直接用 `LoadLibrary`/`GetProcAddress`（或 `DllImport`）调用。每个导出函数转发到同名的 PowerShell 函数：参数以数组形式传入，函数输出作为返回值。返回类型与参数类型按 C# 语法书写；省略返回类型时默认为 `void`，参数不写类型时按 `string` 处理。

原生导出要求 .NET Framework 4.0 目标与 `x86`/`x64` 平台（`AnyCPU` 会自动按宿主位数选择），输出默认 `.dll`。访客/沙箱模式下不可用。导出调用会被串行化，首次调用会启动 PowerShell 运行空间。脚本出错时错误写到 stderr，调用返回所声明类型的默认值，而不是让异常穿过原生边界。

#### `#_balus`

<a id="preprocessing-balus"></a>

```powershell
#_balus <exitcode>
#_balus
```

当代码执行到此处时，以给定的退出码退出进程，并删除exe文件。

### 压缩（Minify）

由于ps12exe的"编译"会将脚本中的所有内容作为资源逐字嵌入到生成的可执行文件中，因此如果脚本中有大量无用字符串，生成的可执行文件就会很大。  
你可以使用 `-Build` 的 `Minify` 键指定一个脚本块，它将在编译前对脚本进行预处理，以获得更小的生成可执行文件。

如果不知道如何编写这样的脚本块，可以使用 [psminnifyer](https://github.com/steve02081504/psminnifyer)。

```powershell
& ./ps12exe.ps1 ./main.ps1 -App @{Windowed=$true} -Build @{Minify={ $_ | &./psminnifyer.ps1 }}
```

### 未实现的 cmdlet 列表

ps12exe 的基本输入/输出命令必须用 C# 重写。未实现的有控制台模式下的 _`Write-Progress`_（工作量太大）和 _`Start-Transcript`_/_`Stop-Transcript`_ （微软没有适当的参考实现）。

### GUI 模式输出格式

默认情况下，PowerShell 将 cmdlet 输出按行格式化为字符串数组。若某命令产生 10 行输出且走 GUI 输出，会弹出 10 个消息框。请通过管道传给 `Out-String`，合并为一段文本后只弹一个消息框（例如：`dir C:\ | Out-String`）。

### 配置文件

ps12exe 可以创建配置文件，文件名为`生成的可执行文件 + ".config"`。在大多数情况下，这些配置文件并不是必需的，它们只是一个清单，告诉你应该使用哪个 .Net Framework 版本。由于你通常会使用实际的 .Net Framework，请尝试在不使用配置文件的情况下运行你的可执行文件。

### 参数处理

编译后的脚本会像原始脚本一样处理参数。其中一个限制来自 Windows 环境：对于所有可执行文件，命令行参数最终都是字符串。

当脚本顶层有 `param()` 时，ps12exe 会把参数值按 PowerShell 数据（PSD）解析：哈希表 `@{}`、有序哈希表 `[ordered]@{}`、数组 `@()`，以及到安全类型的转换（如 `[int]'5'`、`[hashtable]@{}`），都会以对应的对象直接传给参数，无需在脚本里手动转换：

```powershell
# 脚本：param([hashtable]$Config)
app.exe -Config "@{name='Bob'; tags=@('a','b')}"
app.exe -Config "[ordered]@{first='1'; second='2'}"
```

值必须加引号：shell 会把未加引号的 `@{...}` 字符串化（实际只会收到 `System.Collections.Hashtable` 这段文本）。任何不是数据的值（表达式或命令）都按普通字符串传递、绝不会被求值，因此 `-Config "@{x=(Get-Date)}"` 不会执行代码，只是无法绑定。

通过管道传入的值仍然都是字符串。

### 密码安全

<a id="password-security-stuff"></a>
切勿在编译后的脚本中存储密码！  
整个脚本对任何 .net 反编译器来说轻松可见。  
![图片](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### 按脚本区分环境

你可以通过 `$Host.Name` 判断脚本是在编译后的 exe 中运行还是在脚本中运行。

```powershell
if ($Host.Name -eq "PSEXE") { Write-Output "ps12exe" } else { Write-Output "Some other host" }
```

### 脚本变量

由于ps12exe将脚本转换为可执行文件，变量`$MyInvocation`的值与脚本中的不同。

你仍然可以使用`$PSScriptRoot`来获取可执行文件所在的目录路径，并使用`$PSCommandPath`来获取可执行文件本身的路径。

### 在 `App.Windowed` 模式下的后台窗口

在使用`App.Windowed`模式的脚本中打开外部窗口时（如`Get-Credential`或需要`cmd.exe`的命令），一个窗口将在后台打开。

原因是关闭外部窗口时，Windows 会尝试激活父窗口。编译后的脚本没有窗口，因而会激活其父窗口，通常是文件资源管理器或 PowerShell 窗口。

为了解决这个问题，可以使用 `$Host.UI.RawUI.FlushInputBuffer()` 打开一个可以激活的隐形窗口。接下来调用 `$Host.UI.RawUI.FlushInputBuffer()`会关闭这个窗口（以此类推）。

下面的示例将不再在后台打开窗口，而不像只调用一次`ipconfig | Out-String`那样：

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

### 标准输入与 `$input`

编译后的 exe 只会在脚本**顶层**用到 `$input` 时，才把被重定向的标准输入逐行读入并作为管道输入传给脚本：

- 用到 `$input`：行为与 PS2EXE 一致，stdin 被当作管道输入消费完，原始 stdin（`[Console]::In` / `Console.OpenStandardInput()`）随之到达 EOF。
- 没用到 `$input`：完全不读 stdin，原始标准输入原样保留，启动时也不会等待 stdin（父进程即使一直不关闭管道也不会卡住），native 子进程仍能继承 stdin。

判断只看脚本顶层：函数、脚本块、类内部的 `$input` 是它们各自的管道输入，与宿主无关，不计入。

例如脚本里写 `[Console]::In.ReadToEnd()` 且没有用到 `$input`，编译后 `echo hi | .\tool.exe` 就能拿到 `hi`。

### 常量求值

对于只含常量、无副作用的脚本，ps12exe 会在编译期求值，并把结果直接编进极小的 exe（通常 1KB 上下）；超时（默认 7 秒）或结果过长时会退回普通编译。如果求值环境与运行期不一致，或你本来就想要完整的 PowerShell 宿主，可以在脚本里加下面任一 pragma 显式放弃该优化：

- `#_pragma Build.ConstEval.Enabled 0`：声明本脚本不是常量，跳过常量求值。
- `#_pragma Build.ConstEval.Timeout 1`：声明本次常量求值已超时，直接按超时回退。

两者在预处理阶段作为普通嵌套 pragma 解析，放在任意一行即可；退回普通宿主后这两行就是普通注释。

## 优势对比 🏆

### 快速比对 🏁

| 比对内容                             | ps12exe                                                         | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615) |
| ------------------------------------ | --------------------------------------------------------------- | ------------------------------------------------------------------------------ |
| 纯脚本仓库 📦                        | ✔️除图片和随附的辅助 DLL 外全是文本文件                         | ❌ 仓库中含附带开源许可的 `Win-PS2EXE.exe`                                     |
| 生成 hello world 所需要的命令 🌍     | 😎`'"Hello World!"' \| ps12exe`                                 | 🤔`echo "Hello World!" *> a.ps1; PS2EXE a.ps1; rm a.ps1`                       |
| 生成的常量 hello world 文件大小 💾   | 🥰1024 字节（编译期常量求值）                                   | ❌ 不支持；25088 字节                                                          |
| 生成的非常量 hello world 文件大小 💾 | 🥰14848 字节                                                    | 😨25088 字节                                                                   |
| 编译期常量求值 ⚡                    | ✔️                                                              | ❌                                                                             |
| PowerShell Core（7+）/ 跨平台目标 🧬 | ✔️ `Build.Target Core`（Windows / Linux / macOS）               | ❌ 仅支持 Windows PowerShell 5.1                                               |
| GUI 多语言支持 🌐                    | ✔️（7 种语言、深色模式）                                        | ❌                                                                             |
| 编译时的语法检查 ✔️                  | ✔️                                                              | ❌                                                                             |
| 预处理功能 🔄                        | ✔️                                                              | ❌                                                                             |
| `-extract` 等特殊参数解析 🧹         | 🗑️已删除（改用 `exe21sp` 工具）                                 | 🥲 需要修改源代码                                                              |
| PR 欢迎程度 🤝                       | 🥰欢迎！                                                        | 🤷14 个 PR，其中 13 个被关闭                                                   |
| 政治 / DEI / 立场偏见 🕊️             | ✔️ 无；欢迎任何有价值的 PR——无论来自人类、AI 还是敲打字机的猴子 | ❌ README 宣扬反 AI 立场（“人工智能正在扼杀创造力与我们的本性”）               |

ps12exe 的开发者不借本项目宣扬政治、DEI 或其他意识形态立场——我们欢迎任何有价值的 PR，无论它产出自人类、AI，还是敲打字机的猴子。

### 体积与速度基准 🔬

在 Windows 11 + PowerShell 7.6.6（.NET 10）+ Windows PowerShell 5.1 上测量，每项预热后运行 20 次。进程创建下限（`cmd /c exit`）约 15 ms。可用 `pwsh -File ../tools/Benchmark/Compare-Compilers.ps1 -IncludeCore` 复现（加 `-Compile` 可得到下方的编译速度表）。

| 构建                                     | 输出体积   | 预热启动 |
| ---------------------------------------- | ---------- | -------- |
| 直接用 Windows PowerShell 5.1 运行该脚本 | —          | ~406 ms  |
| ps12exe · 常量 · Framework4.0            | 1024 字节  | ~54 ms   |
| ps12exe · 非常量 · Framework4.0          | 14848 字节 | ~365 ms  |
| PS2EXE 1.0.18 · 非常量                   | 25088 字节 | ~398 ms  |
| ps12exe · 非常量 · 大脚本 · Framework4.0 | 30208 字节 | ~381 ms  |
| PS2EXE 1.0.18 · 非常量 · 大脚本          | ~496 KB    | ~402 ms  |
| ---------------------------------------- | ---------- | -------- |
| 直接以 pwsh 7 运行该脚本                 | —          | ~676 ms  |
| ps12exe · 常量 · Core                    | ~165 KB    | ~104 ms  |
| ps12exe · 非常量 · Core                  | ~181 KB    | ~621 ms  |
| ps12exe · 非常量 · 大脚本 · Core         | ~187 KB    | ~637 ms  |
| PS2EXE 1.0.18 · 非常量 · Core            | 不支持     | 不支持   |

常量脚本在编译期求值，得到的 exe 仅 1 KB 且完全不启动 PowerShell——相比 PS2EXE 的 hello world 约小 24 倍、启动快 6 倍。非常量 exe 比 PS2EXE 小约 40%；对于大量使用顶层变量的脚本，由于脚本运行在函数内（局部作用域）而非全局作用域，执行还更快。非常量 exe 始终压缩，且压缩率随负载增大而更明显：约 0.5 MB 的脚本，Framework 产物仍只有约 30 KB，约为 PS2EXE 产物（约 496 KB）的 1/16；PS2EXE 几乎不压缩负载，产物随脚本膨胀。Core 产物仅比小脚本多约 6 KB，大负载也不会膨胀。

### 编译速度 ⏱️

使用同一工具测量（`-Compile -IncludeCore`）。每个样本都运行在全新的宿主进程中（Framework/PS2EXE 用 Windows PowerShell 5.1，Core 用 pwsh 7）；“预热”为首次编译之后 5 次编译的中位数。PS2EXE 数据取自本地已安装的版本（本环境中为 1.0.18）。

| 构建                                     | 预热编译 |
| ---------------------------------------- | -------- |
| ps12exe · 常量 · Framework4.0            | ~2.3 s   |
| ps12exe · 非常量 · Framework4.0          | ~1.3 s   |
| PS2EXE · 非常量                          | ~0.9 s   |
| ps12exe · 非常量 · 大脚本 · Framework4.0 | ~1.5 s   |
| PS2EXE · 非常量 · 大脚本                 | ~0.7 s   |
| ---------------------------------------- | -------- |
| ps12exe · 常量 · Core                    | ~4.2 s   |
| ps12exe · 非常量 · Core                  | ~5.7 s   |
| ps12exe · 非常量 · 大脚本 · Core         | ~5.9 s   |
| PS2EXE · 非常量 · Core                   | 不支持   |

PS2EXE 编译 hello world 更快，因为它只是 Windows 内置 .NET Framework 编译器的一层薄封装：只做一次 CodeDom 编译，别无其他。ps12exe 还会额外执行语法检查、对脚本分类，并对常量脚本求值，再把程序帧作为负载打包进启动器，因此其非常量编译约为 PS2EXE 的 1.4 倍。代价体现在产物上：ps12exe 输出 1024 / 14848 字节，而 PS2EXE 输出 25088 字节，且常量程序启动约快 6 倍。Core 编译主要耗时于 `dotnet publish`；某个配置的首次编译还会还原 NuGet 包，之后 ps12exe 复用已生成的工程目录并运行 `dotnet publish --no-restore`。

编译器本身以 PowerShell 模块形式发布：

| 编译器包               | 解压后   | 压缩后  |
| ---------------------- | -------- | ------- |
| ps12exe（当前 master） | ~1.64 MB | ~629 KB |
| PS2EXE 1.0.18          | ~171 KB  | ~46 KB  |

ps12exe 的模块更大，因为它是无外部依赖的纯脚本编译器，随附精简过的 [AsmResolver](https://github.com/Washi1337/AsmResolver) 二进制、7 种本地化以及纯脚本 GUI；而 PS2EXE 几乎不带任何东西，直接复用 Windows 内置的 .NET Framework 编译器。

### 原生 DLL 导出 🧩

带有 `#_DllExport` 的脚本会被编译成可通过 `LoadLibrary`/`GetProcAddress` 调用的 Win32 DLL（仅 Framework4.0 + x86/x64；PS2EXE 无对应功能）。固定两导出脚本（`Add`、`Greet`）：

| 构建                              | 输出体积   | 预热编译 |
| --------------------------------- | ---------- | -------- |
| ps12exe · DLL 导出 · Framework4.0 | 28160 字节 | ~2.8 s   |
| PS2EXE 1.0.18 · DLL 导出          | 不支持     | 不支持   |

### 编译产物的运行期行为 🖥️

编译出的 EXE 启动的原生子进程能否看到真实控制台 TTY（[#59](https://github.com/steve02081504/ps12exe/issues/59)）、脚本能否读取原始 stdin（[#62](https://github.com/steve02081504/ps12exe/issues/62)），以及特殊路径变量能否解析——均在 Windows 11 的真实控制台窗口中验证：

| 能力                                      | ps12exe                       | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615) |
| ----------------------------------------- | ----------------------------- | ------------------------------------------------------------------------------ |
| 原生子进程能看到控制台 TTY（`isTTY`）     | ✔️                            | ❌                                                                             |
| 可读取原始 stdin（`[Console]::In`）       | ✔️（脚本未使用 `$input` 时）  | ❌                                                                             |
| `$PSCommandPath` / `$PSScriptRoot` 可解析 | ✔️（exe 路径 / exe 所在目录） | ❌                                                                             |
| 命令行参数按 PSD 数据解析（表/对象）      | ✔️（`-Config "@{...}"`）      | ❌（仅字符串）                                                                 |

PS2EXE 1.0.18 总是把脚本输出经 `Out-String` 收集，并在运行脚本前就把重定向的 stdin 全部读走，因此原生子进程失去控制台句柄、stdin 直接 EOF；ps12exe 通过宿主输出（`Out-Default`），且仅在脚本确实用到 `$input` 时才读取 stdin。此外 PS2EXE 在编译产物里让 `$PSCommandPath`/`$PSScriptRoot` 保持为空（另提供自定义的 `$ScriptRoot`），而 ps12exe 会把两者映射到生成的 exe。

### 详细比较 🔍

相较于[`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615)，本项目带来了以下改进：

| 改进内容                                               | 描述                                                              |
| ------------------------------------------------------ | ----------------------------------------------------------------- |
| ✔️ 编译时的语法检查                                    | 在编译时进行语法检查，提高代码质量                                |
| ⚡ 编译期常量求值                                      | 对无副作用脚本在构建期求值，生成约 1 KB 的 exe                    |
| 🧬 PowerShell Core / 跨平台目标                        | `Build.Target Core` 面向 Windows、Linux、macOS 上的 PowerShell 7+ |
| 🔄 强大的预处理功能                                    | 在编译前预处理脚本，无需再复制粘贴所有内容到脚本中                |
| 🛠️ `Build.Options` 参数                                | 新增参数，让你能进一步定制生成的可执行文件                        |
| 📦️ `Build.Minify` 参数                                 | 在编译前预处理脚本，生成更小的可执行文件                          |
| 🌐 支持从 URL 编译脚本和包含文件                       | 支持从 URL 下载图标                                               |
| 🖥️ `App.Windowed` 参数优化                             | 优化了选项处理和窗口标题显示，你现在可以设置自定义弹出窗口的标题  |
| ✍️ 代码签名与图标自动转换                              | 支持用 PFX 证书或证书存储指纹签名，并自动转换图标                 |
| 🧰 附加工具：`exe21sp`、Web 服务器、右键菜单、交互模式 | 反编译 exe、在线编译、右键编译等等                                |
| 🧹 移除了 exe 文件                                     | 从代码仓库中移除了 exe 文件                                       |
| 🌍 多语言支持、纯脚本 GUI                              | 更好的多语言支持、纯脚本 GUI，支持深色模式                        |
| 📖 将 cs 文件从 ps1 文件中分离                         | 更易于阅读和维护                                                  |
| 🚀 更多改进                                            | 还有更多...                                                       |

## 点星历史 ⭐

[![点星历史](https://starchart.cc/steve02081504/ps12exe.svg?variant=adaptive)](https://starchart.cc/steve02081504/ps12exe)
