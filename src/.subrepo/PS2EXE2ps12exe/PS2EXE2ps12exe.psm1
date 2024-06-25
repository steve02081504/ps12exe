<#
.SYNOPSIS
PS2EXE2ps12exe is a module to hook all PS2EXE calls into ps12exe.
#>

<#
.SYNOPSIS
Converts powershell scripts to standalone executables.
.DESCRIPTION
Converts powershell scripts to standalone executables. GUI output and input is activated with one switch,
real windows executables are generated. You may use the graphical front end Win-PS2EXE for convenience.

Please see Remarks on project page for topics "GUI mode output formatting", "Config files", "Password security",
"Script variables" and "Window in background in -noConsole mode".

A generated executable has the following reserved parameters:

-debug Forces the executable to be debugged. It calls "System.Diagnostics.Debugger.Launch()".
-extract:<FILENAME> Extracts the powerShell script inside the executable and saves it as FILENAME.
                                        The script will not be executed.
-wait At the end of the script execution it writes "Hit any key to exit..." and waits for a
                                        key to be pressed.
-end All following options will be passed to the script inside the executable.
                                        All preceding options are used by the executable itself.
.PARAMETER inputFile
Powershell script to convert to executable (file has to be UTF8 or UTF16 encoded)
.PARAMETER outputFile
destination executable file name or folder, defaults to inputFile with extension '.exe'
.PARAMETER prepareDebug
create helpful information for debugging of generated executable. See parameter -debug there
.PARAMETER runtime20
this switch forces PS2EXE to create a config file for the generated executable that contains the
"supported .NET Framework versions" setting for .NET Framework 2.0/3.x for PowerShell 2.0
.PARAMETER runtime40
this switch forces PS2EXE to create a config file for the generated executable that contains the
"supported .NET Framework versions" setting for .NET Framework 4.x for PowerShell 3.0 or higher
.PARAMETER x86
compile for 32-bit runtime only
.PARAMETER x64
compile for 64-bit runtime only
.PARAMETER lcid
location ID for the compiled executable. Current user culture if not specified
.PARAMETER STA
Single Thread Apartment mode
.PARAMETER MTA
Multi Thread Apartment mode
.PARAMETER nested
internal use
.PARAMETER noConsole
the resulting executable will be a Windows Forms app without a console window.
You might want to pipe your output to Out-String to prevent a message box for every line of output
(example: dir C:\ | Out-String)
.PARAMETER UNICODEEncoding
encode output as UNICODE in console mode, useful to display special encoded chars
.PARAMETER credentialGUI
use GUI for prompting credentials in console mode instead of console input
.PARAMETER iconFile
icon file name for the compiled executable
.PARAMETER title
title information (displayed in details tab of Windows Explorer's properties dialog)
.PARAMETER description
description information (not displayed, but embedded in executable)
.PARAMETER company
company information (not displayed, but embedded in executable)
.PARAMETER product
product information (displayed in details tab of Windows Explorer's properties dialog)
.PARAMETER copyright
copyright information (displayed in details tab of Windows Explorer's properties dialog)
.PARAMETER trademark
trademark information (displayed in details tab of Windows Explorer's properties dialog)
.PARAMETER version
version information (displayed in details tab of Windows Explorer's properties dialog)
.PARAMETER configFile
write a config file (<outputfile>.exe.config)
.PARAMETER noConfigFile
compatibility parameter
.PARAMETER noOutput
the resulting executable will generate no standard output (includes verbose and information channel)
.PARAMETER noError
the resulting executable will generate no error output (includes warning and debug channel)
.PARAMETER noVisualStyles
disable visual styles for a generated windows GUI application. Only applicable with parameter -noConsole
.PARAMETER exitOnCancel
exits program when Cancel or "X" is selected in a Read-Host input box. Only applicable with parameter -noConsole
.PARAMETER DPIAware
if display scaling is activated, GUI controls will be scaled if possible.
.PARAMETER winFormsDPIAware
creates an entry in the config file for WinForms to use DPI scaling. Forces -configFile and -supportOS
.PARAMETER requireAdmin
if UAC is enabled, compiled executable will run only in elevated context (UAC dialog appears if required)
.PARAMETER supportOS
use functions of newest Windows versions (execute [Environment]::OSVersion to see the difference)
.PARAMETER virtualize
application virtualization is activated (forcing x86 runtime)
.PARAMETER longPaths
enable long paths ( > 260 characters) if enabled on OS (works only with Windows 10 or up)
.EXAMPLE
Invoke-ps2exe C:\Data\MyScript.ps1
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScript.exe as console executable
.EXAMPLE
ps2exe -inputFile C:\Data\MyScript.ps1 -outputFile C:\Data\MyScriptGUI.exe -iconFile C:\Data\Icon.ico -noConsole -title "MyScript" -version 0.0.0.1
Compiles C:\Data\MyScript.ps1 to C:\Data\MyScriptGUI.exe as graphical executable, icon and meta data
.EXAMPLE
Win-PS2EXE
Start graphical front end to Invoke-ps2exe
#>
function Invoke-ps2exe {
	[CmdletBinding()]
	Param([STRING]$inputFile = $NULL, [STRING]$outputFile = $NULL, [SWITCH]$prepareDebug, [SWITCH]$runtime20, [SWITCH]$runtime40, [SWITCH]$x86, [SWITCH]$x64, [int]$lcid,
		[SWITCH]$STA, [SWITCH]$MTA, [SWITCH]$nested, [SWITCH]$noConsole, [SWITCH]$UNICODEEncoding, [SWITCH]$credentialGUI, [STRING]$iconFile = $NULL,
		[STRING]$title, [STRING]$description, [STRING]$company, [STRING]$product, [STRING]$copyright, [STRING]$trademark, [STRING]$version,
		[SWITCH]$configFile, [SWITCH]$noConfigFile, [SWITCH]$noOutput, [SWITCH]$noError, [SWITCH]$noVisualStyles, [SWITCH]$exitOnCancel,
		[SWITCH]$DPIAware, [SWITCH]$winFormsDPIAware, [SWITCH]$requireAdmin, [SWITCH]$supportOS, [SWITCH]$virtualize, [SWITCH]$longPaths)
	if (!(Get-Module -Name ps12exe -ListAvailable)) {
		Install-Module -Name ps12exe -Scope CurrentUser -Force
	}
	Import-Module -Name ps12exe
	ps12exe @PSBoundParameters
}

function Invoke-WinPS2EXE {
	if (!(Get-Module -Name ps12exe -ListAvailable)) {
		Install-Module -Name ps12exe -Scope CurrentUser -Force
	}
	Import-Module -Name ps12exe
	ps12exeGUI
}

Set-Alias ps2exe Invoke-ps2exe -Scope Global
Set-Alias ps2exe.ps1 Invoke-ps2exe -Scope Global
Set-Alias Win-PS2EXE Invoke-WinPS2EXE -Scope Global
Set-Alias Win-PS2EXE.exe Invoke-WinPS2EXE -Scope Global

Export-ModuleMember -Function @('Invoke-PS2EXE', 'Invoke-WinPS2EXE')
Export-ModuleMember -Alias @('ps2exe', 'ps2exe.ps1', 'Win-PS2EXE', 'Win-PS2EXE.exe')
