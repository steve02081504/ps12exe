# ps12exe

> [!CAUTION]
> 不要在源代码中存储密码！  
> 参阅[这里](#密码安全)了解更多详情。  

## 简介

ps12exe是一个 PowerShell 模块，它允许你从 .ps1 脚本创建可执行文件。  

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

## 安装

```powershell
Install-Module ps12exe #安装ps12exe模块
Set-ps12exeContextMenu #设置右键菜单
```

（你也可以clone本仓库，然后直接运行`.\ps12exe.ps1`）

**升级从 PS2EXE 到 ps12exe 难吗？没问题！**  
PS2EXE2ps12exe 可以将 PS2EXE 的调用钩入到 ps12exe 中，你只需要卸载 PS2EXE 并安装这个，然后像正常使用 PS2EXE 一样即可。

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## 使用方法

### 右键菜单

一旦你设置了`Set-ps12exeContextMenu`，你可以通过右键任何ps1文件来快速将其编译为exe或者就此文件打开ps12exeGUI。  
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

### 自托管Web服务

```powershell
Start-ps12exeWebServer
```

启动一个允许用户在线编译powershell代码的Web服务。

## 参数

### GUI参数

```powershell
ps12exeGUI [[-ConfigFile] '<配置文件>'] [-PS1File '<脚本文件>'] [-Localize '<语言代码>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<脚本文件>'] [-Localize '<语言代码>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : 要加载的配置文件。
PS1File    : 要编译的脚本文件。
Localize   : 要使用的语言代码。
UIMode     : 要使用的用户界面模式。
help       : 显示此帮助信息。
```

### 控制台参数

```powershell
[input |] ps12exe [[-inputFile] '<文件名|url>' | -Content '<脚本>'] [-outputFile '<文件名>']
        [-CompilerOptions '<选项>'] [-TempDir '<文件夹>'] [-minifyer '<scriptblock>'] [-noConsole]
        [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
        [-resourceParams @{iconFile='<文件名|url>'; title='<标题>'; description='<简介>'; company='<公司>';
        product='<产品>'; copyright='<版权>'; trademark='<水印>'; version='<版本>'}]
        [-CodeSigning @{Path='<PFX文件路径>'; Password='<PFX密码>'; Thumbprint='<证书指纹>'; TimestampServer='<时间戳服务器>'}]
        [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<运行时版本>']
        [-SkipVersionCheck] [-GuestMode] [-PreprocessOnly] [-GolfMode] [-Localize '<语言代码>'] [-help]
```

```text
input            : PowerShell脚本文件内容的字符串，与-Content相同。
inputFile        : 您想要转换为可执行文件的PowerShell脚本文件路径或URL（文件必须是UTF8或UTF16编码）
Content          : 您想要转换为可执行文件的PowerShell脚本内容
outputFile       : 目标可执行文件名或文件夹，默认为带有'.exe'扩展名的inputFile
CompilerOptions  : 额外的编译器选项（参见 https://msdn.microsoft.com/en-us/library/78f4aasd.aspx）
TempDir          : 存储临时文件的目录（默认为%temp%中随机生成的临时目录）
minifyer         : 在编译之前缩小脚本的脚本块
lcid             : 编译的可执行文件的位置ID。如果未指定，则为当前用户文化
prepareDebug     : 创建有助于调试的信息
architecture     : 仅为特定运行时编译。可能的值为'x64'，'x86'和'anycpu'
threadingModel   : '单线程单元'或'多线程单元'模式
noConsole        : 生成的可执行文件将是一个没有控制台窗口的Windows Forms应用程序
UNICODEEncoding  : 在控制台模式下将输出编码为UNICODE
credentialGUI    : 在控制台模式下使用GUI提示凭据
resourceParams   : 包含编译的可执行文件的资源参数的哈希表
CodeSigning      : 包含代码签名参数的哈希表
configFile       : 写一个配置文件（<outputfile>.exe.config）
noOutput         : 生成的可执行文件将不生成标准输出（包括详细和信息通道）
noError          : 生成的可执行文件将不生成错误输出（包括警告和调试通道）
noVisualStyles   : 禁用生成的Windows GUI应用程序的视觉样式（仅与-noConsole一起使用）
exitOnCancel     : 当在Read-Host输入框中选择Cancel或'X'时退出程序（仅与-noConsole一起使用）
DPIAware         : 如果启用了显示缩放，GUI控件将尽可能进行缩放
winFormsDPIAware : 如果启用了显示缩放，WinForms将使用DPI缩放（需要Windows 10和.Net 4.7或更高版本）
requireAdmin     : 如果启用了UAC，编译的可执行文件只能在提升的上下文中运行（如果需要，会出现UAC对话框）
supportOS        : 使用最新Windows版本的功能（执行[Environment]::OSVersion以查看差异）
virtualize       : 已激活应用程序虚拟化（强制x86运行时）
longPaths        : 如果在OS上启用，启用长路径（> 260个字符）（仅适用于Windows 10或更高版本）
targetRuntime    : 目标运行时版本，默认为 'Framework4.0'，支持 'Framework2.0'
SkipVersionCheck : 跳过ps12exe的新版本检查
GuestMode        : 在额外的保护下编译脚本，避免本机文件被访问
PreprocessOnly   : 预处理输入脚本并在不编译的情况下返回它
GolfMode         : 启用golf模式，添加缩写和常用函数
Localize         : 指定本地化语言
Help             : 显示此帮助信息
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
|---------|------------------|
| 0 | 没有错误 |
| 1 | 输入代码错误 |
| 2 | 调用格式错误 |
| 3 | ps12exe内部错误 |

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

在大多数情况下你不需要使用 `#_if` 和 `#_include` 预处理命令来使得脚本在转换为exe后子脚本被正确包含，ps12exe会自动处理类似以下这些情况并认为目标脚本应当被包含处理：

```powershell
. $PSScriptRoot/another.ps1
& $PSScriptRoot/another.ps1
$result = & "$PSScriptRoot/another.ps1" -args
```

#### `#_include_as_(base64|bytes) <valuename> <file|url>`

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

```powershell
#_require ps12exe
#_pragma Console 0
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

pragma预处理指令对脚本内容没有任何影响，但会修改编译所使用的参数。  
以下是一个例子：

```powershell
PS C:\Users\steve02081504> '12' | ps12exe
Compiled file written -> 1024 bytes
PS C:\Users\steve02081504> ./a.exe
12
PS C:\Users\steve02081504> '#_pragma Console no
>> 12' | ps12exe
Preprocessed script -> 23 bytes
Compiled file written -> 2560 bytes
```

可以看到，`#_pragma Console no` 使得生成的exe文件以窗口模式运行，即使我们在编译时没有指定`-noConsole`。
pragma命令可以设置任何编译参数：

```powershell
#_pragma noConsole #窗口模式
#_pragma Console #控制台模式
#_pragma Console no #窗口模式
#_pragma Console true #控制台模式
#_pragma icon $PSScriptRoot/icon.ico #设置图标
#_pragma title "title" #设置exe标题
```

#### `#_balus`

```powershell
#_balus <exitcode>
#_balus
```

当代码执行到此处时，以给定的退出码退出进程，并删除exe文件。

### Minifyer

由于ps12exe的"编译"会将脚本中的所有内容作为资源逐字嵌入到生成的可执行文件中，因此如果脚本中有大量无用字符串，生成的可执行文件就会很大。  
你可以使用 `-Minifyer` 参数指定一个脚本块，它将在编译前对脚本进行预处理，以获得更小的生成可执行文件。  

如果不知道如何编写这样的脚本块，可以使用 [psminnifyer](https://github.com/steve02081504/psminnifyer)。

```powershell
& ./ps12exe.ps1 ./main.ps1 -NoConsole -Minifyer { $_ | &./psminnifyer.ps1 }
```

### 未实现的 cmdlet 列表

ps12exe 的基本输入/输出命令必须用 C# 重写。未实现的有控制台模式下的 *`Write-Progress`*（工作量太大）和 *`Start-Transcript`*/*`Stop-Transcript`* （微软没有适当的参考实现）。

### GUI 模式输出格式

默认情况下，powershell 中的小命令输出格式为每行一行（作为字符串数组）。当命令生成 10 行输出并使用 GUI 输出时，会出现 10 个消息框，每个消息框都在等待确定。为避免出现这种情况，请将`Out-String`命令导入命令行。这将把输出转换成一个有 10 行的字符串数组，所有输出都将显示在一个消息框中（例如：`dir C:\| Out-String`）。

### 配置文件

ps12exe 可以创建配置文件，文件名为`生成的可执行文件 + ".config"`。在大多数情况下，这些配置文件并不是必需的，它们只是一个清单，告诉你应该使用哪个 .Net Framework 版本。由于你通常会使用实际的 .Net Framework，请尝试在不使用配置文件的情况下运行你的可执行文件。

### 参数处理

编译后的脚本会像原始脚本一样处理参数。其中一个限制来自 Windows 环境：对于所有可执行文件，所有参数的类型都是 String，如果参数类型没有隐式转换，则必须在脚本中进行显式转换。你甚至可以通过管道将内容传送到可执行文件，但有同样的限制（所有管道传送的值都是 String 类型）。

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

你仍然可以使用`$PSScriptRoot`来获取可执行文件所在的目录路径，并使用新的`$PSEXEpath`来获取可执行文件本身的路径。

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

## 优势对比 🏆

### 快速比对 🏁

| 比对内容 | ps12exe | [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5) |
| --- | --- | --- |
| 纯脚本仓库 📦 | ✔️除了图片和依赖全是文本文件 | ❌含有有开源协议的exe文件 |
| 生成hello world所需要的命令 🌍 | 😎`'"Hello World!"' \| ps12exe` | 🤔`echo "Hello World!" *> a.ps1; PS2EXE a.ps1; rm a.ps1` |
| 生成的hello world可执行文件大小 💾 | 🥰1024 bytes | 😨25088 bytes |
| GUI多语言支持 🌐 | ✔️ | ❌ |
| 编译时的语法检查 ✔️ | ✔️ | ❌ |
| 预处理功能 🔄 | ✔️ | ❌ |
| `-extract`等特殊参数解析 🧹 | 🗑️已删除 | 🥲需要修改源代码 |
| PR欢迎程度 🤝 | 🥰欢迎！ | 🤷14个PR，其中13个被关闭 |

### 详细比较 🔍

相较于[`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5)，本项目带来了以下改进：

| 改进内容 | 描述 |
| --- | --- |
| ✔️ 编译时的语法检查 | 在编译时进行语法检查，提高代码质量 |
| 🔄 强大的预处理功能 | 在编译前预处理脚本，无需再复制粘贴所有内容到脚本中 |
| 🛠️ `-CompilerOptions`参数 | 新增参数，让你能进一步定制生成的可执行文件 |
| 📦️ `-Minifyer`参数 | 在编译前预处理脚本，生成更小的可执行文件 |
| 🌐 支持从URL编译脚本和包含文件 | 支持从URL下载图标 |
| 🖥️ `-noConsole`参数优化 | 优化了选项处理和窗口标题显示，你现在可以通过设置自定义弹出窗口的标题 |
| 🧹 移除了exe文件 | 从代码仓库中移除了exe文件 |
| 🌍 多语言支持、纯脚本GUI | 更好的多语言支持、纯脚本GUI，支持深色模式 |
| 📖 将cs文件从ps1文件中分离 | 更易于阅读和维护 |
| 🚀 更多改进 | 还有更多... |
