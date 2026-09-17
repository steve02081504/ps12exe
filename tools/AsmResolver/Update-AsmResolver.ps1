#Requires -Version 7.0
<#
.SYNOPSIS
	Downloads the latest AsmResolver and writes a size-trimmed copy into ps12exe's bin.
.DESCRIPTION
	ps12exe uses only a small part of AsmResolver. This script:
	  1. resolves the newest stable AsmResolver version on nuget.org,
	  2. downloads the netstandard2.0 assemblies (loadable from both Windows PowerShell 5.1
	     / .NET Framework and PowerShell 7 / .NET),
	  3. builds tools/AsmResolver (TinySharp + exe21sp + src/ExeSinker.ps1 usage) into a root
	     assembly,
	  4. runs the .NET IL Linker (illink) with that root so every AsmResolver member ps12exe
	     never reaches is dropped; all fields are preserved for the types that have literal
	     (const/enum) fields, because Add-Type inlines those values and would otherwise fail
	     to recompile the C# sources,
	  5. copies the result into src/bin/AsmResolver.
	The trimmed assemblies keep netstandard2.0 references, so they stay usable on both runtimes.
	Run the CI test scripts afterwards to verify the result.
.PARAMETER Version
	AsmResolver version to fetch. Defaults to the latest stable version.
.PARAMETER TargetFramework
	TFM used to build the root assembly. Defaults to the newest installed .NET reference pack.
.PARAMETER OutputDirectory
	Where the trimmed assemblies are written. Defaults to src/bin/AsmResolver.
.PARAMETER WorkDirectory
	Download/intermediate cache. Defaults to %TEMP%\ps12exe-asmresolver.
.PARAMETER Force
	Re-download and re-trim even when a cached copy exists.
.EXAMPLE
	./Update-AsmResolver.ps1
.EXAMPLE
	./Update-AsmResolver.ps1 -Version 6.0.1 -Force
#>
[CmdletBinding()]
param(
	[Parameter()][string]$Version,
	[Parameter()][string]$TargetFramework,
	[Parameter()][string]$OutputDirectory = (Join-Path $PSScriptRoot '..\..\src\bin\AsmResolver'),
	[Parameter()][string]$WorkDirectory = (Join-Path ([System.IO.Path]::GetTempPath()) 'ps12exe-asmresolver'),
	[Parameter()][switch]$Force
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

$PackageIds = @(
	'asmresolver'
	'asmresolver.dotnet'
	'asmresolver.pe'
	'asmresolver.pe.file'
	'asmresolver.pe.win32resources'
)
$AssemblyNames = @(
	'AsmResolver'
	'AsmResolver.DotNet'
	'AsmResolver.PE'
	'AsmResolver.PE.File'
	'AsmResolver.PE.Win32Resources'
)
$NetStandardLibraryVersion = '2.0.3'
$ProjectDir = $PSScriptRoot
$ProjectFile = Join-Path $ProjectDir 'AsmResolverTrimmer.csproj'

function Save-FileWithRetry {
	param([string]$Uri, [string]$OutFile, [int]$MaxAttempts = 8)
	for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
		try {
			Invoke-WebRequest -Uri $Uri -OutFile $OutFile
			return
		}
		catch {
			if ($attempt -eq $MaxAttempts) { throw }
			Write-Warning "Download failed ($attempt/$MaxAttempts), retrying: $Uri`n$($_.Exception.Message)"
			Start-Sleep -Seconds ([math]::Min($attempt * 2, 15))
		}
	}
}

function Get-LatestStableVersion {
	param([string]$PackageId)
	$index = Invoke-RestMethod -Uri "https://api.nuget.org/v3-flatcontainer/$PackageId/index.json"
	$stable = @($index.versions | Where-Object { $_ -notmatch '-' })
	if (-not $stable.Count) { throw "No stable version found for $PackageId" }
	return $stable[-1]
}

function Expand-PackageEntry {
	param([string]$PackagePath, [string]$Prefix, [string]$Destination)
	$archive = [System.IO.Compression.ZipFile]::OpenRead($PackagePath)
	try {
		$found = 0
		foreach ($entry in $archive.Entries) {
			if (-not $entry.Name) { continue }
			if (-not $entry.FullName.StartsWith($Prefix, [System.StringComparison]::Ordinal)) { continue }
			$target = Join-Path $Destination $entry.FullName.Substring($Prefix.Length)
			New-Item -ItemType Directory -Force -Path (Split-Path -Parent $target) | Out-Null
			[System.IO.Compression.ZipFileExtensions]::ExtractToFile($entry, $target, $true)
			$found++
		}
		if (-not $found) { throw "No entries under '$Prefix' in $PackagePath" }
	}
	finally { $archive.Dispose() }
}

