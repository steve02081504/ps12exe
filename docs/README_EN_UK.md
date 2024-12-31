# ps12exe

> [!CAUTION]
> Don't store passwords in the source code!  
> See [here](#password-security) for more details.  

## Introduction

ps12exe is a PowerShell module that allows you to create executable files from .ps1 scripts.

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery download num](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![CodeFactor](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![repo img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

[![English (United States)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-States.png)](./README_EN_US.md)
[![中文](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/China.png)](./README_CN.md)
[![日本語](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Japan.png)](./README_JP.md)
[![Français](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/France.png)](./README_FR.md)
[![Español](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Spain.png)](./README_ES.md)
[![हिन्दी](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/India.png)](./README_HI.md)

## Installation

```powershell
Install-Module ps12exe #Install the ps12exe module
Set-ps12exeContextMenu #Set the right-click menu
```

(You can also clone the repository and run `./ps12exe.ps1` directly.)

**Upgrading from PS2EXE to ps12exe? No problem!**  
PS2EXE2ps12exe can hook the PS2EXE calls into ps12exe. Just uninstall PS2EXE and install this, then use PS2EXE as usual.

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## Usage

### Right-Click Menu

Once you've run `Set-ps12exeContextMenu`, you can quickly compile any ps1 file into an exe, or open ps12exeGUI on the file, by right-clicking on it.  
![image](https://github.com/steve02081504/ps12exe/assets/31927825/24e7caf7-2bd8-46aa-8e1d-ee6da44c2dcc)

### GUI Mode

```powershell
ps12exeGUI
```

### Console Mode

```powershell
ps12exe .\source.ps1 .\target.exe
```

Compiles `source.ps1` into the executable `target.exe` (if `.\target.exe` is omitted, output goes to `.\source.exe`).

```powershell
'"Hello World!"' | ps12exe
```

Compiles `"Hello World!"` into the executable `.\a.exe`.

```powershell
ps12exe https://raw.githubusercontent.com/steve02081504/ps12exe/master/src/GUI/Main.ps1
```

Compiles `Main.ps1` from the internet into the executable `.\Main.exe`.

### Self-Host Web Server

```powershell
Start-ps12exeWebServer
```

Starts a web server for compiling PowerShell scripts online.

## Parameters

### Error Handling

Unlike most proper PowerShell functions, ps12exe sets the `$LastExitCode` variable to show if it’s cocked up, but it doesn’t promise you won’t get a right old exception, yeah?  
You can have a butcher's at whether it's gone wrong like this, see:

```powershell
$LastExitCodeBackup = $LastExitCode
try {
	'"some code!"' | ps12exe
	if ($LastExitCode -ne 0) {
		throw "ps12exe buggered up with exit code $LastExitCode"
	}
}
finally {
	$LastExitCode = $LastExitCodeBackup
}
```

Different `$LastExitCode` values show you what kinda balls-up it’s made:

| Error Type | `$LastExitCode` Value |
|---------|------------------|
| 0 | All Tickety-boo |
| 1 | Input code is a load of old rubbish |
| 2 | The call's all gone pear-shaped |
| 3 | ps12exe’s had a proper mare |

### GUI Parameters

```powershell
ps12exeGUI [[-ConfigFile] '<config file>'] [-PS1File '<PS1 file>'] [-Localize '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<PS1 file>'] [-Localize '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : The configuration file to load.
PS1File    : The script file to be compiled.
Localize   : The language code to use.
UIMode     : The UI mode to use (Dark, Light, or Auto).
help       : Show this help message.
```

### Console Parameters

```powershell
[input |] ps12exe [[-inputFile] '<filename|url>' | -Content '<script>'] [-outputFile '<filename>']
        [-CompilerOptions '<options>'] [-TempDir '<directory>'] [-minifyer '<scriptblock>'] [-noConsole]
        [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
        [-resourceParams @{iconFile='<filename|url>'; title='<title>'; description='<description>'; company='<company>';
        product='<product>'; copyright='<copyright>'; trademark='<trademark>'; version='<version>'}]
        [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<Runtime>']
        [-SkipVersionCheck] [-GuestMode] [-Localize '<language code>'] [-help]
```

```text
input            : String of the contents of the PowerShell script file (same as -Content).
inputFile        : PowerShell script file path or URL that you want to convert to executable (file has to be UTF8 or UTF16 encoded).
Content          : PowerShell script content that you want to convert to executable.
outputFile       : Destination executable file name or folder (defaults to inputFile with the extension '.exe').
CompilerOptions  : Additional compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx).
TempDir          : Directory for storing temporary files (default is a randomly generated temp directory in %temp%).
minifyer         : Scriptblock to minify the script before compiling.
lcid             : Location ID for the compiled executable (Current user culture if not specified).
prepareDebug     : Create helpful information for debugging.
architecture     : Compile for specific runtime only (possible values are 'x64', 'x86', and 'anycpu').
threadingModel   : 'Single Thread Apartment' or 'Multi Thread Apartment' mode.
noConsole        : The resulting executable will be a Windows Forms app without a console window.
UNICODEEncoding  : Encode output as UNICODE in console mode.
credentialGUI    : Use a GUI for prompting credentials in console mode.
resourceParams   : A hashtable that contains resource parameters for the compiled executable.
configFile       : Write a config file (<outputfile>.exe.config).
noOutput         : The resulting executable will generate no standard output (including verbose and information channels).
noError          : The resulting executable will generate no error output (including warning and debug channels).
noVisualStyles   : Disable visual styles for a generated windows GUI application (only with -noConsole).
exitOnCancel     : Exits the program when Cancel or 'X' is selected in a Read-Host input box (only with -noConsole).
DPIAware         : If display scaling is activated, GUI controls will be scaled if possible.
winFormsDPIAware : If display scaling is activated, WinForms uses DPI scaling (requires Windows 10 and .NET 4.7 or up).
requireAdmin     : If UAC is enabled, the compiled executable will run only in an elevated context (UAC dialog appears if required).
supportOS        : Use functions of the newest Windows versions (execute [Environment]::OSVersion to see the difference).
virtualize       : Application virtualization is activated (forcing x86 runtime).
longPaths        : Enable long paths ( > 260 characters) if enabled on the OS (works only with Windows 10 or up).
targetRuntime    : Target runtime version ('Framework4.0' by default, 'Framework2.0' is supported).
SkipVersionCheck : Skip the check for new versions of ps12exe
GuestMode        : Compile scripts with additional protection, preventing native files from being accessed.
Localize         : The language code to use.
Help             : Show this help message.
```

## Remarks

### Preprocessing

ps12exe pre-processes the script before compiling.

```powershell
# Read the program frame from the ps12exe.cs file
#_if PSEXE #This is the preprocessing code used when the script is compiled by ps12exe
	#_include_as_value programFrame "$PSScriptRoot/ps12exe.cs" #Inline the contents of ps12exe.cs into this script
#_else #Otherwise read the cs file normally
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

Only the following conditions are supported: `PSEXE` and `PSScript`.  
`PSEXE` is true, `PSScript` is false.  

#### `#_include <filename|url>`/`#_include_as_value <valuename> <file|url>`

```powershell
#_include <filename|url>
#_include_as_value <valuename> <file|url>
```

Includes the content of the file `<filename|url>` or `<file|url>` into the script. The content of the file is inserted at the position of the `#_include`/`#_include_as_value` command.

Unlike the `#_if` statement, if you don't enclose the filename in quotes, the `#_include` family treats the trailing space and `#` as part of the filename as well.

```powershell
#_include $PSScriptRoot/super #weird filename.ps1
#_include "$PSScriptRoot/filename.ps1" #safe comment!
```

The content of the file is preprocessed when `#_include` is used, which allows you to include files at multiple levels.

`#_include_as_value` inserts the content of the file as a string value into the script. The content of the file is not preprocessed.

In most cases, you don't need to use the `#_if` and `#_include` pre-processing commands to make the scripts include sub-scripts correctly after conversion to exe. ps12exe automatically handles cases like the following and assumes that the target script should be included:

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

Includes the content of a file as a base64 string or byte array at preprocessing time. The file content itself isn't preprocessed.

Here's a simple packer example:

```powershell
#_include_as_bytes mydata $PSScriptRoot/data.bin
[System.IO.File]::WriteAllBytes("data.bin", $mydata)
```

This EXE will, upon execution, extract the `data.bin` file embedded in the script during compilation.

#### `#_!!`

```powershell
$Script:eshDir =
#_if PSScript #It is not possible to have $EshellUI in PSEXE
if (Test-Path "$($EshellUI.Sources.Path)/path/esh") { $EshellUI.Sources.Path }
elseif (Test-Path $PSScriptRoot/../path/esh) { "$PSScriptRoot/.." }
elseif
#_else
	#_!!if
#_endif
(Test-Path $env:LOCALAPPDATA/esh) { "$env:LOCALAPPDATA/esh" }
```

Any line beginning with `#_!!` will be removed.

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

`#_require` counts the modules needed in the entire script and adds the script equivalent of the following code before the first `#_require`:

```powershell
$modules | ForEach-Object{
	if(!(Get-Module $_ -ListAvailable -ea SilentlyContinue)) {
		Install-Module $_ -Scope CurrentUser -Force -ea Stop
	}
}
```

Note that the code it generates will only install modules, not import them.
Please use `Import-Module` as needed.

When you need to require more than one module, you can use spaces, commas, or semicolons and full stops as separators instead of writing multi-line require statements.

```powershell
#_require module1 module2;module3、module4,module5
```

#### `#_pragma`

The pragma preprocessor directive has no effect on the content of the script, but it modifies the parameters used for compilation.  
Here's an example:

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

As you can see, `#_pragma Console no` makes the generated exe file run in windowed mode, even if we didn't specify `-noConsole` at compile time.
The pragma command can set any compilation parameter:

```powershell
#_pragma noConsole #windowed
#_pragma Console #console
#_pragma Console no #windowed
#_pragma Console true #console
#_pragma icon $PSScriptRoot/icon.ico #set icon
#_pragma title "title" #set title
```

#### `#_balus`

```powershell
#_balus <exitcode>
#_balus
```

When the code reaches this point, the process exits with the given exit code and deletes the EXE file.

### Minifyer

Since ps12exe's "compilation" embeds everything in the script verbatim as a resource in the resulting executable, the resulting executable will be large if the script has a lot of unnecessary strings.  
You can specify a script block with the `-Minifyer` parameter that will process the script after preprocessing, before compilation, to achieve a smaller generated executable.  

If you don't know how to write such a script block, you can use [psminnifyer](https://github.com/steve02081504/psminnifyer).

```powershell
& ./ps12exe.ps1 ./main.ps1 -NoConsole -Minifyer { $_ | &./psminnifyer.ps1 }
```

### List of Cmdlets Not Implemented

The basic input/output commands had to be rewritten in C# for ps12exe. Not implemented are *`Write-Progress`* in console mode, and *`Start-Transcript`*/*`Stop-Transcript`* (no proper reference implementation by Microsoft).

### GUI Mode Output Formatting

By default, in PowerShell, outputs of commandlets are formatted line by line (as an array of strings). When your command generates 10 lines of output and you use GUI output, 10 message boxes will appear, each awaiting an OK. To prevent this, pipe your command to the commandlet `Out-String`. This will convert the output to one string array with 10 lines, and all output will be shown in one message box (e.g., `dir C:\ | Out-String`).

### Config Files

ps12exe can create config files with the name of the generated executable + ".config". In most cases, those config files are not necessary; they are a manifest that tells which .Net Framework version should be used. As you will usually use the actual .Net Framework, try running your executable without the config file.

### Parameter Processing

Compiled scripts process parameters like the original script does. One restriction comes from the Windows environment: for all executables, all parameters have the type String; if there is no implicit conversion for your parameter type, you have to convert explicitly in your script. You can even pipe content to the executable with the same restriction (all piped values have the type String).

### Password Security

<a id="password-security-stuff"></a>
Never store passwords in your compiled script!  
The entire script is easily visible to any .net decompiler.

![image](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### Distinguish Environment by Script

You can tell whether a script is running in a compiled exe or in a script by `$Host.Name`.

```powershell
if ($Host.Name -eq "PSEXE") { Write-Output "ps12exe" } else { Write-Output "Some other host" }
```

### Script Variables

Since ps12exe converts a script to an executable, the variable `$MyInvocation` is set to different values than in a script.

You can still use `$PSScriptRoot` to retrieve the directory path where the executable is located, and a new `$PSEXEpath` to obtain the path of the executable itself.

### Window in Background in -noConsole Mode

When an external window is opened in a script with `-noConsole` mode (i.e., for `Get-Credential` or for a command that needs a `cmd.exe` shell), the next window is opened in the background.

The reason for this is that on closing the external window, Windows tries to activate the parent window. Since the compiled script has no window, the parent window of the compiled script is activated instead, normally the window of Explorer or PowerShell.

To work around this, `$Host.UI.RawUI.FlushInputBuffer()` opens an invisible window that can be activated. The following call of `$Host.UI.RawUI.FlushInputBuffer()` closes this window (and so on).

The following example will not open a window in the background anymore, as a single call of `ipconfig | Out-String` will do:

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

## Comparative Advantages

### Quick Comparison

| Comparison Content | ps12exe | [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5) |
| --- | --- | --- |
| Pure script repository 📦 | ✔️ All text files except images & dependencies | ❌ Contains exe files with open source license |
| Command to generate hello world 🌍 | 😎`'"Hello World!"' \| ps12exe` | 🤔`echo "Hello World!" *> a.ps1; PS2EXE a.ps1; rm a.ps1` |
| Size of the generated hello world executable file 💾 | 🥰1024 bytes | 😨25088 bytes |
| GUI multilingual support 🌐 | ✔️ | ❌ |
| Syntax check during compilation ✔️ | ✔️ | ❌ |
| Preprocessing feature 🔄 | ✔️ | ❌ |
| `-extract` and other special parameter parsing 🧹 | 🗑️ Removed | 🥲 Requires source code modification |
| PR welcome level 🤝 | 🥰 Welcome! | 🤷 14 PRs, 13 of which were closed |

### Detailed Comparison

Compared to [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5), this project brings the following improvements:

| Improvement Content | Description |
| --- | --- |
| ✔️ Syntax check during compilation | Syntax check during compilation to improve code quality |
| 🔄 Powerful preprocessing feature | Preprocess the script before compilation, no need to copy and paste all content into the script |
| 🛠️ `-CompilerOptions` parameter | New parameter, letting you further customize the generated executable file |
| 📦️ `-Minifyer` parameter | Preprocess the script before compilation to generate a smaller executable file |
| 🌐 Support for compiling scripts and included files from URL | Support for downloading icons from URL |
| 🖥️ Optimization of `-noConsole` parameter | Optimized option handling and window title display; you can now set the title of the custom pop-up window |
| 🧹 Removed exe files | Removed exe files from the code repository |
| 🌍 Multilingual support, pure script GUI | Better multilingual support, pure script GUI, support for dark mode |
| 📖 Separated cs files from ps1 files | Easier to read and maintain |
| 🚀 More improvements | And more... |
