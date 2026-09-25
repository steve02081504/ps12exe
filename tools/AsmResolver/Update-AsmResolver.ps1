#Requires -Version 7.0
<#
.SYNOPSIS
	获取 AsmResolver（NuGet 稳定版 / GitHub CI 构建产物 / 指定 PR 的构建产物 / 从源码构建），并把经过体积裁剪的副本写入 ps12exe 的 bin。
.DESCRIPTION
	ps12exe 只用到 AsmResolver 的一小部分。本脚本：
	  1. 按 -Source 解析一份完整的 AsmResolver：
	       NuGet ：nuget.org 上最新的稳定版（或 -Version 指定版本）；
	       Ci    ：GitHub Actions 上 -Ref 分支（默认 master）最近一次成功运行的 build-artifacts 产物；
	       Pr    ：指定 PR（-Pr）对应提交的 build-artifacts 产物；
	       Source：用 git 取 -Ref / PR head 的源码，本地 dotnet build 出 netstandard2.0 程序集。
	     Ci/Pr 在产物缺失或已过期时自动回退到 Source。
	  2. 取出 netstandard2.0 程序集（可从 Windows PowerShell 5.1 / .NET Framework 和 PowerShell 7 / .NET 两种运行时加载），
	  3. 把 tools/AsmResolver（TinySharp + exe21sp + src/ExeSinker.ps1 + src/DllExportCompiler.ps1 用法）构建成一个根程序集，
	  4. 用该根对 .NET IL Linker（illink）运行，使 ps12exe 永不触达的每个 AsmResolver 成员都被丢弃；对具有字面量（const/enum）字段的类型会保留所有字段，因为 Add-Type 会内联这些值，否则将无法重新编译 C# 源码，
	  5. 用 ILRepack 把裁剪后的 5 个程序集合并成单个 AsmResolver.dll（省掉 4 份程序集清单/元数据表/重定位；原始字节 860 KB→763 KB，压缩后 nupkg 约小 30 KB），
	  6. 把单个 AsmResolver.dll 复制到 src/bin（不再单独建子目录）。
	合并与裁剪产物都保留 netstandard2.0 引用，因此在两种运行时上都可用。之后请运行 CI 测试脚本验证结果。
.PARAMETER Source
	AsmResolver 的来源：NuGet（默认）、Ci、Pr 或 Source。Ci/Pr 依赖已安装并登录的 gh CLI；Source 依赖 git 与 dotnet。
.PARAMETER Version
	NuGet 来源下要获取的 AsmResolver 版本。默认为最新稳定版。
.PARAMETER Pr
	-source Pr（或 -Source Source 配合）时使用的 PR 编号。
.PARAMETER Ref
	-source Ci 时的分支名（默认 master）；-source Source 时要构建的 git ref（分支/tag/提交）。
.PARAMETER RunId
	直接指定 GitHub Actions 的 run id（覆盖按分支/PR 的自动查找）。
.PARAMETER Repo
	CI/PR/源码来源所用的仓库。默认为 Washi1337/AsmResolver。
.PARAMETER ArtifactName
	CI/PR 来源下载的构建产物名。默认为 build-artifacts。
.PARAMETER TargetFramework
	用于构建根程序集的 TFM。默认为最新安装的 .NET 引用包。
.PARAMETER OutputDirectory
	合并后程序集（单个 AsmResolver.dll）的写入位置。默认为 src/bin。
.PARAMETER WorkDirectory
	下载/中间缓存。默认为 %TEMP%\ps12exe-asmresolver。
.PARAMETER Force
	即使存在缓存副本也重新下载/构建并重新裁剪。
.EXAMPLE
	./Update-AsmResolver.ps1
.EXAMPLE
	./Update-AsmResolver.ps1 -Version 6.0.1 -Force
.EXAMPLE
	./Update-AsmResolver.ps1 -Source Ci -Ref development
.EXAMPLE
	./Update-AsmResolver.ps1 -Source Pr -Pr 793
.EXAMPLE
	./Update-AsmResolver.ps1 -Source Source -Ref master
