#Requires -Version 7.0
<#
.SYNOPSIS
Build the Gallery nupkg locally, then recompress it with maximum ZIP Deflate settings.
#>
[CmdletBinding()]
param(
	[string]$RepoRoot = (Resolve-Path "$PSScriptRoot/../..").Path,
	[Parameter(Mandatory)][string]$OutputDirectory,
	[string]$Version = (Import-PowerShellDataFile "$RepoRoot/ps12exe.psd1").ModuleVersion,
	[string]$SevenZip = '7z.exe'
)
$ErrorActionPreference = 'Stop'
$RepoRoot = (Resolve-Path -LiteralPath $RepoRoot).Path
$SevenZip = (Get-Command $SevenZip -ErrorAction Stop).Source
$work = Join-Path ([IO.Path]::GetTempPath()) ('ps12exe-package-' + [guid]::NewGuid().ToString('N'))
$stage = Join-Path $work 'ps12exe'
$packages = Join-Path $work 'packages'
New-Item -ItemType Directory -Path $stage, $packages -Force | Out-Null
try {
	# Same release exclusions as Publish.ps1, without deleting the checkout.
	$excluded = @('docs', 'tools', 'tests', 'AGENTS.md', 'eslint.config.mjs', 'typos.toml')
	$tracked = & git -C $RepoRoot -c core.quotepath=false ls-files
	if ($LASTEXITCODE) { throw 'Cannot enumerate release files with git ls-files.' }
	$tracked | Where-Object {
		$relative = $_
		$relative -notmatch '(^|/)\.' -and ($relative.Split('/')[0] -notin $excluded) -and
		$relative -ne 'src/locale/reorder_locale.ps1'
	} | ForEach-Object {
		$relative = $_
		$target = Join-Path $stage $relative
		New-Item -ItemType Directory -Path (Split-Path $target) -Force | Out-Null
		Copy-Item -LiteralPath (Join-Path $RepoRoot $relative) -Destination $target
	}
	. "$RepoRoot/src/PSObjectToString.ps1"
	$manifest = Import-PowerShellDataFile "$stage/ps12exe.psd1"
	$manifest.ModuleVersion = $Version
	[IO.File]::WriteAllText("$stage/ps12exe.psd1", (PSObjectToString $manifest), [Text.UTF8Encoding]::new($true))
	# PowerShellGet's NuGet pack path works reliably in Windows PowerShell 5.1.
	$packScript = @'
param($stage, $packages)
$ErrorActionPreference = 'Stop'
$name = 'ps12exe-pack-' + [guid]::NewGuid().ToString('N')
try {
    Register-PSRepository -Name $name -SourceLocation $packages -PublishLocation $packages -InstallationPolicy Trusted
    Publish-Module -Path $stage -Repository $name -ErrorAction Stop
} finally { Unregister-PSRepository -Name $name -ErrorAction SilentlyContinue }
'@
	$packPath = Join-Path $work 'pack.ps1'
	[IO.File]::WriteAllText($packPath, $packScript, [Text.UTF8Encoding]::new($true))
	& powershell.exe -NoProfile -NonInteractive -File $packPath $stage $packages | Out-Host
	if ($LASTEXITCODE) { throw "Publish-Module failed: $LASTEXITCODE" }
	$original = @(Get-ChildItem -LiteralPath $packages -Filter '*.nupkg')
	if ($original.Count -ne 1) { throw 'Expected exactly one nupkg.' }
	$expanded = Join-Path $work 'expanded'
	[IO.Compression.ZipFile]::ExtractToDirectory($original[0].FullName, $expanded)
	$archive = [IO.Compression.ZipFile]::OpenRead($original[0].FullName)
	try {
		# Only file entries: avoid adding ZIP directory records and timestamp extras.
		$list = Join-Path $work 'files.txt'
		[IO.File]::WriteAllLines($list, [string[]]$archive.Entries.FullName, [Text.UTF8Encoding]::new($false))
		$optimized = Join-Path $work $original[0].Name
		Push-Location $expanded
		try {
			# Deflate is the interoperable nupkg method; 258 fast bytes and 15 passes are its maxima.
			& $SevenZip a -tzip $optimized "@$list" -scsUTF-8 -mm=Deflate -mx=9 -mfb=258 -mpass=15 -mtc=off -mta=off -mcu=off | Out-Host
			if ($LASTEXITCODE) { throw "7-Zip failed: $LASTEXITCODE" }
		}
		finally { Pop-Location }
		$check = [IO.Compression.ZipFile]::OpenRead($optimized)
		try {
			if ($check.Entries.Count -ne $archive.Entries.Count) { throw 'Recompression changed the entry count.' }
			foreach ($entry in $archive.Entries) {
				$other = $check.GetEntry($entry.FullName)
				if (-not $other -or $other.Length -ne $entry.Length) { throw "Recompression changed $($entry.FullName)." }
				$left = $entry.Open(); $right = $other.Open()
				try {
					$sha = [Security.Cryptography.SHA256]::Create()
					try {
						if ([Convert]::ToBase64String($sha.ComputeHash($left)) -ne [Convert]::ToBase64String($sha.ComputeHash($right))) {
							throw "Recompression changed content: $($entry.FullName)."
						}
					}
					finally { $sha.Dispose() }
				}
				finally { $left.Dispose(); $right.Dispose() }
			}
		}
		finally { $check.Dispose() }
	}
	finally { $archive.Dispose() }
	if ((Get-Item $optimized).Length -gt $original[0].Length) { throw 'Maximum compression produced a larger package.' }
	New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
	$result = Join-Path (Resolve-Path -LiteralPath $OutputDirectory).Path $original[0].Name
	Copy-Item -LiteralPath $optimized -Destination $result -Force
	Write-Host ("nupkg: {0:N0} -> {1:N0} bytes" -f $original[0].Length, (Get-Item $result).Length)
	$result
}
finally {
	# $work is an absolute, unique directory created under the OS temp directory above.
	if ((Split-Path $work) -ne [IO.Path]::GetTempPath().TrimEnd('\', '/')) { throw "Unexpected temporary path: $work" }
	Remove-Item -LiteralPath $work -Recurse -Force
}
