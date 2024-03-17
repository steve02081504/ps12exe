#Requires -Version 5.0

<#
.SYNOPSIS
ps12exeGUI is a GUI tool for ps12exe.
.DESCRIPTION
ps12exeGUI is a GUI tool for ps12exe.
.PARAMETER ConfingFile
The path of the configuration file.
.PARAMETER Localize
The language code to use.
.PARAMETER UIMode
The UI mode to use.
.PARAMETER help
Show this help message.
.EXAMPLE
ps12exeGUI -Localize 'en-UK' -UIMode 'Light'
.EXAMPLE
ps12exeGUI -ConfingFile 'ps12exe.json' -Localize 'en-UK' -UIMode 'Dark'
.EXAMPLE
ps12exeGUI -help
#>
[CmdletBinding()]
param(
	[ValidatePattern('|.(psccfg|xml)$')]
	[string]$ConfingFile,
	[ArgumentCompleter({
		Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
		. "$PSScriptRoot\..\LocaleArgCompleter.ps1" @PSBoundParameters
	})]
	[string]$Localize,
	[ValidateSet('Light', 'Dark', 'Auto')]
	[string]$UIMode = 'Auto',
	[ValidatePattern('|.ps1$')]
	[string]$PS1File,
	[switch]$help
)

if ($help) {
	$LocalizeData = . $PSScriptRoot\..\LocaleLoader.ps1 -Localize $Localize
	$MyHelp = $LocalizeData.GUIHelpData
	. $PSScriptRoot\..\HelpShower.ps1 -HelpData $MyHelp | Out-Host
	return
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
		param ($ScriptRoot, $ConfingFile, $Localize, $UIMode, $PS1File, $help)
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
