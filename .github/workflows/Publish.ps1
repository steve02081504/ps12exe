#Requires -Version 7.0
[CmdletBinding()]
param(
	[Parameter(Mandatory)][string]$version,
	[Parameter(Mandatory)][string]$ApiKey
)
$ErrorActionPreference = 'Stop'
if ($version -notmatch '^v(\d+\.\d+\.\d+)$') { throw "invalid version: $version" }
$version = $Matches[1]
$repoPath = (Resolve-Path "$PSScriptRoot/../..").Path
$output = Join-Path ([IO.Path]::GetTempPath()) ('ps12exe-publish-' + [guid]::NewGuid().ToString('N'))
try {
	$nuget = (Get-Command nuget.exe -ErrorAction Stop).Source
	$package = & "$repoPath/tools/Packaging/New-Package.ps1" -RepoRoot $repoPath -Version $version -OutputDirectory $output
	# Upload the verified package; Publish-Module would repack it.
	& $nuget push $package -Source 'https://www.powershellgallery.com/api/v2/package' -NonInteractive -ApiKey $ApiKey
	if ($LASTEXITCODE) { throw "NuGet push failed: $LASTEXITCODE" }
} finally {
	if ((Split-Path $output) -ne [IO.Path]::GetTempPath().TrimEnd('\', '/')) { throw "Unexpected temporary path: $output" }
	if (Test-Path -LiteralPath $output) { Remove-Item -LiteralPath $output -Recurse -Force }
}
Write-Output 'Nice CI!'
