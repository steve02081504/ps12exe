# ps12exe

> [!CAUTION]
> Do not store passwords in source code.  
> See [Password security](#password-security-stuff) for details.

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

(You can also clone this repository and run `./ps12exe.ps1` directly.)

**Upgrading from PS2EXE to ps12exe? No problem!**  
PS2EXE2ps12exe redirects PS2EXE calls to ps12exe. Uninstall PS2EXE, install this module, then use PS2EXE as usual.

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

### Recover ps1 from exe (exe21sp)

```powershell
exe21sp -inputFile .\target.exe -outputFile .\target.ps1
```

`exe21sp` extracts the PowerShell script embedded in a ps12exe-generated executable and saves it as a `.ps1` file or prints it to standard output. It uses the same `$LastExitCode` convention as ps12exe: 0 = success, 1 = input/parse error (e.g. not a ps12exe exe), 2 = invocation error (e.g. no input when redirected), 3 = resource/internal error (e.g. file not found).

### Pipeline and redirection

- **ps12exe**: When stdout (or stdin/stderr) is redirected, ps12exe writes only the path of the generated exe to stdout so you can capture it (e.g. `$exe = ps12exe .\a.ps1`).
- **exe21sp**: Accepts exe paths or URLs from pipeline input (e.g. `Get-ChildItem *.exe | exe21sp` or `".\app.exe" | exe21sp`).
- **exe21sp**: If `-outputFile` is not specified and stdout is **not** redirected, the decompiled script is saved to a `.ps1` file with the same base name as the exe in the same directory.
- **exe21sp**: If `-outputFile` is not specified and stdout **is** redirected, the decompiled script is written to stdout.

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
ConfigFile : Configuration file to load.
PS1File    : Script file to compile.
Localize   : Language code to use.
UIMode     : UI mode (Dark, Light, or Auto).
help       : Shows this help message.
```

### Console Parameters

```powershell
[input |] ps12exe [[-inputFile] '<filename|url>' | -Content '<script>'] [-outputFile '<filename>']
        [-CompilerOptions '<options>'] [-TempDir '<directory>'] [-minifyer '<scriptblock>'] [-noConsole]
        [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
        [-resourceParams @{iconFile='<filename|url>'; title='<title>'; description='<description>'; company='<company>';
        product='<product>'; copyright='<copyright>'; trademark='<trademark>'; version='<version>'}]
        [-CodeSigning @{Path='<PFX file path>'; Password='<PFX password>'; Thumbprint='<certificate thumbprint>'; TimestampServer='<timestamp server>'}]
        [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<Runtime>']
        [-SkipVersionCheck] [-GuestMode] [-PreprocessOnly] [-GolfMode] [-Localize '<language code>'] [-help]
```

```text
input            : String contents of the PowerShell script (same as -Content).
inputFile        : Path or URL of the PowerShell script to convert (file must be UTF-8 or UTF-16 encoded).
Content          : PowerShell script text to convert to an executable.
outputFile       : Output executable path or folder; defaults to the input file path with a `.exe` extension.
CompilerOptions  : Extra compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx).
TempDir          : Directory for temp files (default is a randomly generated temp directory in %temp%).
minifyer         : Scriptblock to minify the script before compiling.
lcid             : Locale ID for the compiled executable. Uses the current user culture if omitted.
prepareDebug     : Creates info to help with debugging.
architecture     : Compile for a specific runtime. Possible values are 'x64', 'x86', and 'anycpu'.
threadingModel   : 'Single Thread Apartment' or 'Multi Thread Apartment' mode.
noConsole        : The resulting executable will be a Windows Forms app without a console window.
UNICODEEncoding  : Encode output as UNICODE in console mode.
credentialGUI    : Use a GUI to prompt for credentials in console mode.
resourceParams   : A hashtable with resource parameters for the executable.
CodeSigning      : A hashtable containing code signing options for the compiled executable.
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
GuestMode        : Compile scripts with extra protection, preventing access to native files.
PreprocessOnly   : Preprocess the input script and return it without compiling.
GolfMode         : Enable golf mode, adding abbreviations and common functions.
Localize         : Language code.
Help             : Show this help message.
```

## Remarks

### Error Handling

Unlike many PowerShell functions, ps12exe sets `$LastExitCode` to report success or failure, but it may still throw exceptions.  
Check the exit code like this:

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

`$LastExitCode` meanings:

| Error type | `$LastExitCode`        |
| ---------- | ---------------------- |
| 0          | Success                |
| 1          | Input/code error       |
| 2          | Invocation error       |
| 3          | Internal ps12exe error |

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

The `#_!!` prefix is stripped from any line that starts with it.

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

When you need several modules, you can separate them with spaces, commas, or semicolons instead of multiple `#_require` lines.

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

The basic input/output commands had to be rewritten in C# for ps12exe. Not implemented: _`Write-Progress`_ in console mode (prohibitively much work), and _`Start-Transcript`_ / _`Stop-Transcript`_ (no suitable reference implementation from Microsoft).

### GUI Mode Output Formatting

By default, PowerShell formats cmdlet output line by line (as a string array). If a command produces 10 lines and you use GUI output, you get 10 message boxes. Pipe to `Out-String` to combine lines into one string so a single message box shows everything (e.g. `dir C:\ | Out-String`).

### Config Files

ps12exe can create config files named after the generated executable + ".config". Most of the time, these aren't needed; they just say which .Net Framework version to use. Since you'll usually use the current .Net Framework, try running your executable without the config file first.

### Parameter Processing

Compiled scripts handle parameters like the original script. One limitation is Windows itself: for any executable, arguments are strings. If your parameter needs another type, convert it explicitly. Piped input works the same way (values are strings).

### Password Security

<a id="password-security-stuff"></a>
Never store passwords in your compiled script!
The whole script is easy to read with any .NET decompiler.

![image](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### Distinguish Environment by Script

You can tell if a script is running in a compiled exe or in a script by checking `$Host.Name`.

```powershell
if ($Host.Name -eq "PSEXE") { Write-Output "ps12exe" } else { Write-Output "Some other host" }
```

### Script Variables

Since ps12exe turns a script into an executable, the variable `$MyInvocation` is set to different values than in a script.

You can still use `$PSScriptRoot` to get the directory where the executable is, and `$PSCommandPath` to get the path of the executable itself.

### Window in Background in -noConsole Mode

When an external window is opened in a script with `-noConsole` mode (like for `Get-Credential` or a command that needs a `cmd.exe` shell), the next window opens in the background.

This happens because when the external window closes, Windows tries to activate the parent window. Since the compiled script has no window, the parent window of the compiled script gets activated instead, usually Explorer or PowerShell's window.

To fix this, `$Host.UI.RawUI.FlushInputBuffer()` opens an invisible window that can be activated. The following call of `$Host.UI.RawUI.FlushInputBuffer()` closes this window (and so on).

The following avoids the background-window issue, unlike a single `ipconfig | Out-String` alone:

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

## Comparative Advantages 🏆

### Quick Comparison 🏁

| Comparison                                        | ps12exe                                        | [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5) |
| ------------------------------------------------- | ---------------------------------------------- | --------------------------------------------------------------------------------------------------------------- |
| Pure script repo 📦                               | ✔️ All text files except images & dependencies | ❌ Contains exe files with an open source license                                                               |
| Command to generate hello world 🌍                | 😎`'"Hello World!"' \| ps12exe`                | 🤔`echo "Hello World!" *> a.ps1; PS2EXE a.ps1; rm a.ps1`                                                        |
| Size of the generated hello world executable 💾   | 🥰1024 bytes                                   | 😨25088 bytes                                                                                                   |
| GUI multilingual support 🌐                       | ✔️                                             | ❌                                                                                                              |
| Syntax check during compilation ✔️                | ✔️                                             | ❌                                                                                                              |
| Preprocessing 🔄                                  | ✔️                                             | ❌                                                                                                              |
| `-extract` and other special parameter parsing 🧹 | 🗑️ Removed                                     | 🥲 Requires modifying the source code                                                                           |
| PR welcome level 🤝                               | 🥰 Welcome!                                    | 🤷 14 PRs, 13 closed                                                                                            |

### Detailed Comparison 🔍

Compared to [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5), this project offers the following improvements:

| Improvement                                                   | Description                                                                                        |
| ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| ✔️ Syntax check during compilation                            | Syntax checking at compile time for better code quality                                            |
| 🔄 Powerful preprocessing                                     | Preprocess the script before compilation, no need to copy and paste everything into the script     |
| 🛠️ `-CompilerOptions` parameter                               | New parameter to let you further customize the generated executable                                |
| 📦️ `-Minifyer` parameter                                     | Preprocess the script before compilation to generate a smaller executable                          |
| 🌐 Support for compiling scripts and included files from URLs | Support for downloading icons from URLs                                                            |
| 🖥️ Optimization of `-noConsole` parameter                     | Optimized option handling and window title display; you can now set the title of the custom pop-up |
| 🧹 Removed exe files                                          | Removed exe files from the code repo                                                               |
| 🌍 Multilingual support, pure script GUI                      | Better multilingual support, pure script GUI, supports dark mode                                   |
| 📖 Separated cs files from ps1 files                          | Easier to read and maintain                                                                        |
| 🚀 More improvements                                          | And more                                                                                           |

## Stargazers over time ⭐

[![Stargazers over time](https://starchart.cc/steve02081504/ps12exe.svg?variant=adaptive)](https://starchart.cc/steve02081504/ps12exe)
