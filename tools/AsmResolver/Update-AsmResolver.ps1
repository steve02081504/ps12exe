#Requires -Version 7.0
<#
.SYNOPSIS
	下载最新的 AsmResolver，并把经过体积裁剪的副本写入 ps12exe 的 bin。
.DESCRIPTION
	ps12exe 只用到 AsmResolver 的一小部分。本脚本：
	  1. 在 nuget.org 上解析最新的稳定版 AsmResolver，
	  2. 下载 netstandard2.0 程序集（可从 Windows PowerShell 5.1 / .NET Framework 和 PowerShell 7 / .NET 两种运行时加载），
	  3. 把 tools/AsmResolver（TinySharp + exe21sp + src/ExeSinker.ps1 用法）构建成一个根程序集，
	  4. 用该根对 .NET IL Linker（illink）运行，使 ps12exe 永不触达的每个 AsmResolver 成员都被丢弃；对具有字面量（const/enum）字段的类型会保留所有字段，因为 Add-Type 会内联这些值，否则将无法重新编译 C# 源码，
	  5. 把结果复制到 src/bin/AsmResolver。
	裁剪后的程序集保留 netstandard2.0 引用，因此在两种运行时上都可用。之后请运行 CI 测试脚本验证结果。
.PARAMETER Version
	要获取的 AsmResolver 版本。默认为最新稳定版。
.PARAMETER TargetFramework
	用于构建根程序集的 TFM。默认为最新安装的 .NET 引用包。
.PARAMETER OutputDirectory
	裁剪后程序集的写入位置。默认为 src/bin/AsmResolver。
.PARAMETER WorkDirectory
	下载/中间缓存。默认为 %TEMP%\ps12exe-asmresolver。
.PARAMETER Force
	即使存在缓存副本也重新下载并重新裁剪。
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
		# 旧版/单属性 msbuild 会打印原始值；跳过任何 restore 噪音行。
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

# 针对完整的 AsmResolver 构建根程序集。构建过程还会还原 Microsoft.NET.ILLink.Tasks（PublishTrimmed=true），随后在下方直接调用它；刻意避免仅为满足裁剪器而进行自包含发布。
Write-Host 'Building root assembly'
# 显式还原：`dotnet build` 的隐式还原并不总能带上 TargetFramework 覆盖，这会遗留一个面向错误框架的 project.assets.json。
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