function Get-AsmResolverLibDirectory {
	param([string]$Version, [string]$WorkDirectory, [switch]$Force)
	$libDir = Join-Path $WorkDirectory "$Version\lib\netstandard2.0"
	$packagesDir = Join-Path $WorkDirectory "$Version\packages"
	if (-not $Force -and (Test-Path -LiteralPath (Join-Path $libDir 'AsmResolver.DotNet.dll'))) { return $libDir }

	New-Item -ItemType Directory -Force -Path $packagesDir, $libDir | Out-Null
	foreach ($id in $PackageIds) {
		$nupkg = Join-Path $packagesDir "$id.$Version.nupkg"
		if ($Force -or -not (Test-Path -LiteralPath $nupkg)) {
			Write-Host "Downloading $id $Version"
			Save-FileWithRetry -Uri "https://api.nuget.org/v3-flatcontainer/$id/$Version/$id.$Version.nupkg" -OutFile $nupkg
		}
		Expand-PackageEntry -PackagePath $nupkg -Prefix 'lib/netstandard2.0/' -Destination $libDir
	}
	return $libDir
}

function Get-NetStandardRefDirectory {
	param([string]$WorkDirectory, [switch]$Force)
	$refDir = Join-Path $WorkDirectory "netstandard.library\$NetStandardLibraryVersion\ref"
	if (-not $Force -and (Test-Path -LiteralPath (Join-Path $refDir 'netstandard.dll'))) { return $refDir }

	$nupkg = Join-Path $WorkDirectory "netstandard.library.$NetStandardLibraryVersion.nupkg"
	if ($Force -or -not (Test-Path -LiteralPath $nupkg)) {
		Write-Host "Downloading NETStandard.Library $NetStandardLibraryVersion (reference assemblies)"
		Save-FileWithRetry -Uri "https://api.nuget.org/v3-flatcontainer/netstandard.library/$NetStandardLibraryVersion/netstandard.library.$NetStandardLibraryVersion.nupkg" -OutFile $nupkg
	}
	Expand-PackageEntry -PackagePath $nupkg -Prefix 'build/netstandard2.0/ref/' -Destination $refDir
	return $refDir
}

function Get-DefaultTargetFramework {
	$dotnet = (Get-Command dotnet).Source
	$packsRoot = Join-Path (Split-Path -Parent $dotnet) 'packs\Microsoft.NETCore.App.Ref'
	if (Test-Path -LiteralPath $packsRoot) {
		$versions = @(Get-ChildItem -LiteralPath $packsRoot -Directory |
			Where-Object { $_.Name -match '^\d+\.\d+\.\d+$' } |
			Sort-Object { [version]$_.Name } -Descending)
		if ($versions.Count) {
			$newest = [version]$versions[0].Name
			return "net$($newest.Major).$($newest.Minor)"
		}
	}
	return 'net8.0'
}

function Get-IllinkPath {
	param([string]$ProjectFile, [string]$TargetFramework)
	$output = & dotnet msbuild $ProjectFile -getProperty:ILLinkTasksAssembly -p:TargetFramework=$TargetFramework 2>&1 | Out-String
	$property = $null
	if ($output.TrimStart().StartsWith('{')) {
		$property = ($output.Substring($output.IndexOf('{')) | ConvertFrom-Json).Properties.ILLinkTasksAssembly
	}
	else {
		# Older/single-property msbuild prints the raw value; skip any restore noise lines.
		$property = @($output -split "`r?`n" | Where-Object { $_.Trim() -like '*.dll' })[-1]
	}
	if (-not $property) { throw "Microsoft.NET.ILLink.Tasks was not restored:`n$output" }
	$property = $property.Trim()
	$illink = Join-Path (Split-Path -Parent $property) 'illink.dll'
	if (-not (Test-Path -LiteralPath $illink)) { throw "illink.dll not found next to '$property'" }
	return $illink
}

function New-LinkerRootDescriptor {
	param([string[]]$Assemblies, [string]$DescriptorPath, [string]$MonoCecilPath)
	if (-not ('Mono.Cecil.AssemblyDefinition' -as [type])) {
		Add-Type -Path $MonoCecilPath
	}

	$builder = [System.Text.StringBuilder]::new()
	[void]$builder.AppendLine('<linker>')
	foreach ($path in $Assemblies) {
		$assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($path)
		try {
			$typeNames = [System.Collections.Generic.List[string]]::new()
			foreach ($module in $assembly.Modules) {
				$pending = [System.Collections.Generic.Stack[object]]::new()
				foreach ($type in $module.Types) { $pending.Push($type) }
				while ($pending.Count) {
					$type = $pending.Pop()
					foreach ($nested in $type.NestedTypes) { $pending.Push($nested) }
					foreach ($field in $type.Fields) {
						if ($field.HasConstant) { $typeNames.Add($type.FullName); break }
					}
				}
			}
			if ($typeNames.Count) {
				[void]$builder.AppendLine("  <assembly fullname=`"$([System.Security.SecurityElement]::Escape($assembly.Name.Name))`">")
				foreach ($name in $typeNames) {
					[void]$builder.AppendLine("    <type fullname=`"$([System.Security.SecurityElement]::Escape($name))`" preserve=`"fields`" />")
				}
				[void]$builder.AppendLine('  </assembly>')
			}
		}
		finally { $assembly.Dispose() }
	}
	[void]$builder.AppendLine('</linker>')
	Set-Content -LiteralPath $DescriptorPath -Value $builder.ToString() -Encoding utf8
}

