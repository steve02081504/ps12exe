# ps12exe

WARNING: Please avoid compiling scripts from unknown sources with this project for the following reasons:  

1. ps12exe allows to include scripts indirectly from url, which means you can include scripts from any url in the script.  
2. When ps12exe determines (through a not-so-rigorous set of rules) that all or some part of a script may be a constant program whose contents can be determined at compile time, it will automatically execute this script in an attempt to get the output.  

This means that if you compile a script whose contents you don't even know, it's entirely possible that the script will cause ps12exe to download and execute a malicious script at compile time.  
If you don't believe it, try `"while(1){}" | ps12exe -Verbose`  

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery download num](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![CodeFactor](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![repo img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

[中文](./README_CN.md)

## Install

```powershell
Install-Module ps12exe
```

(you can also clone this repository and run `./ps12exe.ps1` directly)

## Usage

### GUI mode

```powershell
ps12exeGUI
```

### Console mode

```powershell
ps12exe .\source.ps1 .\target.exe
```

compiles `source.ps1` into the executable target.exe (if `.\target.exe` is omitted, output is written to `.\source.exe`).

```powershell
'"Hello World!"' | ps12exe
```

compiles `"Hello World!"` into the executable `.\a.exe`.

## Project Comparison

When compared to [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5), this project introduces the following enhancements:

- Syntax checking at compile time.
- Incorporates [robust preprocessing capabilities](#prepossessing), enabling you to preprocess scripts prior to compilation, eliminating the need to embed everything into the script manually.
- Special parameters are not enabled by default in the generated files anymore, but can be activated with the new `-SepcArgsHandling` parameter if required.
- A new `-CompilerOptions` parameter has been introduced, providing additional customization options for the generated executable.
- The [`-Minifyer` parameter](#minifyer) has been added, allowing for script preprocessing before compilation, resulting in smaller executables.
- Supports compiling scripts and including files from URLs, as well as downloading icons from URLs.
- Under the `-noConsole` parameter, option handling and window title display have been optimized. You can now personalize the title of popup windows by setting `$Host.UI.RawUI.WindowTitle`.
- Executable files have been removed from the code repository.
- Enhanced multi-language support, pure script GUI, and dark mode support.
- The C# file has been separated from the PowerShell file, making it easier to read and maintain.
- And much more...

## Parameter

### GUI parameters

```powershell
ps12exeGUI [[-ConfingFile] '<filename>'] [-Localize '<languagecode>'] [-UIMode 'Dark'|'Light'|'Auto']
```

```text
ConfingFile = path to config file (default is none)
   Localize = language code (default is current system language, try to load 'en-UK' if no corresponding language file is available, if still not available, iterate through all language files until available)
     UIMode = UI mode (default is Auto)
```

### Console parameters

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
           input = String of the contents of the powershell script file, same as -Content.
       inputFile = Powershell script file path or url that you want to convert to executable (file has to be UTF8 or UTF16 encoded)
         Content = Powershell script content that you want to convert to executable
      outputFile = destination executable file name or folder, defaults to inputFile with extension '.exe'
 CompilerOptions = additional compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx)
         TempDir = directory for storing temporary files (default is random generated temp directory in %temp%)
        minifyer = scriptblock to minify the script before compiling
SepcArgsHandling = the resulting executable will handle special arguments -debug, -extract, -wait and -end
    prepareDebug = create helpful information for debugging
    architecture = compile for specific runtime only. Possible values are 'x64' and 'x86' and 'anycpu'
            lcid = location ID for the compiled executable. Current user culture if not specified
  threadingModel = 'Single Thread Apartment' or 'Multi Thread Apartment' mode
       noConsole = the resulting executable will be a Windows Forms app without a console window
 UNICODEEncoding = encode output as UNICODE in console mode
   credentialGUI = use GUI for prompting credentials in console mode
  resourceParams = A hashtable that contains resource parameters for the compiled executable
      configFile = write a config file (<outputfile>.exe.config)
        noOutput = the resulting executable will generate no standard output (includes verbose and information channel)
         noError = the resulting executable will generate no error output (includes warning and debug channel)
  noVisualStyles = disable visual styles for a generated windows GUI application (only with -noConsole)
    exitOnCancel = exits program when Cancel or "X" is selected in a Read-Host input box (only with -noConsole)
        DPIAware = if display scaling is activated, GUI controls will be scaled if possible
winFormsDPIAware = if display scaling is activated, WinForms use DPI scaling (requires Windows 10 and .Net 4.7 or up)
    requireAdmin = if UAC is enabled, compiled executable run only in elevated context (UAC dialog appears if required)
       supportOS = use functions of newest Windows versions (execute [Environment]::OSVersion to see the difference)
      virtualize = application virtualization is activated (forcing x86 runtime)
       longPaths = enable long paths ( > 260 characters) if enabled on OS (works only with Windows 10 or up)

```

With `SepcArgsHandling` parameter, generated executable has the following reserved parameters:

```text
-debug              Forces the executable to be debugged. It calls "System.Diagnostics.Debugger.Launch()".
-extract:<FILENAME> Extracts the powerShell script inside the executable and saves it as FILENAME.
                    The script will not be executed.
-wait               At the end of the script execution it writes "Hit any key to exit..." and waits for a key to be pressed.
-end                All following options will be passed to the script inside the executable.
                    All preceding options are used by the executable itself and will not be passed to the script.
```

## Remarks

### Prepossessing

ps12exe preprocesses the script before compiling.  

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
#_if PSEXE
	#_include ../src/opt/opt_init.ps1
#_else
	. $PSScriptRoot/../src/opt/opt_init.ps1
#_endif
```

Only the following conditions are now supported: `PSEXE` and `PSScript`.  
`PSEXE` is true , `PSScript` is false.  

#### `#_include <filename|url>`/`#_include_as_value <valuename> <file|url>`

```powershell
#_include <filename|url>
#_include_as_value <valuename> <file|url>
```

Includes the content of the file `<filename|url>` or `<file|url>` into the script. The content of the file is inserted at the position of the `#_include`/`#_include_as_value` command.  

Unlike the `#_if` statement, if you don't enclose the filename in quotes, the `#_include` family treats the trailing space & `#` as part of the filename as well.  

```powershell
#_include $PSScriptRoot/super #weird filename.ps1
#_include "$PSScriptRoot/filename.ps1" #safe comment!
```

The content of the file is preprocessed when `#_include` is used, which allows you to include files at multiple levels.  

`#_include_as_value` inserts the content of the file as a string value into the script. The content of the file is not preprocessed.  

#### `#_!!`

```powershell
$Script:eshDir =
#_if PSScript #It is not possible to have $EshellUI in PSEXE and $PSScriptRoot is not valid!
if (Test-Path "$($EshellUI.Sources.Path)/path/esh") { $EshellUI.Sources.Path }
elseif (Test-Path $PSScriptRoot/../path/esh) { "$PSScriptRoot/.." }
elseif
#_else
	#_!!if
#_endif
(Test-Path $env:LOCALAPPDATA/esh) { "$env:LOCALAPPDATA/esh" }
```

Any line beginning with `#_!!` line that `#_!!` will be removed.

### Minifyer

Since ps12exe's "compilation" embeds everything in the script verbatim as a resource in the resulting executable, the resulting executable will be large if the script has a lot of useless strings.  
You can specify a script block with the `-Minifyer` parameter that will process the script after preprocessing before compilation to achieve a smaller generated executable.  

If you don't know how to write such a script block, you can use [psminnifyer](https://github.com/steve02081504/psminnifyer).

```powershell
& ./ps12exe.ps1 ./main.ps1 -NoConsole -Minifyer { $_ | &./psminnifyer.ps1 }
```

### List of cmdlets not implemented

The basic input/output commands had to be rewritten in C# for ps12exe. Not implemented are *`Write-Progress`* in console mode (too much work) and *`Start-Transcript`*/*`Stop-Transcript`* (no proper reference implementation by Microsoft).

### GUI mode output formatting

Per default in powershell outputs of commandlets are formatted line per line (as an array of strings). When your command generates 10 lines of output and you use GUI output, 10 message boxes will appear each awaiting for an OK. To prevent this pipe your commandto the comandlet `Out-String`. This will convert the output to one string array with 10 lines, all output will be shown in one message box (for example: `dir C:\ | Out-String`).

### Config files

ps12exe can create config files with the name of the `generated executable + ".config"`. In most cases those config files are not necessary, they are a manifest that tells which .Net Framework version should be used. As you will usually use the actual .Net Framework, try running your excutable without the config file.

### Parameter processing

Compiled scripts process parameters like the original script does. One restriction comes from the Windows environment: for all executables all parameters have the type String, if there is no implicit conversion for your parameter type you have to convert explicitly in your script. You can even pipe content to the executable with the same restriction (all piped values have the type String).

### Password security

Never store passwords in your compiled script!  
if you use the `SepcArgsHandling` parameter, everyone can simply decompile the script with the parameter `-extract`.  
For example  

```powershell
Output.exe -extract:.\Output.ps1
```

will decompile the script stored in Output.exe.
Even if you don't use it, the entire script is still easily visible to any .net decompiler.
![图片](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### Distinguish environment by script  

You can tell whether a script is running in a compiled exe or in a script by `$Host.Name`.  

```powershell
if ($Host.Name -eq "PSEXE") { Write-Output "ps12exe" } else { Write-Output "Some other host" }
```

### Script variables

Since ps12exe converts a script to an executable, script related variables are not available anymore. Especially the variable `$PSScriptRoot` is empty.

The variable `$MyInvocation` is set to other values than in a script.

You can retrieve the script/executable path independant of compiled/not compiled with the following code (thanks to JacquesFS):

```powershell
if ($MyInvocation.MyCommand.CommandType -eq "ExternalScript"){
	$ScriptPath = Split-Path -Parent -Path $MyInvocation.MyCommand.Definition
}
else{
	$ScriptPath = Split-Path -Parent -Path ([Environment]::GetCommandLineArgs()[0]) 
	if(!$ScriptPath){ $ScriptPath = "." }
}
```

### Window in background in -noConsole mode

When an external window is opened in a script with `-noConsole` mode (i.e. for `Get-Credential` or for a command that needs a `cmd.exe` shell) the next window is opened in the background.

The reason for this is that on closing the external window windows tries to activate the parent window. Since the compiled script has no window, the parent window of the compiled script is activated instead, normally the window of Explorer or Powershell.

To work around this, `$Host.UI.RawUI.FlushInputBuffer()` opens an invisible window that can be activated. The following call of `$Host.UI.RawUI.FlushInputBuffer()` closes this window (and so on).

The following example will not open a window in the background anymore as a single call of `ipconfig | Out-String` will do:

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```
