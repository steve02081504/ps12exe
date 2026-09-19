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

## Used by

- [fount](https://github.com/steve02081504/fount)
- [SessionTracker](https://github.com/quinncthirtyone/SessionTracker)
- [GStreamer-Glass](https://github.com/Geofferey/GStreamer-Glass)
- [MailboxManager](https://github.com/TestGroundControl/MailboxManager)
- [always-accompany](https://github.com/beilusaiying/always-accompany)

## Installation

```powershell
Install-Module ps12exe #Install the ps12exe module
Set-ps12exeContextMenu #Set the right-click menu
```

(You can also clone the repository and run `./ps12exe.ps1` directly.)

**Upgrading from PS2EXE to ps12exe? No problem!**  
PS2EXE2ps12exe can hook the PS2EXE calls into ps12exe. Just uninstall PS2EXE and install this, then use PS2EXE as usual.  
It aims for maximum compatibility with every PS2EXE version (including `conHost`, `embedFiles` and legacy `runtime20`/`runtime40`); capabilities ps12exe lacks are rewritten at compile time.

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

### Pulling a ps1 back out of an exe (exe21sp)

```powershell
exe21sp -inputFile .\target.exe -outputFile .\target.ps1
```

`exe21sp` pulls the embedded PowerShell script out of a ps12exe-built executable and writes it back to a `.ps1` file or to standard output. It uses the same `$LastExitCode` convention as ps12exe: 0 = success, 1 = input/parse error (e.g. not a ps12exe exe), 2 = invocation error (e.g. no input when redirected), 3 = resource/internal error (e.g. file not found).

### Pipeline and redirection

- **ps12exe**: When stdout (or stdin/stderr) is redirected, ps12exe writes only the path of the generated exe to stdout so you can capture it (e.g. `$exe = ps12exe .\a.ps1`).
- **exe21sp**: Accepts exe paths or URLs from pipeline input (e.g. `Get-ChildItem *.exe | exe21sp` or `".\app.exe" | exe21sp`).
- **exe21sp**: If `-outputFile` is not specified and stdout is **not** redirected, the decompiled script is saved to a `.ps1` file with the same base name as the exe in the same directory.
- **exe21sp**: If `-outputFile` is not specified and stdout **is** redirected, the decompiled script is written to stdout.

### Self-Host Web Server

```powershell
Start-ps12exeWebServer
```

Starts a web server for compiling PowerShell scripts online.

### VS Code Extension

The [ps12exe VS Code extension](https://marketplace.visualstudio.com/items?itemName=steve02081504.ps12exe) compiles a `.ps1` script into an executable — or opens ps12exeGUI — without leaving the editor, and adds editor support for the preprocessor directives (syntax highlighting, diagnostics, `#_if` auto-close, folding, go-to-definition, hover, completion and formatting).

![image](https://github.com/user-attachments/assets/5cace798-2737-479a-8d1e-882484f26f31)

`Set-ps12exeContextMenu` installs it automatically; you can also install `steve02081504.ps12exe` manually.

## Parameters

### GUI Parameters

```powershell
ps12exeGUI [[-ConfigFile] '<config file>'] [-PS1File '<PS1 file>'] [-Locale '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<PS1 file>'] [-Locale '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : Configuration file to load.
PS1File    : Script file to compile.
Locale     : The language code to use.
UIMode     : The UI mode to use (Dark, Light, or Auto).
help       : Show this help message.
```

### Console Parameters

```powershell
[input |] ps12exe [[-inputFile] '<filename|url>' | -Content '<script>'] [-outputFile '<filename>']
        [-App @{Windowed=$true; Silence=@('Output','Error'); OutputEncoding='UTF8'|'UTF16LE'|'Default'; VisualStyles=$true;
        ExitOnCancel=$true; CredentialGUI=$true; DpiAware=$true; WinFormsDpiAware=$true}]
        [-Os @{Admin=$true; ModernOS=$true; LongPaths=$true; Virtualize=$true}]
        [-Build @{Target='Framework4.0'|'Framework2.0'|'Core'; Platform='AnyCpu'|'x64'|'x86'; Apartment='STA'|'MTA';
        Culture='<culture>'; Options='<options>'; KeepSource=$true; Minify={<scriptblock>}; TempDir='<directory>'}]
        [-Resources @{Icon='<file|url>'; Title='<title>'; Description='<description>'; Company='<company>';
        Product='<product>'; Copyright='<copyright>'; Trademark='<trademark>'; Version='<version>'}]
        [-Signing @{Certificate='<PFX path>'; Password='<password>'; Thumbprint='<thumbprint>'; Timestamp='<timestamp server>'}]
        [-PreprocessOnly] [-Golf] [-Sandbox] [-NoUpdateCheck] [-Locale '<language code>'] [-ConfigFile] [-help]
```

```text
input            : String of the contents of the PowerShell script file (same as -Content).
inputFile        : PowerShell script file path or URL that you want to convert to executable (file has to be UTF8 or UTF16 encoded).
Content          : PowerShell script content that you want to convert to executable.
outputFile       : Destination executable file name or folder (defaults to inputFile with the extension '.exe').
App              : A hashtable describing how the produced application behaves. Supported keys:
                   Windowed         : Build a Windows Forms application without a console window.
                   Silence          : Stream names to suppress; one or more of 'Output', 'Verbose', 'Error', 'Warning', 'Debug', or '*'.
                   OutputEncoding   : Console output encoding; 'Default', 'UTF8' or 'UTF16LE'.
                   VisualStyles     : Enable visual styles for GUI applications (default $true).
                   ExitOnCancel     : Exit when Cancel or 'X' is selected in a Read-Host input box.
                   CredentialGUI    : Use a GUI for prompting credentials in console mode.
                   DpiAware         : Mark the compiled executable as DPI aware.
                   WinFormsDpiAware : Let WinForms use DPI scaling (requires Windows 10 and .NET 4.7 or up).
Os               : A hashtable of OS integration options. Supported keys:
                   Admin            : If UAC is enabled, the compiled executable will run only in an elevated context (UAC dialog appears if required).
                   ModernOS         : Use functions of the newest Windows versions (execute [Environment]::OSVersion to see the difference).
                   LongPaths        : Enable long paths ( > 260 characters) if enabled on the OS (works only with Windows 10 or up).
                   Virtualize       : Application virtualization is activated (forcing x86 runtime).
Build            : A hashtable of build/toolchain options. Supported keys:
                   Target           : Target runtime version ('Framework4.0' by default; 'Framework2.0' and 'Core' are supported). 'Core' builds a PowerShell Core (.NET) executable (needs PowerShell Core and .NET on both build and target machines; the output is much larger).
                   Platform         : Compile for specific runtime only (possible values are 'AnyCpu', 'x64', and 'x86').
                   Apartment        : 'Single Thread Apartment' or 'Multi Thread Apartment' mode.
                   Culture          : Locale for the compiled executable (current user culture if not specified).
                   Options          : Additional compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx).
                   KeepSource       : Create helpful information for debugging.
                   Minify           : Scriptblock to minify the script before compiling.
                   TempDir          : Directory for storing temporary files (default is a randomly generated temp directory in %temp%).
Resources        : A hashtable that contains version resources for the compiled executable (Icon, Title, Description, Company, Product, Copyright, Trademark, Version). Icon can be a file path or URL; for .exe/.dll append ,<index> to pick a resource icon (default 0), e.g. shell32.dll,3.
Signing          : A hashtable containing code signing options for the compiled executable (Certificate, Password, Thumbprint, Timestamp). Either Certificate or Thumbprint must be specified.
PreprocessOnly   : Preprocess the input script and return it without compiling.
Golf             : Enable golf mode, adding abbreviations and common functions.
Sandbox          : Compile scripts with additional protection, preventing native files from being accessed.
NoUpdateCheck    : Skip the check for new versions of ps12exe.
Locale           : The language code to use.
ConfigFile       : Write a config file (<outputfile>.exe.config).
Help             : Show this help message.
```

## Remarks

### Error Handling

Unlike many PowerShell functions, ps12exe sets `$LastExitCode` to report success or failure, but exceptions may still occur.  
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
| 1          | Input or code error    |
| 2          | Invocation error       |
| 3          | Internal ps12exe error |

### Preprocessing

<a id="preprocessing-overview"></a>

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

<a id="preprocessing-if"></a>

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

<a id="preprocessing-include"></a>

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

<a id="preprocessing-include-as"></a>

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

<a id="preprocessing-bang"></a>

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

The `#_!!` prefix is stripped from any line that starts with it.

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

When you need several modules, you can separate them with spaces, commas, semicolons, or the Chinese enumeration comma (、) instead of multiple `#_require` lines.

```powershell
#_require module1 module2;module3、module4,module5
```

#### `#_pragma`

<a id="preprocessing-pragma"></a>

The pragma preprocessor directive has no effect on the content of the script, but it modifies the parameters used for compilation.  
Here's an example:

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

As you can see, `#_pragma App.Windowed` makes the generated exe file run in windowed mode, even if we didn't specify `-App @{Windowed=$true}` at compile time.
The pragma command can set any compilation parameter; use `.` in the name to set nested values:

```powershell
#_pragma App.Windowed #windowed
#_pragma App.Windowed $false #console
#_pragma Resources.Icon $PSScriptRoot/icon.ico #set icon
#_pragma Resources.Title "title" #set title
#_pragma Signing.Certificate "C:\Cert\mycert.pfx" #set the code signing certificate
```

String pragma values can also contain `$(...)` subexpressions, which are evaluated at preprocess time, e.g. `#_pragma Resources.Icon $(Join-Path $env:USERPROFILE 'foo.ico')`. Only whitelisted path-related commands (`Get-Command`, `Join-Path`, `Split-Path`, `Resolve-Path`, `Convert-Path`, `Get-Item`, `Test-Path`, `Get-ChildItem`, plus `Get-Content` outside Sandbox), variables (`$env:*` (inside Sandbox only `$env:windir`/`$env:SystemRoot`), `$PSScriptRoot`, `$ScriptRoot`, `$HOME`, `$PWD`, `$PSCommandPath`) and common harmless instance methods (e.g. `ToUpper`, `Trim`, `Split`, `ToString`) are allowed; anything else aborts the compile. Single-quoted values stay fully literal. Sandbox mode also ignores `#_pragma outputFile`, `Build.TempDir`, `Build.Minify`, and `Signing.Certificate`, and only fetches http(s) URLs that resolve to public addresses (redirect targets are restricted the same way). Local `Resources.Icon` paths are only allowed under the Windows directory.

#### `#_balus`

<a id="preprocessing-balus"></a>

```powershell
#_balus <exitcode>
#_balus
```

When the code reaches this point, the process exits with the given exit code and deletes the EXE file.

### Minification

Since ps12exe's "compilation" embeds everything in the script verbatim as a resource in the resulting executable, the resulting executable will be large if the script has a lot of unnecessary strings.  
You can specify a script block with the `Minify` key of `-Build` that will process the script after preprocessing, before compilation, to achieve a smaller generated executable.

If you don't know how to write such a script block, you can use [psminnifyer](https://github.com/steve02081504/psminnifyer).

```powershell
& ./ps12exe.ps1 ./main.ps1 -App @{Windowed=$true} -Build @{Minify={ $_ | &./psminnifyer.ps1 }}
```

### List of Cmdlets Not Implemented

The basic input/output commands had to be rewritten in C# for ps12exe. Not implemented are _`Write-Progress`_ in console mode, and _`Start-Transcript`_/_`Stop-Transcript`_ (no proper reference implementation by Microsoft).

### GUI Mode Output Formatting

By default, PowerShell formats cmdlet output line by line (as a string array). If a command produces 10 lines and you use GUI output, you get 10 message boxes. Pipe to `Out-String` to combine lines into one string so a single message box shows everything (e.g. `dir C:\ | Out-String`).

### Config Files

ps12exe can create config files with the name of the generated executable + ".config". In most cases, those config files are not necessary; they are a manifest that tells which .Net Framework version should be used. As you will usually use the actual .Net Framework, try running your executable without the config file.

### Parameter Processing

Compiled scripts process parameters like the original script does. One restriction comes from the Windows environment: for all executables, command-line arguments are ultimately strings.

When the script has a top-level `param()` block, ps12exe parses argument values as PowerShell data (PSD): hashtables `@{}`, ordered hashtables `[ordered]@{}`, arrays `@()`, and casts to safe types such as `[int]'5'` or `[hashtable]@{}` are passed to the parameter as the corresponding object, so no manual conversion is needed:

```powershell
# script: param([hashtable]$Config)
app.exe -Config "@{name='Bob'; tags=@('a','b')}"
app.exe -Config "[ordered]@{first='1'; second='2'}"
```

The value must be quoted: shells stringify an unquoted `@{...}` (the program only receives the text `System.Collections.Hashtable`). Anything that is not data (an expression or a command) is passed as a plain string and is never evaluated, so `-Config "@{x=(Get-Date)}"` does not run code — it simply fails to bind.

Piped input values are still strings.

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

You can still use `$PSScriptRoot` to retrieve the directory path where the executable is located, and `$PSCommandPath` to obtain the path of the executable itself.

### Window in Background in `App.Windowed` Mode

When an external window is opened in a script with `App.Windowed` mode (i.e., for `Get-Credential` or for a command that needs a `cmd.exe` shell), the next window is opened in the background.

The reason for this is that on closing the external window, Windows tries to activate the parent window. Since the compiled script has no window, the parent window of the compiled script is activated instead, normally the window of Explorer or PowerShell.

To work around this, `$Host.UI.RawUI.FlushInputBuffer()` opens an invisible window that can be activated. The following call of `$Host.UI.RawUI.FlushInputBuffer()` closes this window (and so on).

The following example will not open a window in the background anymore, as a single call of `ipconfig | Out-String` will do:

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

### Standard Input and `$input`

A compiled exe only reads redirected standard input (line by line, as pipeline input) when the script uses `$input` at its **top level**:

- If `$input` is used: behaves like PS2EXE — stdin is consumed as pipeline input, so raw stdin (`[Console]::In` / `Console.OpenStandardInput()`) reaches EOF afterwards.
- If `$input` is not used: stdin is not read at all; the raw standard input is left untouched and startup does not wait for stdin (a parent that keeps the pipe open no longer blocks it), and child processes can still inherit stdin.

Only the script's top level counts: a `$input` inside functions, script blocks or classes is that scope's own pipeline input and is ignored.

For example, if the script calls `[Console]::In.ReadToEnd()` and never uses `$input`, then after compiling, `echo hi | .\tool.exe` receives `hi`.

### Constant Evaluation

For constant-only, side-effect-free scripts, ps12exe evaluates them at compile time and emits the result as a tiny exe (the TinySharp path, usually around 1KB); it falls back to the normal build when evaluation times out (7 seconds by default) or the result is too long. If the evaluation environment differs from runtime, or you simply want the full PowerShell host, add either pragma below to opt out of that optimisation explicitly:

- `#_pragma Build.ConstEval.Enabled 0`: declare this script is not a constant; skip constant evaluation.
- `#_pragma Build.ConstEval.Timeout 1`: declare constant evaluation already timed out; fall back as if it had timed out.

Both are parsed as ordinary nested pragmas during preprocessing, so they can go on any line; after falling back to the normal host they are just ordinary comments.

## Comparative Advantages

### Quick Comparison

| Comparison Content                                | ps12exe                                                                                | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615)                     |
| ------------------------------------------------- | -------------------------------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| Pure script repository 📦                         | ✔️ All text files except images & bundled helper DLLs                                  | ❌ Ships `Win-PS2EXE.exe` with an open source license                                              |
| Command to generate hello world 🌍                | 😎`'"Hello World!"' \| ps12exe`                                                        | 🤔`echo "Hello World!" *> a.ps1; PS2EXE a.ps1; rm a.ps1`                                           |
| Constant hello world executable 💾                | 🥰1024 bytes (constant-evaluated at compile time)                                      | ❌ Not supported; 25088 bytes                                                                      |
| Non-constant hello world executable 💾            | 🥰14848 bytes                                                                          | 😨25088 bytes                                                                                      |
| Compile-time constant evaluation ⚡               | ✔️                                                                                     | ❌                                                                                                 |
| PowerShell Core (7+) / cross-platform target 🧬   | ✔️ `Build.Target Core` (Windows / Linux / macOS)                                       | ❌ Windows PowerShell 5.1 only                                                                     |
| GUI multilingual support 🌐                       | ✔️ (7 languages, dark mode)                                                            | ❌                                                                                                 |
| Syntax check during compilation ✔️                | ✔️                                                                                     | ❌                                                                                                 |
| Preprocessing feature 🔄                          | ✔️                                                                                     | ❌                                                                                                 |
| `-extract` and other special parameter parsing 🧹 | 🗑️ Removed (use the `exe21sp` tool instead)                                            | 🥲 Requires source code modification                                                               |
| PR welcome level 🤝                               | 🥰 Welcome!                                                                            | 🤷 14 PRs, 13 of which were closed                                                                 |
| Political / DEI / stance bias 🕊️                  | ✔️ None; any valuable PR is welcome — from a human, an AI, or a monkey at a typewriter | ❌ Readme takes an anti-AI stance ("artificial intelligence is killing creativity and our nature") |

ps12exe's developer does not use this project to promote a political, DEI or other ideological stance — any valuable PR is welcome, whether it comes from a human, an AI, or a monkey at a typewriter.

### Size & Speed Benchmark 🔬

Measured on Windows 11 with PowerShell 7.6.6 (.NET 10) and Windows PowerShell 5.1, 20 warm runs each. The process-creation floor (`cmd /c exit`) is ~15 ms. Reproduce with `pwsh -File ../tools/Benchmark/Compare-Compilers.ps1 -IncludeCore`.

| Build                                              | Output size | Warm startup |
| -------------------------------------------------- | ----------- | ------------ |
| Windows PowerShell 5.1 running the script directly | —           | ~245 ms      |
| ps12exe · constant · Framework4.0                  | 1024 bytes  | ~33 ms       |
| ps12exe · non-constant · Framework4.0              | 14848 bytes | ~210 ms      |
| PS2EXE 1.0.18 · non-constant                       | 25088 bytes | ~223 ms      |
| -------------------------------------------------- | ----------- | ------------ |
| pwsh 7 running the script directly                 | —           | ~450 ms      |
| ps12exe · constant · Core                          | ~169 KB     | ~70 ms       |
| ps12exe · non-constant · Core                      | ~185 KB     | ~395 ms      |
| PS2EXE 1.0.18 · non-constant · Core                | not support | not support  |

A constant script is evaluated at compile time, so its exe is 1 KB and never starts PowerShell — about 24× smaller and 6× faster to launch than a PS2EXE hello world. Non-constant exes are ~40% smaller than PS2EXE's, and for top-level-variable-heavy scripts they also run faster, because the script executes inside a function (local scope) rather than at global scope.

The compiler itself is installed as a PowerShell module:

| Compiler package         | Unpacked | Compressed |
| ------------------------ | -------- | ---------- |
| ps12exe (current master) | ~1.29 MB | ~513 KB    |
| PS2EXE 1.0.18            | ~171 KB  | ~46 KB     |

ps12exe's module is larger because it is a dependency-free, pure-script compiler that bundles trimmed [AsmResolver](https://github.com/Washi1337/AsmResolver) binaries (used to emit the 1 KB constant exes and to unpack payloads), 7 localisations and a pure-script GUI; PS2EXE ships almost nothing and relies on the .NET Framework compiler built into Windows.

### Compiled-EXE Runtime Behaviour 🖥️

Whether native child processes started by the EXE see a real console TTY ([#59](https://github.com/steve02081504/ps12exe/issues/59)), whether the script can read raw stdin ([#62](https://github.com/steve02081504/ps12exe/issues/62)), and whether the special path variables resolve — all verified from a real console window on Windows 11:

| Capability                                                 | ps12exe                              | [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615) |
| ---------------------------------------------------------- | ------------------------------------ | ------------------------------------------------------------------------------ |
| Native child process sees a console TTY (`isTTY`)          | ✔️                                   | ❌                                                                             |
| Raw stdin (`[Console]::In`) readable                       | ✔️ (unless the script uses `$input`) | ❌                                                                             |
| `$PSCommandPath` / `$PSScriptRoot` resolve                 | ✔️ (exe path / exe directory)        | ❌                                                                             |
| Command-line arguments parsed as PSD data (tables/objects) | ✔️ (`-Config "@{...}"`)              | ❌ (strings only)                                                              |

PS2EXE 1.0.18 always pipes script output through `Out-String` and eagerly drains redirected stdin before the script runs, so native children lose the console handle and stdin reaches EOF; ps12exe runs the script through the host (`Out-Default`) and only drains stdin when the script actually uses `$input`. PS2EXE also leaves `$PSCommandPath`/`$PSScriptRoot` empty inside the compiled program (it offers its own `$ScriptRoot` instead), while ps12exe maps both to the generated exe.

### Detailed Comparison

Compared to [`MScholtes/PS2EXE@1.0.18`](https://github.com/MScholtes/PS2EXE/tree/05c62615), this project brings the following improvements:

| Improvement Content                                           | Description                                                                                        |
| ------------------------------------------------------------- | -------------------------------------------------------------------------------------------------- |
| ✔️ Syntax check during compilation                            | Syntax check during compilation to improve code quality                                            |
| ⚡ Compile-time constant evaluation                           | Side-effect-free scripts are evaluated at build time and emitted as ~1 KB exes                     |
| 🧬 PowerShell Core / cross-platform target                    | `Build.Target Core` targets PowerShell 7+ on Windows, Linux and macOS                              |
| 🔄 Powerful preprocessing feature                             | Preprocess the script before compilation, no need to copy and paste all content into the script    |
| 🛠️ `Build.Options` parameter                                  | New parameter, letting you further customize the generated executable file                         |
| 📦️ `Build.Minify` parameter                                   | Preprocess the script before compilation to generate a smaller executable file                     |
| 🌐 Support for compiling scripts and included files from URL  | Support for downloading icons from URL                                                             |
| 🖥️ Optimisation of `App.Windowed` parameter                   | Optimised option handling and window title display; you can now set the title of the custom pop-up |
| ✍️ Code signing and icon auto-conversion                      | Sign output with a PFX certificate or a store thumbprint, and convert icons automatically          |
| 🧰 Extras: `exe21sp`, web server, context menu, interact mode | Decompile exes, compile online, right-click compile and more                                       |
| 🧹 Removed exe files                                          | Removed exe files from the code repository                                                         |
| 🌍 Multilingual support, pure script GUI                      | Better multilingual support, pure script GUI, support for dark mode                                |
| 📖 Separated cs files from ps1 files                          | Easier to read and maintain                                                                        |
| 🚀 More improvements                                          | And more...                                                                                        |

## Stargazers over time ⭐

[![Stargazers over time](https://starchart.cc/steve02081504/ps12exe.svg?variant=adaptive)](https://starchart.cc/steve02081504/ps12exe)
