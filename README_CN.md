# ps12exe

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery download num](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![CodeFactor](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![repo img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

## 安装

```powershell
Install-Module ps12exe
```

（你也可以clone本仓库，然后直接运行`.\ps12exe.ps1`）

## 使用方法

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

## 优势对比

相较于[`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5)，本项目带来了以下改进：

- 引入了[强大的预处理功能](#预处理)，让你在编译前就能预处理脚本，无需再复制粘贴所有内容到脚本中。
- 生成的文件中不再默认启用特殊参数，但如果需要，可以通过新的`-SepcArgsHandling`参数启用。
- 新增`-CompilerOptions`参数，让你能进一步定制生成的可执行文件。
- 新增[`-Minifyer`参数](#minifyer)，让你在编译前预处理脚本，生成更小的可执行文件。
- 支持从URL编译脚本和包含文件，支持从URL下载图标。
- 在`-noConsole`参数下，优化了选项处理和窗口标题显示，你现在可以通过设置`$Host.UI.RawUI.WindowTitle`自定义弹出窗口的标题。
- 从代码仓库中移除了exe文件。
- 更好的多语言支持、纯脚本GUI，支持深色模式。
- 将cs文件从ps1文件中分离，更易于阅读和维护。
- 还有更多...

## 参数

### GUI参数

```powershell
ps12exeGUI [[-ConfingFile] '<filename>'] [-Localize '<languagecode>'] [-UIMode 'Dark'|'Light'|'Auto']
```

```text
ConfingFile = 配置文件的路径（默认为 无）
   Localize = 语言代码（默认为当前系统语言，没有对应的语言文件时尝试加载'en-UK'，如果仍然没有则遍历所有语言文件直到可用）
     UIMode = 界面模式（默认为 Auto）
```

### 控制台参数

```powershell
[input |] ps12exe [[-inputFile] '<filename|url>' | -Content '<script>'] [-outputFile '<filename>']
        [-CompilerOptions '<options>'] [-TempDir '<directory>'] [-minifyer '<scriptblock>'] [-noConsole]
        [-SepcArgsHandling] [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug]
        [-resourceParams @{iconFile='<filename|url>'; title='<title>'; description='<description>'; company='<company>';
        product='<product>'; copyright='<copyright>'; trademark='<trademark>'; version='<version>'}]
        [-lcid <lcid>] [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths]
```

```text
           input = Powershell 脚本文件的内容，与 -Content 参数相同。
       inputFile = 要转换为可执行文件的 Powershell 脚本文件的路径或网址（文件必须是 UTF8 或 UTF16 编码）
         Content = 要转换为可执行文件的 Powershell 脚本的内容
      outputFile = 目标可执行文件的名称或所在的文件夹，默认为 inputFile 加上 ".exe" 扩展名
 CompilerOptions = 附加的编译器选项（请参阅 https://msdn.microsoft.com/en-us/library/78f4aasd.aspx）
         TempDir = 用于存放临时文件的目录（默认为位于 %temp% 中的随机生成的临时目录）
        minifyer = 用于在编译前缩小脚本的脚本块
SepcArgsHandling = 生成的可执行文件将处理以下特殊参数：-debug、-extract、-wait 和 -end
    prepareDebug = 为调试生成有用的信息
    architecture = 仅针对特定的运行时编译。可选的值有 "x64"、"x86" 和 "anycpu"
            lcid = 编译后可执行文件的区域设置 ID。如果未指定，则为当前用户的区域设置
  threadingModel = "单线程公寓"或 "多线程公寓"模式
       noConsole = 生成的可执行文件将是没有控制台窗口的 Windows 窗体应用程序
 UNICODEEncoding = 在控制台模式下将输出以 UNICODE 编码
   credentialGUI = 在控制台模式下使用图形用户界面来提示凭据
  resourceParams = 包含编译后可执行文件的资源参数的哈希表
      configFile = 生成配置文件（<outputfile>.exe.config）
        noOutput = 生成的可执行文件将不输出任何标准输出（包括详细和信息通道）
         noError = 生成的可执行文件将不输出任何错误输出（包括警告和调试通道）
  noVisualStyles = 禁用生成的 Windows GUI 应用程序的视觉样式（仅与 -noConsole 一起使用）
    exitOnCancel = 在 "读取主机"输入框中选择 "取消"或 "X"时退出程序（仅适用于 -noConsole）
        DPIAware = 如果启用了显示缩放功能，将尽可能地缩放图形用户界面的控件
winFormsDPIAware = 如果启用了显示缩放，WinForms 将使用 DPI 缩放（需要 Windows 10 和 .Net 4.7 或更高版本）
    requireAdmin = 如果启用了 UAC，编译后的可执行文件只能在提升的权限下运行（如果需要，会弹出 UAC 对话框）
       supportOS = 使用最新 Windows 版本的特性（执行 [Environment]::OSVersion 查看区别）
      virtualize = 启用应用程序虚拟化（强制使用 x86 运行时）
       longPaths = 启用长路径（超过 260 个字符）如果操作系统支持（仅适用于 Windows 10 或更高版本）
```

使用 `SepcArgsHandling` 参数，生成的可执行文件具有以下保留参数：

```text
-debug              强制调试可执行文件。它会调用 "System.Diagnostics.Debugger.Launch()"。
-extract:<FILENAME> 提取可执行文件中的 powerShell 脚本并将其保存为 FILENAME。
                    脚本不会被执行。
-wait               在脚本执行结束时，它会写入 "按任意键退出... "并等待按键。
-end                以下所有选项都将传递给可执行文件中的脚本。
                    前面的所有选项都由可执行文件本身使用，不会传递给脚本。
```

### 备注

### 预处理

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

```powershell
#_if <condition>
	<code>
#_else
	<code>
#_endif
```

现在只支持以下条件： `PSEXE` 和 `PSScript`。  
`PSEXE` 为 true；`PSScript` 为 false。  

#### `#_include <filename|url>`/`#_include_as_value <valuename> <file|url>`

```powershell
#_include <filename|url>
#_include_as_value <valuename> <file|url>
```

将文件 `<filename|url>` 或 `<file|url>` 的内容包含到脚本中。文件内容会插入到 `#_include`/`#_include_as_value` 命令的位置。  

与`#_if`语句不同 如果你不使用引号将文件名括起来，`#_include`系列预处理命令会将末尾的空格、`#`也视为文件名的一部分  

```powershell
#_include $PSScriptRoot/super #weird filename.ps1
#_include "$PSScriptRoot/filename.ps1" #safe comment!
```

使用 `#_include` 时，文件内容会经过预处理，这允许你多级包含文件。

`#_include_as_value` 会将文件内容作为字符串值插入脚本。文件内容不会被预处理。  

#### `#_!!`

```powershell
$Script:eshDir =
#_if PSScript #在PSEXE中不可能有$EshellUI，而$PSScriptRoot无效
if (Test-Path "$($EshellUI.Sources.Path)/path/esh") { $EshellUI.Sources.Path }
elseif (Test-Path $PSScriptRoot/../path/esh) { "$PSScriptRoot/.." }
elseif
#_else
	#_!!if
#_endif
(Test-Path $env:LOCALAPPDATA/esh) { "$env:LOCALAPPDATA/esh" }
```

任何以`#_!!`开头的行，其开头的`#_!!`会被去除。

### Minifyer

由于ps12exe的"编译"会将脚本中的所有内容作为资源逐字嵌入到生成的可执行文件中，因此如果脚本中有大量无用字符串，生成的可执行文件就会很大。  
你可以使用 `-Minifyer` 参数指定一个脚本块，它将在编译前对脚本进行预处理，以获得更小的生成可执行文件。  

如果不知道如何编写这样的脚本块，可以使用 [psminnifyer](https://github.com/steve02081504/psminnifyer)。

```powershell
& ./ps12exe.ps1 ./main.ps1 -NoConsole -Minifyer { $_ | &./psminnifyer.ps1 }
```

### 未实现的 cmdlet 列表

ps12exe 的基本输入/输出命令必须用 C# 重写。未实现的有控制台模式下的 *`Write-Progress`*（工作量太大）和*`Start-Transcript`*/*`Stop-Transcript`*（微软没有适当的参考实现）。

### GUI 模式输出格式

默认情况下，powershell 中的小命令输出格式为每行一行（作为字符串数组）。当命令生成 10 行输出并使用 GUI 输出时，会出现 10 个消息框，每个消息框都在等待确定。为避免出现这种情况，请将`Out-String`命令导入命令行。这将把输出转换成一个有 10 行的字符串数组，所有输出都将显示在一个消息框中（例如：`dir C:\| Out-String`）。

### 配置文件

ps12exe 可以创建配置文件，文件名为`生成的可执行文件 + ".config"`。在大多数情况下，这些配置文件并不是必需的，它们只是一个清单，告诉你应该使用哪个 .Net Framework 版本。由于你通常会使用实际的 .Net Framework，请尝试在不使用配置文件的情况下运行你的可执行文件。

### 参数处理

编译后的脚本会像原始脚本一样处理参数。其中一个限制来自 Windows 环境：对于所有可执行文件，所有参数的类型都是 String，如果参数类型没有隐式转换，则必须在脚本中进行显式转换。你甚至可以通过管道将内容传送到可执行文件，但有同样的限制（所有管道传送的值都是 String 类型）。

### 密码安全

切勿在编译后的脚本中存储密码！  
如果使用了 `SepcArgsHandling` 参数，所有人都可以使用 `-extract` 参数简单地反编译脚本。  
例如  

```powershell
Output.exe -extract:.\Output.ps1
```

将反编译存储在 Output.exe 中的脚本。
即使你不使用它，整个脚本对任何 .net 反编译器来说仍然是轻松可见的。
![图片](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### 按脚本区分环境  

你可以通过 `$Host.Name` 判断脚本是在编译后的 exe 中运行还是在脚本中运行。 

```powershell
if ($Host.Name -eq "PSEXE") { Write-Output "ps12exe" } else { Write-Output "Some other host" }
```

### 脚本变量

由于 ps12exe 会将脚本转换为可执行文件，因此与脚本相关的变量将不再可用。特别是变量`$PSScriptRoot`是空的。

变量`$MyInvocation`被设置为脚本以外的值。

你可以使用下面的代码（感谢 JacquesFS）获取脚本/可执行文件的路径，而与编译/未编译无关：

```powershell
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript"){
	$ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}
else{
	$ScriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0]) 
	if(!$ScriptPath){ $ScriptPath = "." }
}
```

### 在 -noConsole 模式下的后台窗口

在使用`-noConsole`模式的脚本中打开外部窗口时（如`Get-Credential`或需要`cmd.exe`的命令），一个窗口将在后台打开。

原因是关闭外部窗口时，windows 会尝试激活父窗口。由于编译后的脚本没有窗口，因此会激活编译后脚本的父窗口，通常是资源管理器或 Powershell 的窗口。

为了解决这个问题，可以使用 `$Host.UI.RawUI.FlushInputBuffer()` 打开一个可以激活的隐形窗口。接下来调用 `$Host.UI.RawUI.FlushInputBuffer()`会关闭这个窗口（以此类推）。

下面的示例将不再在后台打开窗口，而不像只调用一次`ipconfig | Out-String`那样：

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```