if (-not $Version) {
	$Version = Get-LatestStableVersion -PackageId 'asmresolver'
	Write-Host "Latest stable AsmResolver: $Version"
}
if (-not $TargetFramework) {
	$TargetFramework = Get-DefaultTargetFramework
}
Write-Host "Root target framework: $TargetFramework"

$libDir = Get-AsmResolverLibDirectory -Version $Version -WorkDirectory $WorkDirectory -Force:$Force
$refDir = Get-NetStandardRefDirectory -WorkDirectory $WorkDirectory -Force:$Force

# Build the root assembly against the full AsmResolver. The build also restores
# Microsoft.NET.ILLink.Tasks (PublishTrimmed=true), which is then invoked directly below;
# publishing self-contained just to satisfy the trimmer is deliberately avoided.
Write-Host 'Building root assembly'
# Restore explicitly: the implicit restore of `dotnet build` does not always carry the
# TargetFramework override, which leaves a project.assets.json for the wrong framework.
& dotnet restore $ProjectFile -nologo -p:TargetFramework=$TargetFramework
if ($LASTEXITCODE) { throw "dotnet restore failed with exit code $LASTEXITCODE" }
& dotnet build $ProjectFile -c Release -nologo --no-restore -p:AsmResolverLibDir=$libDir -p:TargetFramework=$TargetFramework
if ($LASTEXITCODE) { throw "dotnet build failed with exit code $LASTEXITCODE" }
$rootDll = Join-Path $ProjectDir "bin\Release\$TargetFramework\AsmResolverRoot.dll"
if (-not (Test-Path -LiteralPath $rootDll)) { throw "Root assembly not found: $rootDll" }

$illink = Get-IllinkPath -ProjectFile $ProjectFile -TargetFramework $TargetFramework
$monoCecil = Join-Path (Split-Path -Parent $illink) 'Mono.Cecil.dll'

$descriptor = Join-Path $WorkDirectory "$Version\linker-roots.xml"
New-LinkerRootDescriptor -Assemblies (@($AssemblyNames | ForEach-Object { Join-Path $libDir "$_.dll" })) -DescriptorPath $descriptor -MonoCecilPath $monoCecil

$trimmedDir = Join-Path $WorkDirectory "$Version\trimmed"
Remove-Item -LiteralPath $trimmedDir -Recurse -Force -ErrorAction SilentlyContinue
Write-Host 'Trimming'
$illinkArgs = @(
	'-a', $rootDll
	'-d', $libDir
	'-d', $refDir
	'-x', $descriptor
	'--action', 'copy', '--trim-mode', 'copy'
	'--action', 'link', 'AsmResolver'
	'--action', 'link', 'AsmResolver.DotNet'
	'--action', 'link', 'AsmResolver.PE'
	'--action', 'link', 'AsmResolver.PE.File'
	'--action', 'link', 'AsmResolver.PE.Win32Resources'
	'-out', $trimmedDir
	'--singlewarn', 'true'
)
& dotnet exec $illink @illinkArgs
if ($LASTEXITCODE) { throw "illink failed with exit code $LASTEXITCODE" }

New-Item -ItemType Directory -Force -Path $OutputDirectory | Out-Null
$totalBefore = 0
$totalAfter = 0
foreach ($name in $AssemblyNames) {
	$source = Join-Path $trimmedDir "$name.dll"
	if (-not (Test-Path -LiteralPath $source)) { throw "Trimmed assembly missing: $source" }
	$before = (Get-Item -LiteralPath (Join-Path $libDir "$name.dll")).Length
	$after = (Get-Item -LiteralPath $source).Length
	$totalBefore += $before
	$totalAfter += $after
	Copy-Item -LiteralPath $source -Destination (Join-Path $OutputDirectory "$name.dll") -Force
}
Write-Host ("AsmResolver {0}: {1:N0} KB -> {2:N0} KB ({3:P0} smaller) written to {4}" -f `
	$Version, ($totalBefore / 1KB), ($totalAfter / 1KB), (1 - $totalAfter / $totalBefore), (Resolve-Path -LiteralPath $OutputDirectory).Path)
