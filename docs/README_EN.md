# ps12exe, eh wot?

> [!CAUTION]
> I say, old chap, be a good sport and avoid storing your passwords directly in the source code, wouldn't you? Bit of a sticky wicket, that.  
> Do have a gander at [this](#password-security-terribly-important) for a spot more information.  

## Introduction, by Jove!

ps12exe, you see, is a PowerShell module, bit of a wizard, really, that allows one to create an executable file, quite spiffing, from a .ps1 script. What?  

[![CI](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml/badge.svg)](https://github.com/steve02081504/ps12exe/actions/workflows/CI.yml)
[![PSGallery download num](https://img.shields.io/powershellgallery/dt/ps12exe)](https://www.powershellgallery.com/packages/ps12exe)
[![GitHub issues by-label bug](https://img.shields.io/github/issues/steve02081504/ps12exe/bug?label=bugs)](https://github.com/steve02081504/ps12exe/issues?q=is%3Aissue+is%3Aopen+label%3Abug)
[![Codacy Badge](https://app.codacy.com/project/badge/Grade/ecfd57f5f2eb4ac5bbcbcd525b454f99)](https://app.codacy.com/gh/steve02081504/ps12exe/dashboard?utm_source=gh&utm_medium=referral&utm_content=&utm_campaign=Badge_grade)
[![CodeFactor](https://www.codefactor.io/repository/github/steve02081504/ps12exe/badge/master)](https://www.codefactor.io/repository/github/steve02081504/ps12exe/overview/master)
[![PRs Welcome](https://img.shields.io/badge/PRs-welcome-brightgreen.svg)](http://makeapullrequest.com)

![repo img](https://repository-images.githubusercontent.com/729678966/3ed3f02f-c7c9-4a18-b1f5-255e667643b6)

[![中文](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/China.png)](./docs/README_CN.md)
[![日本語](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Japan.png)](./docs/README_JP.md)
[![Español](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/Spain.png)](./docs/README_ES.md)
[![हिन्दी](https://raw.githubusercontent.com/gosquared/flags/master/flags/flags/shiny/48/India.png)](./docs/README_HI.md)

## Installation, old bean

```powershell
Install-Module ps12exe #Install the ps12exe module, what?
Set-ps12exeContextMenu #Set the right-click menu, rather spiffing
```

(One can also clone this repository and run `./ps12exe.ps1` directly, if one is so inclined.)

**Having a spot of bother upgrading from PS2EXE to ps12exe? Not to worry!**  
PS2EXE2ps12exe can hook PS2EXE calls into ps12exe, quite clever, really. All you need do is uninstall PS2EXE and install this, then carry on using PS2EXE as per usual.

```powershell
Uninstall-Module PS2EXE
Install-Module PS2EXE2ps12exe
```

## Usage, my good sir

### Right-click menu, what?

Once you've set `Set-ps12exeContextMenu`, you can quickly compile any ps1 file into an exe, rather nifty, or open ps12exeGUI on this file by simply right-clicking on it.  
![image](https://github.com/steve02081504/ps12exe/assets/31927825/24e7caf7-2bd8-46aa-8e1d-ee6da44c2dcc)

### GUI mode, top-hole!

```powershell
ps12exeGUI
```

### Console mode, for the technically minded

```powershell
ps12exe .\source.ps1 .\target.exe
```

compiles `source.ps1` into the executable target.exe (if `.\target.exe` is omitted, output is written to `.\source.exe`). Quite straightforward, really.  

```powershell
'"Hello World!"' | ps12exe
```

compiles `"Hello World!"` into the executable `.\a.exe`. Jolly good!  

```powershell
ps12exe https://raw.githubusercontent.com/steve02081504/ps12exe/master/src/GUI/Main.ps1
```

compiles `Main.ps1` from the internet, bit of a marvel that, into the executable `.\Main.exe`. Splendid!  

### Self-Host WebServer, bit of a marvel

```powershell
Start-ps12exeWebServer
```

Starts a web server, rather clever, that can be used to compile PowerShell scripts online. Wizardry, I tell you!  

## Parameter, eh what?

### GUI parameters, for the discerning gentleman

```powershell
ps12exeGUI [[-ConfigFile] '<config file>'] [-PS1File '<PS1 file>'] [-Localize '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]

ps12exeGUI [[-PS1File] '<PS1 file>'] [-Localize '<language code>'] [-UIMode 'Dark'|'Light'|'Auto'] [-help]
```

```text
ConfigFile : The configuration file to load, what?
PS1File    : The script file to be compiled, you see.
Localize   : The language code to use, rather important.
UIMode     : The UI mode to use, dark or light, your choice.
help       : Show this help message, in case you're feeling lost.
```

### Console parameters, for the chap who likes to tinker

```powershell
[input |] ps12exe [[-inputFile] '<filename|url>' | -Content '<script>'] [-outputFile '<filename>']
        [-CompilerOptions '<options>'] [-TempDir '<directory>'] [-minifyer '<scriptblock>'] [-noConsole]
        [-architecture 'x86'|'x64'] [-threadingModel 'STA'|'MTA'] [-prepareDebug] [-lcid <lcid>]
        [-resourceParams @{iconFile='<filename|url>'; title='<title>'; description='<description>'; company='<company>';
        product='<product>'; copyright='<copyright>'; trademark='<trademark>'; version='<version>'}]
        [-UNICODEEncoding] [-credentialGUI] [-configFile] [-noOutput] [-noError] [-noVisualStyles] [-exitOnCancel]
        [-DPIAware] [-winFormsDPIAware] [-requireAdmin] [-supportOS] [-virtualize] [-longPaths] [-targetRuntime '<Runtime>']
        [-GuestMode] [-Localize '<language code>'] [-help]
```

```text
input            : String of the contents of the powershell script file, same as -Content, what?
inputFile        : Powershell script file path or url that you want to convert to executable (file has to be UTF8 or UTF16 encoded), you see.
Content          : Powershell script content that you want to convert to executable, bit of a mouthful.
outputFile       : destination executable file name or folder, defaults to inputFile with extension '.exe', rather sensible.
CompilerOptions  : additional compiler options (see https://msdn.microsoft.com/en-us/library/78f4aasd.aspx), for the technically minded.
TempDir          : directory for storing temporary files (default is random generated temp directory in %temp%), keeps things tidy.
minifyer         : scriptblock to minify the script before compiling, bit of a space saver.
lcid             : location ID for the compiled executable. Current user culture if not specified, rather convenient.
prepareDebug     : create helpful information for debugging, in case things go pear-shaped.
architecture     : compile for specific runtime only. Possible values are 'x64' and 'x86' and 'anycpu', for the discerning chap.
threadingModel   : 'Single Thread Apartment' or 'Multi Thread Apartment' mode, for the advanced user.
noConsole        : the resulting executable will be a Windows Forms app without a console window, quite spiffing.
UNICODEEncoding  : encode output as UNICODE in console mode, for those foreign characters.
credentialGUI    : use GUI for prompting credentials in console mode, bit more user-friendly.
resourceParams   : A hashtable that contains resource parameters for the compiled executable, bit of a mouthful.
configFile       : write a config file (<outputfile>.exe.config), for those who like to configure.
noOutput         : the resulting executable will generate no standard output (includes verbose and information channel), keeps things quiet.
noError          : the resulting executable will generate no error output (includes warning and debug channel), for those who don't like errors.
noVisualStyles   : disable visual styles for a generated windows GUI application (only with -noConsole), for the minimalist.
exitOnCancel     : exits program when Cancel or "X" is selected in a Read-Host input box (only with -noConsole), rather sensible.
DPIAware         : if display scaling is activated, GUI controls will be scaled if possible, keeps things looking sharp.
winFormsDPIAware : if display scaling is activated, WinForms use DPI scaling (requires Windows 10 and .Net 4.7 or up), for the modern chap.
requireAdmin     : if UAC is enabled, compiled executable run only in elevated context (UAC dialog appears if required), for security.
supportOS        : use functions of newest Windows versions (execute [Environment]::OSVersion to see the difference), for the up-to-date chap.
virtualize       : application virtualization is activated (forcing x86 runtime), bit of a technicality.
longPaths        : enable long paths ( > 260 characters) if enabled on OS (works only with Windows 10 or up), for those with long file names.
targetRuntime    : target runtime version, 'Framework4.0' by default, 'Framework2.0' are supported, for compatibility.
GuestMode        : Compile scripts with additional protection, prevent native files from being accessed, bit of a security feature.
Localize         : The language code to use, for those who speak other languages.
Help             : Show this help message, in case you get lost.
```

## Remarks, old chap

### Prepossessing, bit of a mouthful

ps12exe preprocesses the script before compiling, quite clever, really.  

```powershell
# Read the program frame from the ps12exe.cs file
#_if PSEXE #This is the preprocessing code used when the script is compiled by ps12exe
	#_include_as_value programFrame "$PSScriptRoot/ps12exe.cs" #Inline the contents of ps12exe.cs into this script
#_else #Otherwise read the cs file normally
	[string]$programFrame = Get-Content $PSScriptRoot/ps12exe.cs -Raw -Encoding UTF8
#_endif
```

#### `#_if <condition>`/`#_else`/`#_endif`, rather conditional

```powershell
$LocalizeData =
	#_if PSScript
		. $PSScriptRoot\src\LocaleLoader.ps1
	#_else
		#_include "$PSScriptRoot/src/locale/en-UK.psd1"
	#_endif
```

Only the following conditions are now supported: `PSEXE` and `PSScript`.  
`PSEXE` is true, `PSScript` is false. Quite straightforward, really.  

#### `#_include <filename|url>`/`#_include_as_value <valuename> <file|url>`, bit of a mouthful

```powershell
#_include <filename|url>
#_include_as_value <valuename> <file|url>
```

Includes the content of the file `<filename|url>` or `<file|url>` into the script. The content of the file is inserted at the position of the `#_include`/`#_include_as_value` command. Rather like magic.  

Unlike the `#_if` statement, if you don't enclose the filename in quotes, the `#_include` family treats the trailing space & `#` as part of the filename as well. Bit of a quirk, that.  

```powershell
#_include $PSScriptRoot/super #weird filename.ps1
#_include "$PSScriptRoot/filename.ps1" #safe comment!
```

The content of the file is preprocessed when `#_include` is used, which allows you to include files at multiple levels. Quite clever, really.  

`#_include_as_value` inserts the content of the file as a string value into the script. The content of the file is not preprocessed. Bit more straightforward.  

In most cases you don't need to use the `#_if` and `#_include` preprocessing commands to make the scripts include sub-scripts correctly after conversion to exe. ps12exe automatically handles cases like the following and assumes that the target script should be included:

```powershell
. $PSScriptRoot/another.ps1
& $PSScriptRoot/another.ps1
$result = & "$PSScriptRoot/another.ps1" -args
```

Rather helpful, wouldn't you say?

#### `#_include_as_(base64|bytes) <valuename> <file|url>`, rather handy

```powershell
#_include_as_base64 <valuename> <file|url>
#_include_as_bytes <valuename> <file|url>
```

Includes the content of a file as a base64 string or byte array at preprocessing time. The file content itself is not preprocessed. Bit of a clever trick, that.  

Here's a simple packer example:

```powershell
#_include_as_bytes mydata $PSScriptRoot/data.bin
[System.IO.File]::WriteAllBytes("data.bin", $mydata)
```

This EXE will, upon execution, extract the `data.bin` file embedded in the script during compilation. Rather nifty, wouldn't you say?  

#### `#_!!`, bit of a mystery

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

Any line beginning with `#_!!` line that `#_!!` will be removed. Bit of a disappearing act, that.  

#### `#_require <modulesList>`, for the organised chap

```powershell
#_require ps12exe
#_pragma Console 0
$Number = [bigint]::Parse('0')
$NextNumber = $Number+1
$NextScript = $PSEXEscript.Replace("Parse('$Number')", "Parse('$NextNumber')")
$NextScript | ps12exe -outputFile $PSScriptRoot/$NextNumber.exe *> $null
$Number
```

`#_require` count the modules needed in the entire script and add the script equivalent of the following code before the first `#_require`:

```powershell
$modules | ForEach-Object{
	if(!(Get-Module $_ -ListAvailable -ea SilentlyContinue)) {
		Install-Module $_ -Scope CurrentUser -Force -ea Stop
	}
}
```

It is worth noting that the code it generates will only install modules, not import them.
Please use `Import-Module` as appropriate. Bit of a stickler for the rules, that.  

When you need to require more than one module, you can use spaces, commas, or semicolons and periods as separators instead of writing multi-line require statements.

```powershell
#_require module1 module2;module3、module4,module5
```

Keeps things tidy, wouldn't you say?

#### `#_pragma`, bit of a tweak

The pragma preprocessor directive has no effect on the content of the script, but modifies the parameters used for compilation. Bit of a behind-the-scenes operator, that.  
The following is an example:

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

As you can see, `#_pragma Console no` makes the generated exe file run in windowed mode, even if we didn't specify `-noConsole` at compile time. Rather clever, wouldn't you say?  
The pragma command can set any compilation parameter:

```powershell
#_pragma noConsole #windowed
#_pragma Console #console
#_pragma Console no #windowed
#_pragma Console true #console
#_pragma icon $PSScriptRoot/icon.ico #set icon
#_pragma title "title" #set title
```

Quite a few options, eh what?

#### `#_balus`, bit of a self-destruct button

```powershell
#_balus <exitcode>
#_balus
```

When the code reaches this point, the process exits with the given exit code and deletes the EXE file. Bit dramatic, don't you think?  

### Minifyer, bit of a space saver

Since ps12exe's "compilation" embeds everything in the script verbatim as a resource in the resulting executable, the resulting executable will be large if the script has a lot of useless strings. Bit of a waste of space, wouldn't you say?
You can specify a script block with the `-Minifyer` parameter that will process the script after preprocessing before compilation to achieve a smaller generated executable. Rather clever, that.  

If you don't know how to write such a script block, you can use [psminnifyer](https://github.com/steve02081504/psminnifyer).

```powershell
& ./ps12exe.ps1 ./main.ps1 -NoConsole -Minifyer { $_ | &./psminnifyer.ps1 }
```

### List of cmdlets not implemented, bit of a shame

The basic input/output commands had to be rewritten in C# for ps12exe. Not implemented are *`Write-Progress`* in console mode (too much work) and *`Start-Transcript`*/*`Stop-Transcript`* (no proper reference implementation by Microsoft). Bit of a nuisance, that.  

### GUI mode output formatting, bit of a faff

Per default in powershell outputs of commandlets are formatted line per line (as an array of strings). When your command generates 10 lines of output and you use GUI output, 10 message boxes will appear each awaiting for an OK. To prevent this pipe your command to the commandlet `Out-String`. This will convert the output to one string array with 10 lines, all output will be shown in one message box (for example: `dir C:\ | Out-String`). Bit of a workaround, that.  

### Config files, bit of a mystery

ps12exe can create config files with the name of the `generated executable + ".config"`. In most cases those config files are not necessary, they are a manifest that tells which .Net Framework version should be used. As you will usually use the actual .Net Framework, try running your executable without the config file. Bit of a trial and error approach, that.  

### Parameter processing, bit of a technicality

Compiled scripts process parameters like the original script does. One restriction comes from the Windows environment: for all executables all parameters have the type String, if there is no implicit conversion for your parameter type you have to convert explicitly in your script. You can even pipe content to the executable with the same restriction (all piped values have the type String). Bit of a limitation, that.  

### Password security, terribly important

Never store passwords in your compiled script!  
The entire script is easily visible to any .net decompiler. Bit of a security risk, that.

![图片](https://github.com/steve02081504/ps12exe/assets/31927825/92d96e53-ba52-406f-ae8b-538891f42779)

### Distinguish environment by script, rather important

You can tell whether a script is running in a compiled exe or in a script by `$Host.Name`. Bit of a tell-tale sign, that.  

```powershell
if ($Host.Name -eq "PSEXE") { Write-Output "ps12exe" } else { Write-Output "Some other host" }
```

### Script variables, bit of a technicality

Since ps12exe converts a script to an executable, the variable `$MyInvocation` is set to other values than in a script. Bit of a change, that.  

You still can use `$PSScriptRoot` to retrieve the directory path where the executable is located, and new `$PSEXEpath` to obtain the path of the executable itself. Rather handy, wouldn't you say?  

### Window in background in -noConsole mode, bit of a nuisance

When an external window is opened in a script with `-noConsole` mode (i.e. for `Get-Credential` or for a command that needs a `cmd.exe` shell) the next window is opened in the background. Bit of a bother, that.  

The reason for this is that on closing the external window windows tries to activate the parent window. Since the compiled script has no window, the parent window of the compiled script is activated instead, normally the window of Explorer or Powershell. Bit of a roundabout way of doing things, that.  

To work around this, `$Host.UI.RawUI.FlushInputBuffer()` opens an invisible window that can be activated. The following call of `$Host.UI.RawUI.FlushInputBuffer()` closes this window (and so on). Bit of a workaround, that.  

The following example will not open a window in the background anymore as a single call of `ipconfig | Out-String` will do:

```powershell
$Host.UI.RawUI.FlushInputBuffer()
ipconfig | Out-String
$Host.UI.RawUI.FlushInputBuffer()
```

### Comparative Advantages 🏆, rather proud of this

### Quick Comparison 🏁, bit of a race

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

### Detailed Comparison 🔍, for the discerning gentleman

Compared to [`MScholtes/PS2EXE@678a892`](https://github.com/MScholtes/PS2EXE/tree/678a89270f4ef4b636b69db46b31e1b4e0a9e1c5), this project brings the following improvements:

| Improvement Content | Description |
| --- | --- |
| ✔️ Syntax check during compilation | Syntax check during compilation to improve code quality |
| 🔄 Powerful preprocessing feature | Preprocess the script before compilation, no need to copy and paste all content into the script |
| 🛠️ `-CompilerOptions` parameter | New parameter, allowing you to further customize the generated executable file |
| 📦️ `-Minifyer` parameter | Preprocess the script before compilation to generate a smaller executable file |
| 🌐 Support for compiling scripts and included files from URL | Support for downloading icons from URL |
| 🖥️ Optimization of `-noConsole` parameter | Optimized option handling and window title display, you can now set the title of the custom pop-up window |
| 🧹 Removed exe files | Removed exe files from the code repository |
| 🌍 Multilingual support, pure script GUI | Better multilingual support, pure script GUI, support for dark mode |
| 📖 Separated cs files from ps1 files | Easier to read and maintain |
| 🚀 More improvements | And more... |

Quite a few improvements, wouldn't you say? Rather proud of it, actually.  
