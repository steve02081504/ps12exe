# ps12exe

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

[中文](./README_CN.md)

## Install

```powershell
Install-Module ps12exe
```

(you can also clone this repository and run `./ps12exe.ps1` directly)

## Usage

```powershell
ps12exe .\source.ps1 .\target.exe
```

compiles `source.ps1` into the executable target.exe (if `.\target.exe` is omitted, output is written to `.\source.exe`).

## Comparison

Compared to [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5), this project:

- Adds [powerful preprocessing features](#prepossessing) that allow you to preprocess the script before compiling (instead of copy-pasting everything and embedding it into the script)
- Special parameters are no longer enabled by default in the generated files, but can be enabled with the new `-SepcArgsHandling` parameter if needed.
- The `-CompilerOptions` parameter has been added to allow you to further customise the generated executable.
- Added [`-Minifyer` parameter](#minifyer) to allow you to pre-process scripts before compilation to get smaller generated executables
- Support for compiling scripts and including files from urls, support for downloading icons from urls
- Optimised option handling and window title display under the `-noConsole` parameter, you can now customise the title of popup windows by setting `$Host.UI.RawUI.WindowTitle`.
- Removed exe files from code repository
- Removed the code for ps12exe-GUI, considering it's cumbersome to use and requires extra effort to maintain
- Separated the cs file from the ps1 file, easier to read and maintain.
- and more...

## Parameter

```powershell
ps12exe ([-inputFile] '<filename|url>' | -Content '<script>') [-outputFile '<filename>'] [-CompilerOptions '<options>']
       [-TempDir '<directory>'] [-Minifyer '<scriptblock>']
       [-SepcArgsHandling] [-prepareDebug] [-x86|-x64] [-lcid <lcid>] [-STA|-MTA] [-noConsole] [-UNICODEEncoding]
       [-credentialGUI] [-iconFile '<filename|url>'] [-title '<title>'] [-description '<description>']
       [-company '<company>'] [-product '<product>'] [-copyright '<copyright>'] [-trademark '<trademark>']
       [-version '<version>'] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
       [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths]
```

```text
       inputFile = Powershell script file that you want to convert to executable (file has to be UTF8 or UTF16 encoded)
         Content = Powershell script content that you want to convert to executable
      outputFile = destination executable file name or folder, defaults to inputFile with extension '.exe'
 CompilerOptions = additional compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx)
         TempDir = directory for storing temporary files (default is random generated temp directory in %temp%)
        Minifyer = scriptblock to minify the script before compiling
SepcArgsHandling = handle special arguments -debug, -extract, -wait and -end
    prepareDebug = create helpful information for debugging
      x86 or x64 = compile for 32-bit or 64-bit runtime only
            lcid = location ID for the compiled executable. Current user culture if not specified
      STA or MTA = 'Single Thread Apartment' or 'Multi Thread Apartment' mode
       noConsole = the resulting executable will be a Windows Forms app without a console window
 UNICODEEncoding = encode output as UNICODE in console mode
   credentialGUI = use GUI for prompting credentials in console mode
        iconFile = icon file name for the compiled executable
           title = title information (displayed in details tab of Windows Explorer's properties dialog)
     description = description information (not displayed, but embedded in executable)
         company = company information (not displayed, but embedded in executable)
         product = product information (displayed in details tab of Windows Explorer's properties dialog)
       copyright = copyright information (displayed in details tab of Windows Explorer's properties dialog)
       trademark = trademark information (displayed in details tab of Windows Explorer's properties dialog)
         version = version information (displayed in details tab of Windows Explorer's properties dialog)
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

Compiled scripts process parameters like the original script does. One restriction comes from the Windows environment: for all executables all parameters have the type STRING, if there is no implicit conversion for your parameter type you have to convert explicitly in your script. You can even pipe content to the executable with the same restriction (all piped values have the type STRING).

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
