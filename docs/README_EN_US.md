# ps12exe

> [!CAUTION]
> Don't store passwords in the source code, you hear?  
> See [this section](#password-security) for more details.  

## Introduction

ps12exe is a PowerShell module that lets you create an executable file from a .ps1 script.

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery download num](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![CodeFactor](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![repo img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

[![English (United Kingdom)](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/United-Kingdom.png)](./README_EN_UK.md)
[![中文](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/China.png)](./README_CN.md)
[![日本語](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Japan.png)](./README_JP.md)
[![Français](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/France.png)](./README_FR.md)
[![Español](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Spain.png)](./README_ES.md)
[![हिन्दी](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/India.png)](./README_HI.md)

## Installation

```powershell
Install-Module ps12exe # Install the ps12exe module
Set-ps12exeContextMenu # Set the right-click menu
```

(You can also clone this here repo and run `./ps12exe.ps1` directly.)

**Upgrading from PS2EXE to ps12exe? No problem!**  
PS2EXE2ps12exe can hook the PS2EXE calls into ps12exe. Just uninstall PS2EXE, install this, and keep using PS2EXE like normal.

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## Usage

### Right-Click Menu

Once you've run `Set-ps12exeContextMenu`, you can right-click any ps1 file to quickly compile it into an exe or open ps12exeGUI with that file.  
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

### Self-Hosted Web Server

```powershell
Start-ps12exeWebServer
```

Starts a web server that lets users compile PowerShell code online.

## Parameters

### GUI Parameters

```powershell
ps12exeGUI [[-ConfigFile] '<config file>'] [-PS1File '<PS1 file>'] [-Localize '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<PS1 file>'] [-Localize '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : The configuration file to load.
PS1File    : The script file to be compiled.
Localize   : The language code to use, ya know?
UIMode     : The UI mode to use, dark or light.
help       : Shows this here help message.
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
        [-SkipVersionCheck] [-GuestMode] [-PreprocessOnly] [-GolfMode] [-Localize '<language code>'] [-help]
```

```text
input            : String of the PowerShell script file's contents, same as -Content.
inputFile        : PowerShell script file path or URL you wanna convert to an executable (file must be UTF8 or UTF16 encoded).
Content          : PowerShell script content you wanna convert to an executable.
outputFile       : Destination executable file name or folder, defaults to inputFile with '.exe' added on.
CompilerOptions  : Extra compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx).
TempDir          : Directory for temp files (default is a randomly generated temp directory in %temp%).
minifyer         : Scriptblock to minify the script before compiling.
lcid             : Location ID for the compiled executable. Current user culture if nothin's specified.
prepareDebug     : Creates info to help with debugging.
architecture     : Compile for a specific runtime. Possible values are 'x64', 'x86', and 'anycpu'.
threadingModel   : 'Single Thread Apartment' or 'Multi Thread Apartment' mode.
noConsole        : The resulting executable will be a Windows Forms app without a console window.
UNICODEEncoding  : Encode output as UNICODE in console mode.
credentialGUI    : Use a GUI to prompt for credentials in console mode.
resourceParams   : A hashtable with resource parameters for the executable.
configFile       : Write a config file (<outputfile>.exe.config).
noOutput         : The resulting executable won't generate standard output (verbose and info included).
noError          : The resulting executable won't generate error output (warnings and debug included).
noVisualStyles   : Disable visual styles for a generated GUI app (only with -noConsole).
exitOnCancel     : Exits the program when Cancel or 'X' is selected in a Read-Host input box (only with -noConsole).
DPIAware         : If display scaling is on, GUI controls will be scaled if possible.
winFormsDPIAware : If display scaling is on, WinForms uses DPI scaling (requires Windows 10 and .NET 4.7 or up).
requireAdmin     : If UAC is enabled, the compiled executable runs only in an elevated context (UAC dialog appears).
supportOS        : Use functions of the newest Windows versions (run [Environment]::OSVersion to see the difference).
virtualize       : App virtualization is activated (forcing x86 runtime).
longPaths        : Enable long paths ( > 260 characters) if enabled on the OS (Windows 10 or up).
targetRuntime    : Target runtime version, 'Framework4.0' by default, 'Framework2.0' is supported.
SkipVersionCheck : Skip the check for new versions of ps12exe
GuestMode        : Compile scripts with extra protection, preventin' native files from being accessed.
PreprocessOnly   : Preprocess the input script and return it without compiling.
GolfMode         : Enable golf mode, adding abbreviations and common functions.
Localize         : Language code.
Help             : Show this here help message.
```

## Remarks

### Error Handlin

Unlike most PowerShell functions, ps12exe sets the `$LastExitCode` variable to show if somethin' went sideways, but it ain't guaranteein' no exceptions.  
You can have a butcher's at whether it's gone wrong like this, see:

```powershell
$LastExitCodeBackup = $LastExitCode
try {
	'"some code!"' | ps12exe
	if ($LastExitCode -ne 0) {
		throw "ps12exe crashed and burned with exit code $LastExitCode"
	}
}
finally {
	$LastExitCode = $LastExitCodeBackup
}
```

Different `$LastExitCode` values tell ya what kinda screw-up happened.

| Error Type | `$LastExitCode` Value |
|---------|------------------|
| 0 | All good, no problemo |
| 1 | Input code's a hot mess |
| 2 | Call's all jacked up |
| 3 | ps12exe had a total meltdown |

### Preprocessing

ps12exe pre-processes the script before compiling.

```powershell
# Read the program frame from the ps12exe.cs file
#_if PSEXE # This is the preprocessing code used when the script is compiled by ps12exe
	#_include_as_value programFrame "$PSScriptRoot/ps12exe.cs" # Inline the contents of ps12exe.cs into this script
#_else # Otherwise read the cs file normally
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

Right now, only these conditions are supported: `PSEXE` and `PSScript`.  
`PSEXE` is true; `PSScript` is false.  

#### `#_include <filename|url>`/`#_include_as_value <valuename> <file|url>`

```powershell
#_include <filename|url>
#_include_as_value <valuename> <file|url>
```

Includes the content of the file `<filename|url>` or `<file|url>` into the script. The file's content is inserted where the `#_include`/`#_include_as_value` command is.

Unlike the `#_if` statement, if you don't put quotes around the filename, the `#_include` commands treat trailing spaces and `#` as part of the filename as well.

```powershell
#_include $PSScriptRoot/super #weird filename.ps1
#_include "$PSScriptRoot/filename.ps1" #safe comment!
```

The file's content is preprocessed when `#_include` is used, letting you include files at multiple levels.

`#_include_as_value` inserts the file's content as a string value into the script. The file's content isn't preprocessed.

Most of the time, you don't need to use `#_if` and `#_include` to make scripts include sub-scripts correctly after converting to an exe. ps12exe automatically handles stuff like this and assumes the target script should be included:

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

Includes a file's content as a base64 string or byte array at preprocessing time. The file content itself isn't preprocessed.

Here's a simple packer example:

```powershell
#_include_as_bytes mydata $PSScriptRoot/data.bin
[System.IO.File]::WriteAllBytes("data.bin", $mydata)
```

When run, this EXE extracts the `data.bin` file that was embedded in the script during compilation.

#### `#_!!`

```powershell
$Script:eshDir =
#_if PSScript # It's not possible to have $EshellUI in PSEXE
if (Test-Path "$($EshellUI.Sources.Path)/path/esh") { $EshellUI.Sources.Path }
elseif (Test-Path $PSScriptRoot/../path/esh) { "$PSScriptRoot/.." }
elseif
#_else
	#_!!if
#_endif
(Test-Path $env:LOCALAPPDATA/esh) { "$env:LOCALAPPDATA/esh" }
```

Any line starting with `#_!!` gets removed.

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

`#_require` counts the modules needed in the whole script and adds a script equivalent to this before the first `#_require`:

```powershell
$modules | ForEach-Object{
	if(!(Get-Module $_ -ListAvailable -ea SilentlyContinue)) {
		Install-Module $_ -Scope CurrentUser -Force -ea Stop
	}
}
```

Note that the generated code only installs modules, it doesn't import them.
Use `Import-Module` as needed.

When you gotta require more than one module, you can use spaces, commas, or semicolons as separators instead of writing multiple `#_require` lines.

```powershell
#_require module1 module2;module3、module4,module5
```

#### `#_pragma`

The pragma preprocessor directive doesn't change the script's content, but it changes the parameters used for compilation.
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

As you can see, `#_pragma Console no` makes the generated exe file run in windowed mode, even if we didn't specify `-noConsole` during compilation.
The pragma command can set any compilation parameter:

```powershell
#_pragma noConsole # windowed
#_pragma Console # console
#_pragma Console no # windowed
#_pragma Console true # console
#_pragma icon $PSScriptRoot/icon.ico # set icon
#_pragma title "title" # set title
```

#### `#_balus`

```powershell
#_balus <exitcode>
#_balus
```

When the code gets here, the process exits with the given exit code and deletes the EXE.

### Minifyer

Since ps12exe's "compilation" embeds everything in the script as a resource in the resulting executable, the executable will be large if the script has a lot of useless strings.
You can use `-Minifyer` to specify a script block that processes the script after preprocessing but before compilation to get a smaller executable.

If you don't know how to write one of those script blocks, you can use [psminnifyer](https://github.com/steve02081504/psminnifyer).

```powershell
& ./ps12exe.ps1 ./main.ps1 -NoConsole -Minifyer { $_ | &./psminnifyer.ps1 }
```

### List of Cmdlets Not Implemented

The basic input/output commands had to be rewritten in C# for ps12exe. Not implemented are *`Write-Progress`* in console mode (too much work, man), and *`Start-Transcript`*/*`Stop-Transcript`* (no good reference implementation by Microsoft).

### GUI Mode Output Formatting

By default in PowerShell, commandlet outputs are formatted line by line (as an array of strings). When your command makes 10 lines of output and you use GUI output, 10 message boxes will show up, each waiting for an OK. To avoid this, pipe your command to `Out-String`. This turns the output into one string array with 10 lines, and all output shows in one message box (for example: `dir C:\ | Out-String`).

### Config Files

ps12exe can create config files named after the generated executable + ".config". Most of the time, these aren't needed; they just say which .Net Framework version to use. Since you'll usually use the current .Net Framework, try running your executable without the config file first.

### Parameter Processing

Compiled scripts handle parameters like the original script. One limit comes from Windows: for all executables, all parameters are type String. If there's no implicit conversion for your parameter type, you gotta convert it explicitly in your script. You can even pipe content to the executable, but all piped values are type String.

### Password Security

<a id="password-security-stuff"></a>
Never store passwords in your compiled script!
The whole script is easily visible to any .net decompiler, you see?

![image](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### Distinguish Environment by Script

You can tell if a script is running in a compiled exe or in a script by checking `$Host.Name`.

```powershell
if ($Host.Name -eq "PSEXE") { Write-Output "ps12exe" } else { Write-Output "Some other host" }
```

### Script Variables

Since ps12exe turns a script into an executable, the variable `$MyInvocation` is set to different values than in a script.

You can still use `$PSScriptRoot` to get the directory where the executable is, and the new `$PSEXEpath` to get the path of the executable itself.

### Window in Background in -noConsole Mode

When an external window is opened in a script with `-noConsole` mode (like for `Get-Credential` or a command that needs a `cmd.exe` shell), the next window opens in the background.

This happens because when the external window closes, Windows tries to activate the parent window. Since the compiled script has no window, the parent window of the compiled script gets activated instead, usually Explorer or PowerShell's window.

To fix this, `$Host.UI.RawUI.FlushInputBuffer()` opens an invisible window that can be activated. The following call of `$Host.UI.RawUI.FlushInputBuffer()` closes this window (and so on).

The following example will not open a window in the background anymore, as a single call of `ipconfig | Out-String` will do:

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

### Comparative Advantages

### Quick Comparison

| Comparison | ps12exe | [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5) |
| --- | --- | --- |
| Pure script repo 📦 | ✔️ All text files except images & dependencies | ❌ Contains exe files with an open source license |
| Command to generate hello world 🌍 | 😎`'"Hello World!"' \| ps12exe` | 🤔`echo "Hello World!" *> a.ps1; PS2EXE a.ps1; rm a.ps1` |
| Size of the generated hello world executable 💾 | 🥰1024 bytes | 😨25088 bytes |
| GUI multilingual support 🌐 | ✔️ | ❌ |
| Syntax check during compilation ✔️ | ✔️ | ❌ |
| Preprocessing 🔄 | ✔️ | ❌ |
| `-extract` and other special parameter parsing 🧹 | 🗑️ Removed | 🥲 Requires modifying the source code |
| PR welcome level 🤝 | 🥰 Welcome! | 🤷 14 PRs, 13 closed |

### Detailed Comparison

Compared to [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5), this project has these improvements:

| Improvement | Description |
| --- | --- |
| ✔️ Syntax check during compilation | Syntax check during compilation to improve code quality, you know? |
| 🔄 Powerful preprocessing | Preprocess the script before compilation, no need to copy and paste everything into the script |
| 🛠️ `-CompilerOptions` parameter | New parameter to let you further customize the generated executable |
| 📦️ `-Minifyer` parameter | Preprocess the script before compilation to generate a smaller executable |
| 🌐 Support for compiling scripts and included files from URLs | Support for downloading icons from URLs |
| 🖥️ Optimization of `-noConsole` parameter | Optimized option handling and window title display; you can now set the title of the custom pop-up |
| 🧹 Removed exe files | Removed exe files from the code repo |
| 🌍 Multilingual support, pure script GUI | Better multilingual support, pure script GUI, supports dark mode |
| 📖 Separated cs files from ps1 files | Easier to read and maintain, ya see? |
| 🚀 More improvements | And a whole bunch more... |
