# Shared（CoreCompiler.ps1）与 Bundled（CoreBundledCompiler.ps1）两个 Core 后端共用的 dotnet 工程辅助：
# 缓存工程目录 + 命名互斥量、统一的 dotnet 调用、产物拷贝，以及按脚本内容粗判 GUI 框架。

# 解析 dotnet 宿主；Windows PowerShell 下调用方应先交接给 pwsh。
function Get-CoreDotnet {
	$dotnet = Get-Command dotnet -ErrorAction Ignore
	if (-not $dotnet) {
		Write-I18n Error CoreCompileNeedDotnet -Category NotInstalled
		throw 'ps12exe:core-need-dotnet'
	}
	return $dotnet
}

# 把选项清单哈希成 24 位十六进制的缓存键。
function Get-CoreBuildKey([string[]]$Invariant) {
	$sha = [System.Security.Cryptography.SHA256]::Create()
	try {
		return [System.BitConverter]::ToString($sha.ComputeHash([System.Text.Encoding]::UTF8.GetBytes($Invariant -join "`n"))).Replace('-', '').Substring(0, 24)
	}
	finally { $sha.Dispose() }
}

# 进入某编译选项组合对应的缓存工程目录：命中即 touch，长期未用则清理；用命名互斥量串行化同一 key 的并发编译。
# 返回 @{ ProjectDir; Mutex; Locked }；拿不到锁（超时/平台不支持）时退化为本次独占的临时目录。
function Enter-CoreProject {
	param([string]$CacheTag, [string]$BuildKey, [string]$TempDir, [int]$MutexTimeoutMs = 300000)
	$cacheRoot = Get-CacheRoot 'core'
	$projectDir = Join-Path $cacheRoot $BuildKey
	if (Test-Path -LiteralPath $projectDir) { (Get-Item -LiteralPath $projectDir).LastWriteTimeUtc = [DateTime]::UtcNow }
	Clear-StaleCache $cacheRoot

	$mutex = $null
	$locked = $false
	try {
		$mutex = [System.Threading.Mutex]::new($false, "ps12exe-$CacheTag-$BuildKey")
		$locked = $mutex.WaitOne($MutexTimeoutMs)
	}
	catch { $mutex = $null; $locked = $false }
	if (-not $locked) {
		$projectDir = Join-Path $TempDir "coreproj-$([Guid]::NewGuid().ToString('N'))"
		Remove-Item -LiteralPath $projectDir -Recurse -Force -ErrorAction Ignore
	}
	New-Item -ItemType Directory -Path $projectDir -Force | Out-Null
	return @{ ProjectDir = $projectDir; Mutex = $mutex; Locked = $locked }
}

# 释放 Enter-CoreProject 取得的互斥量。
function Exit-CoreProject($Project) {
	if (-not $Project.Mutex) { return }
	try { if ($Project.Locked) { $Project.Mutex.ReleaseMutex() } } catch {}
	$Project.Mutex.Dispose()
}

# 统一的 dotnet 调用：若 obj/project.assets.json 已存在（缓存命中）则加 --no-restore；
# 若 --no-restore 失败（obj 损坏 / SDK 升级）再退回完整还原重试一次。
function Invoke-CoreDotnet {
	param([string[]]$DotnetArgs, [string]$AssetsPath, [string]$DotnetPath)
	$useNoRestore = Test-Path -LiteralPath $AssetsPath
	$effective = if ($useNoRestore) { $DotnetArgs + '--no-restore' } else { $DotnetArgs }
	$output = & $DotnetPath @effective --nologo -v quiet 2>&1
	if ($LASTEXITCODE -ne 0 -and $useNoRestore) {
		$output = & $DotnetPath @DotnetArgs --nologo -v quiet 2>&1
	}
	if ($LASTEXITCODE -ne 0) { throw ($output -join "`n") }
	return $output
}

# 校验 publish 产物并把 exe（单文件）或整个发布目录（非单文件）拷到 $OutputFile，附带可选 pdb。
function Copy-CorePublishOutput {
	param([string]$PublishDir, [string]$AssemblyName, [string]$OutputFile, [bool]$SingleFile, [bool]$PrepareDebug)
	$publishedExe = Join-Path $PublishDir "$AssemblyName.exe"
	if (-not (Test-Path -LiteralPath $publishedExe)) {
		Write-I18n Error OutputFileNotWritten -Category WriteError
		throw 'ps12exe:core-no-output'
	}
	if ($SingleFile) {
		Copy-Item -LiteralPath $publishedExe -Destination $OutputFile -Force
	}
	else {
		# 非单文件：把整个 publish 目录（exe + deps/runtimeconfig 等）拷到 outputFile 所在目录。
		$outDir = Split-Path -Parent $OutputFile
		New-Item -ItemType Directory -Path $outDir -Force | Out-Null
		Copy-Item -Path (Join-Path $PublishDir '*') -Destination $outDir -Recurse -Force
		$copiedExe = Join-Path $outDir "$AssemblyName.exe"
		if ([System.IO.Path]::GetFullPath($copiedExe) -ne [System.IO.Path]::GetFullPath($OutputFile)) {
			Move-Item -LiteralPath $copiedExe -Destination $OutputFile -Force
		}
	}
	if ($PrepareDebug) {
		$publishedPdb = Join-Path $PublishDir "$AssemblyName.pdb"
		if (Test-Path -LiteralPath $publishedPdb) {
			Copy-Item -LiteralPath $publishedPdb -Destination ($OutputFile -replace '\.exe$', '.pdb') -Force
		}
	}
}

# 从脚本源码粗略识别 WinForms / WPF 的使用：Core 目标下 console 应用默认不引用 WindowsDesktop 框架，
# 命中时由编译器按需打开 UseWindowsForms / UseWPF（PS2EXE.Core #6）。宁可多开也不漏——误判只让产物大一点。
function Get-GuiFrameworkUsage([string]$Text) {
	$winForms = $Text -match '(?i)(?<![\w.])System\.Windows\.Forms(?!\w)|(?<![\w.])System\.Drawing(?!\w)'
	$wpf = $Text -match '(?i)(?<![\w.])System\.Windows\.(?!Forms)|(?<![\w.])PresentationFramework(?!\w)|(?<![\w.])PresentationCore(?!\w)|(?<![\w.])WindowsBase(?!\w)'
	return @{ WinForms = $winForms; Wpf = $wpf }
}
