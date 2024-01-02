[CmdletBinding()]
param(
	[string]$ConfingFile,
	[string]$Localize,
	[ValidateSet('Light', 'Dark', 'Auto')]
	[string]$UIMode = 'Auto'
)

$Prarms = [hashtable]$PSBoundParameters

if (!$Localize) {
	# 本机语言
	$Prarms.Localize = (Get-Culture).Name
}

if (($PSVersionTable.PSEdition -eq "Core") -and (Get-Command powershell -ErrorAction Ignore)) {
	powershell -NoProfile -ExecutionPolicy Bypass -File $PSScriptRoot\src\GUI\Main.ps1 @Prarms | Out-Null
	return
}

.$PSScriptRoot\src\GUI\Main.ps1 @Prarms | Out-Null
