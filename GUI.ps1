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
	[ValidatePattern('.(psccfg|xml)$')]
	[string]$ConfingFile,
	[string]$Localize,
	[ValidateSet('Light', 'Dark', 'Auto')]
	[string]$UIMode = 'Auto',
	[ValidatePattern('.ps1$')]
	[string]$PS1File,
	[switch]$help
)

if ($help) {
	$LocalizeData = . $PSScriptRoot\src\LocaleLoader.ps1 -Localize $Localize
	$MyHelp = $LocalizeData.GUIHelpData
	. $PSScriptRoot\src\HelpShower.ps1 -HelpData $MyHelp | Out-Host
	return
}

. $PSScriptRoot\src\GUI\Main.ps1 @PSBoundParameters
