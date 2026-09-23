[CmdletBinding()]
param(
	[Parameter(Mandatory = $true)]
	[string]$InputFile,

	[Parameter(Mandatory = $true)]
	[string]$OutputFile,

	[string]$ModulePath,

	[string]$Locale,

	[switch]$Sandbox
)

$ErrorActionPreference = 'Stop'

if ($ModulePath) {
	Import-Module -Name $ModulePath -ErrorAction Stop
}
else {
	Import-Module -Name ps12exe -ErrorAction Stop
}

$compileParams = @{
	outputFile    = $OutputFile
	Sandbox       = [bool]$Sandbox
	NoUpdateCheck = $true
	ErrorAction   = 'Stop'
}
if ($Locale) {
	$compileParams.Locale = $Locale
}

Get-Content -LiteralPath $InputFile -Raw -Encoding UTF8 | ps12exe @compileParams

if (-not (Test-Path -LiteralPath $OutputFile)) {
	throw 'ps12exe did not produce the expected output file.'
}
