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
	[string]$ConfingFile,
	[string]$Localize,
	[ValidateSet('Light', 'Dark', 'Auto')]
	[string]$UIMode = 'Auto',
	[switch]$help
)

$Prarms = [hashtable]$PSBoundParameters

if ($help) {
	$LocalizeData = . $PSScriptRoot\src\LocaleLoader.ps1
	$MyHelp = $LocalizeData.GUIHelpData
	. $PSScriptRoot\src\HelpShower.ps1 -HelpData $MyHelp | Out-Host
	return
}

if (($PSVersionTable.PSEdition -eq "Core") -and (Get-Command powershell -ErrorAction Ignore)) {
	powershell -NoProfile -ExecutionPolicy Bypass -File $PSScriptRoot\src\GUI\Main.ps1 @Prarms | Out-Null
	return
}

.$PSScriptRoot\src\GUI\Main.ps1 @Prarms | Out-Null