#>
[CmdletBinding()]
param(
	[Parameter()][ValidateSet('NuGet', 'Ci', 'Pr', 'Source')][string]$Source = 'NuGet',
	[Parameter()][string]$Version,
	[Parameter()][int]$Pr,
	[Parameter()][string]$Ref,
	[Parameter()][long]$RunId,
	[Parameter()][string]$Repo = 'Washi1337/AsmResolver',
	[Parameter()][string]$ArtifactName = 'build-artifacts',
	[Parameter()][string]$TargetFramework,
	[Parameter()][string]$OutputDirectory = (Join-Path $PSScriptRoot '..\..\src\bin'),
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
# 从源码构建时，构建这两个工程即可（其项目引用链会带出其余三个程序集）。
$SourceProjects = @(
	'src/AsmResolver.DotNet/AsmResolver.DotNet.csproj'
	'src/AsmResolver.PE.Win32Resources/AsmResolver.PE.Win32Resources.csproj'
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

# 调用外部命令，遇到网络类瞬时错误（TLS handshake timeout / EOF）反复重试。
function Invoke-CommandWithRetry {
	param([string]$Command, [string[]]$Arguments, [int]$MaxAttempts = 8)
	for ($attempt = 1; $attempt -le $MaxAttempts; $attempt++) {
		try {
			$output = & $Command @Arguments 2>&1
			if ($LASTEXITCODE -ne 0) { throw (($output | Out-String).Trim()) }
			return (($output | Out-String).Trim())
		}
		catch {
			if ($attempt -eq $MaxAttempts) { throw }
			Write-Warning "$Command failed ($attempt/$MaxAttempts), retrying: $Command $($Arguments -join ' ')`n$($_.Exception.Message)"
			Start-Sleep -Seconds ([math]::Min($attempt * 3, 20))
		}
	}
}

function Invoke-Gh {
	param([string[]]$Arguments, [int]$MaxAttempts = 8)
	return Invoke-CommandWithRetry -Command 'gh' -Arguments $Arguments -MaxAttempts $MaxAttempts
}

function Invoke-Git {
	param([string[]]$Arguments, [int]$MaxAttempts = 5)
	return Invoke-CommandWithRetry -Command 'git' -Arguments $Arguments -MaxAttempts $MaxAttempts
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

# 解析目标 CI run（-RunId 优先，其次按 PR head 提交 / 分支查找最近一次成功运行）。
function Resolve-CiRun {
	param([string]$Repo, [string]$Ref, [int]$Pr, [long]$RunId)
	if ($RunId) {
		return (Invoke-Gh -Arguments @('run', 'view', "$RunId", '--repo', $Repo, '--json', 'databaseId,headSha,headBranch,conclusion') | ConvertFrom-Json)
	}

	if ($Pr) {
		$sha = Invoke-Gh -Arguments @('api', "repos/$Repo/pulls/$Pr", '--jq', '.head.sha')
		$runs = @(Invoke-Gh -Arguments @('run', 'list', '--repo', $Repo, '--commit', $sha, '--limit', '1', '--json', 'databaseId,headSha,headBranch,conclusion') | ConvertFrom-Json)
		if (-not $runs.Count) { throw "No GitHub Actions run found for PR #$Pr ($sha) in $Repo. Pass -RunId to target a specific run." }
	}
	else {
		$runs = @(Invoke-Gh -Arguments @('run', 'list', '--repo', $Repo, '--workflow', 'test-and-publish.yml', '--branch', $Ref, '--status', 'success', '--limit', '1', '--json', 'databaseId,headSha,headBranch,conclusion') | ConvertFrom-Json)
		if (-not $runs.Count) { throw "No GitHub Actions run found for branch '$Ref' in $Repo. Pass -RunId to target a specific run." }
	}

	return $runs[0]
}

function Get-CommitSha {
	param([string]$Repo, [string]$Ref, [int]$Pr)
	if ($Pr) { return (Invoke-Gh -Arguments @('api', "repos/$Repo/pulls/$Pr", '--jq', '.head.sha')) }
	$ls = Invoke-Git -Arguments @('ls-remote', "https://github.com/$Repo.git", $Ref)
	if (-not $ls) { throw "Could not resolve ref '$Ref' in $Repo." }
	return ($ls -split "\s+")[0]
}

# 下载 CI run 的构建产物（内含各包 nupkg），解出 netstandard2.0 程序集。
function Get-CiAsmResolverLibDirectory {
	param([string]$Repo, [string]$ArtifactName, [long]$RunId, [string]$CacheKey, [string]$WorkDirectory, [switch]$Force)
	$libDir = Join-Path $WorkDirectory "$CacheKey\lib\netstandard2.0"
	if (-not $Force -and (Test-Path -LiteralPath (Join-Path $libDir 'AsmResolver.DotNet.dll'))) { return $libDir }

	# 预检产物是否存在/过期：产物保留 7 天，过期或缺失时给出可操作的错误而不是让 gh 反复重试。
	$expired = Invoke-Gh -Arguments @('api', "repos/$Repo/actions/runs/$RunId/artifacts", '--jq', ".artifacts[] | select(.name==`"$ArtifactName`") | .expired")
	if (-not $expired) { throw "Run $RunId has no artifact named '$ArtifactName'." }
	if ($expired -eq 'true') { throw "Artifact '$ArtifactName' of run $RunId has expired (GitHub keeps artifacts for 7 days)." }

	$downloadDir = Join-Path $WorkDirectory "$CacheKey\artifact"
	Remove-Item -LiteralPath $downloadDir -Recurse -Force -ErrorAction Ignore
	New-Item -ItemType Directory -Force -Path $downloadDir, $libDir | Out-Null

	Write-Host "Downloading CI artifact '$ArtifactName' from run $RunId"
	Invoke-Gh -Arguments @('run', 'download', "$RunId", '--repo', $Repo, '--name', $ArtifactName, '--dir', $downloadDir) | Out-Null

	$packages = @(Get-ChildItem -LiteralPath $downloadDir -Recurse -File -Filter *.nupkg)
	if (-not $packages.Count) { throw "No .nupkg found in artifact '$ArtifactName' of run $RunId." }

	foreach ($package in $packages) {
		try { Expand-PackageEntry -PackagePath $package.FullName -Prefix 'lib/netstandard2.0/' -Destination $libDir }
		catch { Write-Verbose "Skipping $($package.Name): $($_.Exception.Message)" }
	}
	if (-not (Test-Path -LiteralPath (Join-Path $libDir 'AsmResolver.DotNet.dll'))) {
		throw "No netstandard2.0 assemblies found in artifact '$ArtifactName' of run $RunId."
	}
	return $libDir
}

# 用 git 取指定 ref（或 PR head）的源码，本地构建 netstandard2.0 程序集。
function Get-SourceAsmResolverLibDirectory {
	param([string]$Repo, [string]$Ref, [int]$Pr, [string]$CacheKey, [string]$WorkDirectory, [switch]$Force)
	$libDir = Join-Path $WorkDirectory "$CacheKey\lib\netstandard2.0"
	if (-not $Force -and (Test-Path -LiteralPath (Join-Path $libDir 'AsmResolver.DotNet.dll'))) { return $libDir }

	$repoUrl = "https://github.com/$Repo.git"
	$srcDir = Join-Path $WorkDirectory "$CacheKey\src"
	Remove-Item -LiteralPath $srcDir -Recurse -Force -ErrorAction Ignore
	New-Item -ItemType Directory -Force -Path $libDir | Out-Null

	if ($Pr) {
		Write-Host "Cloning $Repo at PR #$Pr head"
		Invoke-Git -Arguments @('clone', '--no-tags', '--filter=blob:none', $repoUrl, $srcDir) | Out-Null
		Invoke-Git -Arguments @('-C', $srcDir, 'fetch', '--depth', '1', 'origin', "refs/pull/$Pr/head") | Out-Null
		Invoke-Git -Arguments @('-C', $srcDir, 'checkout', '--detach', 'FETCH_HEAD') | Out-Null
	}
	else {
		Write-Host "Cloning $Repo at '$Ref'"
		Invoke-Git -Arguments @('clone', '--depth', '1', '--no-tags', '--branch', $Ref, $repoUrl, $srcDir) | Out-Null
	}

	Write-Host 'Building AsmResolver from source (netstandard2.0)'
	foreach ($project in $SourceProjects) {
		$buildOutput = & dotnet build (Join-Path $srcDir $project) -c Release -f netstandard2.0 -nologo `
			-p:CheckEolTargetFramework=false -p:NuGetAudit=false 2>&1 | Out-String
		if ($LASTEXITCODE) { throw "dotnet build failed for $project with exit code $LASTEXITCODE`n$buildOutput" }
		Write-Verbose $buildOutput
	}

	foreach ($name in $AssemblyNames) {
		$projectBin = Join-Path $srcDir "artifacts/src/bin/$name"
		$dll = Get-ChildItem -LiteralPath $projectBin -Recurse -File -Filter "$name.dll" -ErrorAction Ignore |
			Where-Object { $_.DirectoryName -match 'netstandard2\.0' } | Select-Object -First 1
		if (-not $dll) { throw "netstandard2.0 build output not found for $name under $projectBin" }
		Copy-Item -LiteralPath $dll.FullName -Destination (Join-Path $libDir "$name.dll") -Force
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

# 安装（必要时）ILRepack 到工作目录下的私有 tool-path，返回 exe 路径。
# ILRepack 把裁剪后的 5 个程序集合并成单个 AsmResolver.dll：省掉 4 份程序集清单 / 元数据表 / 重定位，
# 原始字节 860 KB→763 KB、压缩后 nupkg 约小 30 KB（4.5%）。合并后类型仍在同一程序集，
# AsmResolver 自身用 internal 跨程序集调用的部分不受影响；产物仍是 netstandard2.0，PS 5.1 与 PS 7 都能加载。
function Get-ILRepackPath {
	param([string]$WorkDirectory)
	$toolDir = Join-Path $WorkDirectory 'tools\ilrepack'
	$exe = Join-Path $toolDir 'ilrepack.exe'
	if (Test-Path -LiteralPath $exe) { return $exe }
	New-Item -ItemType Directory -Force -Path $toolDir | Out-Null
	Write-Host 'Installing ILRepack (dotnet tool)'
	& dotnet tool install --tool-path $toolDir dotnet-ilrepack --version 2.0.48
	if ($LASTEXITCODE) { throw "dotnet tool install dotnet-ilrepack failed with exit code $LASTEXITCODE" }
	if (-not (Test-Path -LiteralPath $exe)) { throw "ILRepack not found after install: $exe" }
	return $exe
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

# ---- 解析来源 ----
$CiRun = $null
if ($Source -eq 'NuGet') {
	if (-not $Version) {
		$Version = Get-LatestStableVersion -PackageId 'asmresolver'
	}
	$cacheKey = $Version
	Write-Host "Source: NuGet $Version"
}
elseif ($Source -eq 'Source') {
	if (-not (Get-Command git -ErrorAction Ignore)) { throw '-Source Source requires git on PATH.' }
	if (-not $Pr -and -not $Ref) { $Ref = 'master' }
	$sha = Get-CommitSha -Repo $Repo -Ref $Ref -Pr $Pr
	if ($sha.Length -gt 8) { $sha = $sha.Substring(0, 8) }
	$cacheKey = if ($Pr) { "src-pr-$Pr-$sha" } else { "src-$Ref-$sha" }
	Write-Host "Source: git $Repo ($(if ($Pr) { "PR #$Pr" } else { $Ref }) @ $sha)"
}
else {
	if ($Source -eq 'Pr' -and -not $Pr) { throw "-Source Pr requires -Pr <number>." }
	if ($Source -eq 'Ci' -and -not $Ref) { $Ref = 'master' }
	if (-not (Get-Command gh -ErrorAction Ignore)) { throw "-Source $Source requires the gh CLI on PATH." }

	$CiRun = Resolve-CiRun -Repo $Repo -Ref $Ref -Pr $Pr -RunId $RunId
	$sha = "$($CiRun.headSha)"
	if ($sha.Length -gt 8) { $sha = $sha.Substring(0, 8) }
	$cacheKey = if ($Source -eq 'Pr') { "pr-$Pr-$sha" } else { "ci-$($CiRun.headBranch)-$sha" }
	Write-Host "Source: GitHub Actions run $($CiRun.databaseId) ($($CiRun.headBranch) @ $sha, $($CiRun.conclusion))"
}

if (-not $TargetFramework) {
	$TargetFramework = Get-DefaultTargetFramework
}
Write-Host "Root target framework: $TargetFramework"

$libDir = if ($Source -eq 'NuGet') {
	Get-AsmResolverLibDirectory -Version $Version -WorkDirectory $WorkDirectory -Force:$Force
}
elseif ($Source -eq 'Source') {
	Get-SourceAsmResolverLibDirectory -Repo $Repo -Ref $Ref -Pr $Pr -CacheKey $cacheKey -WorkDirectory $WorkDirectory -Force:$Force
}
else {
	try {
		Get-CiAsmResolverLibDirectory -Repo $Repo -ArtifactName $ArtifactName -RunId $CiRun.databaseId -CacheKey $cacheKey -WorkDirectory $WorkDirectory -Force:$Force
	}
	catch {
		Write-Warning "Could not use CI artifact: $($_.Exception.Message)"
		Write-Warning 'Falling back to building AsmResolver from source.'
		$fallbackPr = if ($Source -eq 'Pr') { $Pr } else { 0 }
		$fallbackRef = if ($fallbackPr) { $null } else { $Ref }
		$fallbackKey = if ($fallbackPr) { "src-pr-$fallbackPr-$sha" } else { "src-$fallbackRef-$sha" }
		Get-SourceAsmResolverLibDirectory -Repo $Repo -Ref $fallbackRef -Pr $fallbackPr -CacheKey $fallbackKey -WorkDirectory $WorkDirectory -Force:$Force
	}
}
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

$trimRoot = Join-Path $WorkDirectory $cacheKey
New-Item -ItemType Directory -Force -Path $trimRoot | Out-Null
$descriptor = Join-Path $trimRoot 'linker-roots.xml'
New-LinkerRootDescriptor -Assemblies (@($AssemblyNames | ForEach-Object { Join-Path $libDir "$_.dll" })) -DescriptorPath $descriptor -MonoCecilPath $monoCecil

$trimmedDir = Join-Path $trimRoot 'trimmed'
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

# 合并：把裁剪后的 5 个程序集用 ILRepack 合成单个 AsmResolver.dll，直接写到 src/bin 下
# （不再单独建子目录）。ps12exe 的加载点都是 `Get-ChildItem bin -Filter *.dll`，合并成一个文件后照常工作。
Write-Host 'Merging trimmed assemblies into a single AsmResolver.dll'
$ilrepack = Get-ILRepackPath -WorkDirectory $WorkDirectory
$mergeOutput = Join-Path $trimRoot 'merged'
New-Item -ItemType Directory -Force -Path $mergeOutput | Out-Null
# 保留裁剪目录里全部输入（含重新写出的 mscorlib/netstandard 桩）供解析；主程序集用 AsmResolver.DotNet，
# 它承载绝大多数类型与 public API 根。
$mergePrimary = Join-Path $trimmedDir 'AsmResolver.DotNet.dll'
$mergeOthers = @(
	'AsmResolver.PE.Win32Resources.dll'
	'AsmResolver.PE.dll'
	'AsmResolver.PE.File.dll'
	'AsmResolver.dll'
) | ForEach-Object { Join-Path $trimmedDir $_ }
$mergedOut = Join-Path $mergeOutput 'AsmResolver.dll'
$ilrepackArgs = @(
	"/out:$mergedOut"
	"/lib:$trimmedDir"
	'/ndebug'
	'/allowduplicateresources'
	'/target:library'
	$mergePrimary
) + $mergeOthers
& $ilrepack @ilrepackArgs
if ($LASTEXITCODE) { throw "ILRepack failed with exit code $LASTEXITCODE" }
if (-not (Test-Path -LiteralPath $mergedOut)) { throw "Merged assembly missing: $mergedOut" }

# 清掉上一版的残留（旧的 5 个分体 dll 或旧的 src/bin/AsmResolver 子目录），避免新旧混用。
Remove-Item -Path (Join-Path $OutputDirectory 'AsmResolver*.dll') -Force -ErrorAction SilentlyContinue
Remove-Item -LiteralPath (Join-Path $OutputDirectory 'AsmResolver') -Recurse -Force -ErrorAction SilentlyContinue
Copy-Item -LiteralPath $mergedOut -Destination (Join-Path $OutputDirectory 'AsmResolver.dll') -Force

# 合并前（5 个裁剪产物之和）与合并后（单文件）对比，便于脚本输出里核对收益。
foreach ($name in $AssemblyNames) {
	$trimmedAssembly = Join-Path $trimmedDir "$name.dll"
	if (-not (Test-Path -LiteralPath $trimmedAssembly)) { throw "Trimmed assembly missing: $trimmedAssembly" }
	$totalBefore += (Get-Item -LiteralPath (Join-Path $libDir "$name.dll")).Length
	$totalAfter += (Get-Item -LiteralPath $trimmedAssembly).Length
}
$mergedSize = (Get-Item -LiteralPath $mergedOut).Length
Write-Host ("AsmResolver {0}: {1:N0} KB -> trimmed {2:N0} KB -> merged {3:N0} KB ({4:P0} smaller than original, {5:P0} smaller than trimmed set) written to {6}" -f `
		$cacheKey, ($totalBefore / 1KB), ($totalAfter / 1KB), ($mergedSize / 1KB), (1 - $mergedSize / $totalBefore), (1 - $mergedSize / $totalAfter), (Resolve-Path -LiteralPath $OutputDirectory).Path)
