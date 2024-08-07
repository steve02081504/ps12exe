#Requires -Version 5.0

<#
.SYNOPSIS
ps12exeGUI is a GUI tool for ps12exe.
.DESCRIPTION
ps12exeGUI is a GUI tool for ps12exe.
.PARAMETER ConfigFile
The path of the configuration file.
.PARAMETER PS1File
The path of the script file.
.PARAMETER Localize
The language code to use.
.PARAMETER UIMode
The UI mode to use.
.PARAMETER help
Show this help message.
.EXAMPLE
ps12exeGUI -Localize 'en-UK' -UIMode 'Light'
.EXAMPLE
ps12exeGUI -ConfigFile 'proj.psccfg' -Localize 'en-UK' -UIMode 'Dark'
.EXAMPLE
ps12exeGUI -help
#>
[CmdletBinding(DefaultParameterSetName = 'ConfigOrPS1File')]
param(
	[Parameter(DontShow, ParameterSetName = 'ConfigOrPS1File', Position = 0)]
	[ValidatePattern('^.*\.(psccfg|xml|ps1)$')]
	[string]$ConfigOrPS1File,
	[Parameter(Mandatory, ParameterSetName = 'ConfigFile', Position = 0)]
	[ValidatePattern('^.*\.(psccfg|xml)$')]
	[string]$ConfigFile,
	[Parameter(ParameterSetName = 'ConfigFile')]
	[Parameter(Mandatory, ParameterSetName = 'Ps1File', Position = 0)]
	[ValidatePattern('^.*\.ps1$')]
	[string]$PS1File,
	#_if PSScript
		[ArgumentCompleter({
			Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
			. "$PSScriptRoot\..\LocaleArgCompleter.ps1" @PSBoundParameters
		})]
	#_endif
	[string]$Localize,
	[ValidateSet('Light', 'Dark', 'Auto')]
	[string]$UIMode = 'Auto',
	[switch]$help
)

#_if PSScript
if ($help) {
	$LocalizeData = . $PSScriptRoot\..\LocaleLoader.ps1 -Localize $Localize
	$MyHelp = $LocalizeData.GUIHelpData
	. $PSScriptRoot\..\HelpShower.ps1 -HelpData $MyHelp | Write-Host
	return
}

if ($ConfigOrPS1File) {
	if ($ConfigOrPS1File -match '\.ps1$') {
		$PSBoundParameters.PS1File = $ConfigOrPS1File
	}
	else {
		$PSBoundParameters.ConfigFile = $ConfigOrPS1File
	}
	$PSBoundParameters.Remove('ConfigOrPS1File') | Out-Null
}

try {
	# Set Console Window Title
	$BackUpTitle = $Host.UI.RawUI.WindowTitle
	$Host.UI.RawUI.WindowTitle = "ps12exe GUI Console Host"

	# Initialize STA Runspace
	$Runspace = [RunspaceFactory]::CreateRunspace()
	$Runspace.ApartmentState = 'STA'
	$Runspace.ThreadOptions = 'ReuseThread'
	$Runspace.Open()

	# Execute
	$pwsh = [PowerShell]::Create().AddScript({
		param ($ScriptRoot, $ConfigFile, $Localize, $UIMode, $PS1File, $help)
		. "$ScriptRoot\GUIMainScript.ps1"
	}).AddParameter('ScriptRoot', $PSScriptRoot)

	foreach ($param in $PSBoundParameters.Keys) {
		$pwsh = $pwsh.AddParameter($param, $PSBoundParameters[$param])
	}

	$pwsh.RunSpace = $Runspace
	$pwsh.Invoke()
}
finally {
	# Dispose
	$Runspace.Close()
	$Runspace.Dispose()
	$pwsh.Dispose()

	# Restore Console Window Title
	$Host.UI.RawUI.WindowTitle = $BackUpTitle
}
#_else
#_require ps12exe
#_pragma Console 0
#_pragma iconFile $PSScriptRoot/../../img/icon.ico
#_pragma title ps12exeGUI
#_pragma description 'A super cool GUI for compile powershell scripts'
#_!!if (!(Test-Path -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Classes\ps12exeGUI.psccfg")){
#_!!	Set-ps12exeContextMenu 1
#_!!}
#_!!ps12exeGUI @PSBoundParameters
#_endif
