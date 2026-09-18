# exe21sp 提取测试：普通 exe、TinySharp 控制台(0/非0)、TinySharp GUI(0/非0)。失败时输出 GitHub 友好 ::error/::group。
$ErrorActionPreference = 'Stop'
$error.Clear()
$repoRoot = $env:REPO_ROOT
if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }
$buildDir = Join-Path $repoRoot 'build'
$ciDir = Join-Path $repoRoot '.github/workflows/CI'

. (Join-Path $ciDir 'test-helpers.ps1')
Import-Module $repoRoot -Force
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

# 子进程内跑 exe21sp 使 stdout 被管道重定向，exe21sp 会输出到 stdout，再用 Out-String 捕获（用仓库路径 Import-Module，避免子进程 cwd 导致 . 无效）
$repoEsc = $repoRoot -replace "'", "''"
function Get-Exe21spContent {
	param([string]$RelPath)
	$exePath = Join-Path $repoRoot $RelPath
	$pathEsc = $exePath -replace "'", "''"
	pwsh -NoProfile -Command "Import-Module '$repoEsc' -Force; exe21sp -inputFile '$pathEsc'" | Out-String
}
# 管道输入：exe 路径来自管道，脚本输出到 stdout（重定向时的行为与 -inputFile 相同）
function Get-Exe21spContentFromPipeline {
	param([string]$RelPath)
	$exePath = Join-Path $repoRoot $RelPath
	$pathEsc = $exePath -replace "'", "''"
	pwsh -NoProfile -Command "Import-Module '$repoEsc' -Force; '$pathEsc' | exe21sp" | Out-String
}

try {
	# 1) 普通 exe（非常量默认打包，嵌入 main.ps1）或 TinySharp 常量化
	$normalScript = "Write-Output 'normal-embed'"
	$normalScript | ps12exe -outputFile $repoRoot/build/normal.exe -Verbose | Write-Host
	$extracted = Get-Exe21spContent 'build/normal.exe'
	if ($extracted -notmatch 'normal-embed') { throw "exe21sp normal: expected 'normal-embed' in: $extracted" }
	# exe21sp 管道输入：同一 exe 路径经管道传入会在 stdout 产出相同脚本
	$fromPipe = Get-Exe21spContentFromPipeline 'build/normal.exe'
	if ($fromPipe -notmatch 'normal-embed') { throw "exe21sp pipeline: expected 'normal-embed' in: $fromPipe" }

	# 2) TinySharp 控制台、退出码 0
	"'tinysharp-console-zero'" | ps12exe -outputFile $repoRoot/build/ts_console_0.exe -Verbose | Write-Host
	$e2 = Get-Exe21spContent 'build/ts_console_0.exe'
	if ($e2 -notmatch "tinysharp-console-zero") { throw "exe21sp TinySharp console 0: expected content, got: $e2" }
	$exit0 = & $repoRoot/build/ts_console_0.exe; if ($LASTEXITCODE -ne 0) { throw "ts_console_0.exe exit code expected 0, got $LASTEXITCODE" }

	# 3) TinySharp 控制台、非零退出码（若 const 支持 'x'; exit N）
	$scriptNonZero = "'tinysharp-console-42'; exit 42"
	$scriptNonZero | ps12exe -outputFile $repoRoot/build/ts_console_42.exe -Verbose | Write-Host
	if (Test-Path $repoRoot/build/ts_console_42.exe) {
		$e3 = Get-Exe21spContent 'build/ts_console_42.exe'
		if ($e3 -notmatch "tinysharp-console-42" -or $e3 -notmatch "exit 42") { throw "exe21sp TinySharp console 42: expected content+exit 42, got: $e3" }
		& $repoRoot/build/ts_console_42.exe | Out-Null
		if ($LASTEXITCODE -ne 42) { throw "ts_console_42.exe exit code expected 42, got $LASTEXITCODE" }
	}

	# 4) TinySharp GUI、退出码 0（MessageBox，此处仅测 exe21sp 提取）
	"'tinysharp-gui-zero'" | ps12exe -App @{Windowed=$true} -outputFile $repoRoot/build/ts_gui_0.exe -Verbose -Resources @{ Title = 'CI' } | Write-Host
	if (Test-Path $repoRoot/build/ts_gui_0.exe) {
		$e4 = Get-Exe21spContent 'build/ts_gui_0.exe'
		if ($e4 -notmatch "tinysharp-gui-zero") { throw "exe21sp TinySharp GUI 0: expected content, got: $e4" }
	}

	# 5) TinySharp GUI、非零退出码
	"'tinysharp-gui-42'; exit 42" | ps12exe -App @{Windowed=$true} -outputFile $repoRoot/build/ts_gui_42.exe -Verbose -Resources @{ Title = 'CI' } | Write-Host
	if (Test-Path $repoRoot/build/ts_gui_42.exe) {
		$e5 = Get-Exe21spContent 'build/ts_gui_42.exe'
		if ($e5 -notmatch "tinysharp-gui-42" -or $e5 -notmatch "exit 42") { throw "exe21sp TinySharp GUI 42: expected content+exit 42, got: $e5" }
	}

	# 6) 非常量 exe（默认打包：压缩负载 + launcher）：exe21sp 需能解包并还原脚本
	$packedScript = "Get-Date | Out-Null; Write-Output 'packed-embed'"
	$packedScript | ps12exe -outputFile $repoRoot/build/packed.exe -Verbose | Write-Host
	$e6 = Get-Exe21spContent 'build/packed.exe'
	if ($e6 -notmatch 'packed-embed') { throw "exe21sp packed: expected 'packed-embed' in: $e6" }
	$packedRun = & $repoRoot/build/packed.exe
	if ("$packedRun" -notmatch 'packed-embed') { throw "packed exe output mismatch: $packedRun" }

	# 7) Core exe（dotnet 单文件）：exe21sp 需能穿透单文件 bundle 找到托管负载并解包还原脚本
	if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core target requires the .NET SDK (dotnet)' }
	$coreScript = "Get-Date | Out-Null; Write-Output 'core-packed-embed'"
	$coreScript | ps12exe -Build @{Target='Core'} -outputFile $repoRoot/build/core_packed.exe -Verbose | Write-Host
	$e7 = Get-Exe21spContent 'build/core_packed.exe'
	if ($e7 -notmatch 'core-packed-embed') { throw "exe21sp Core: expected 'core-packed-embed' in: $e7" }
	# 7b) Windows PowerShell（.NET Framework 无 BrotliStream）下：转交 pwsh 解压后同样能还原
	$coreExeEsc = (Join-Path $repoRoot 'build/core_packed.exe') -replace "'", "''"
	$e7WinPs = powershell -NoProfile -Command "Import-Module '$repoEsc' -Force; exe21sp -inputFile '$coreExeEsc'" | Out-String
	if ($e7WinPs -notmatch 'core-packed-embed') { throw "exe21sp Core under Windows PowerShell: expected 'core-packed-embed' in: $e7WinPs" }

	# exe21sp 不带 -outputFile 且未重定向：保存为同目录下的 <exe>.ps1（不加管道调用；stdout 未重定向时 exe21sp 写入文件）
	$normalExeFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'build/normal.exe'))
	$expectedPs1Path = [System.IO.Path]::GetDirectoryName($normalExeFull) + [System.IO.Path]::DirectorySeparatorChar + [System.IO.Path]::GetFileNameWithoutExtension($normalExeFull) + '.ps1'
	if (Test-Path -LiteralPath $expectedPs1Path) { Remove-Item -LiteralPath $expectedPs1Path -Force }
	$stdoutNotRedirected = -not [System.Console]::IsOutputRedirected
	if ($stdoutNotRedirected) {
		exe21sp -inputFile $normalExeFull
		if (-not (Test-Path -LiteralPath $expectedPs1Path)) { throw "exe21sp no-OutFile no-redirect: expected file $expectedPs1Path" }
		$savedContent = Get-Content -LiteralPath $expectedPs1Path -Raw -Encoding UTF8
		if ($savedContent -notmatch 'normal-embed') { throw "exe21sp no-OutFile no-redirect: expected 'normal-embed' in saved file, got: $savedContent" }
	}
	# 重定向的情况（脚本输出到 stdout）已由上面的 Get-Exe21spContent / Get-Exe21spContentFromPipeline 覆盖。

	# 8) 资源参数还原：exe21sp 把源码里没有的资源配置补成 #_pragma，并把图标释放到输出目录。构造一个最小的 1x1 32bpp ICO。
	$iconPath = Join-Path $buildDir 'resource.ico'
	$ico = [System.Collections.Generic.List[byte]]::new()
	$ico.AddRange([byte[]](0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 32, 0))
	$img = [System.Collections.Generic.List[byte]]::new()
	$img.AddRange([byte[]](40, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 1, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0))
	1..4 | ForEach-Object { $img.AddRange([byte[]](0, 0, 0, 0)) }
	$img.AddRange([byte[]](0, 0, 255, 255, 0, 0, 0, 0))
	$ico.AddRange([BitConverter]::GetBytes([uint32]$img.Count))
	$ico.AddRange([BitConverter]::GetBytes([uint32]22))
	$ico.AddRange($img)
	[System.IO.File]::WriteAllBytes($iconPath, $ico.ToArray())

	$resourceScript = "Get-Date | Out-Null; Write-Output 'resource-roundtrip'"
	$resourceExe = Join-Path $buildDir 'resource.exe'
	$resourceScript | ps12exe -outputFile $resourceExe -Resources @{ Title = 'RT Title'; Description = 'RT Desc'; Company = 'RT Co'; Version = '2.3.4.5'; Icon = $iconPath } | Write-Host
	$extractOut = Join-Path $buildDir 'resource.extracted.ps1'
	exe21sp -inputFile $resourceExe -outputFile $extractOut
	$extractedText = Get-Content -LiteralPath $extractOut -Raw -Encoding UTF8
	foreach ($expected in @("#_pragma Resources.Title 'RT Title'", "#_pragma Resources.Description 'RT Desc'", "#_pragma Resources.Company 'RT Co'", "#_pragma Resources.Version '2.3.4.5'", '#_pragma Resources.Icon')) {
		if ($extractedText -notlike "*$expected*") { throw "exe21sp resource: missing [$expected] in: $extractedText" }
	}
	$releasedIcon = Join-Path $buildDir 'resource.extracted.ico'
	if (-not (Test-Path -LiteralPath $releasedIcon)) { throw "exe21sp resource: icon not released to $releasedIcon" }

	# 还原出的源码可重新编译，并保留资源参数。
	$recompiled = Join-Path $buildDir 'resource.recompiled.exe'
	ps12exe -inputFile $extractOut -outputFile $recompiled | Write-Host
	$recompiledInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($recompiled)
	if ($recompiledInfo.FileDescription -ne 'RT Title') { throw "exe21sp recompile: title lost, got '$($recompiledInfo.FileDescription)'" }
	if ($recompiledInfo.CompanyName -ne 'RT Co') { throw "exe21sp recompile: company lost, got '$($recompiledInfo.CompanyName)'" }
	if ($recompiledInfo.FileVersion -ne '2.3.4.5') { throw "exe21sp recompile: version lost, got '$($recompiledInfo.FileVersion)'" }
	if ((& $recompiled) -notmatch 'resource-roundtrip') { throw 'exe21sp recompile: run output mismatch' }

	# 幂等：源码里已有 pragma 时再次反编译不再重复补。
	$extractOut2 = Join-Path $buildDir 'resource.recompiled.ps1'
	exe21sp -inputFile $recompiled -outputFile $extractOut2
	$text2 = Get-Content -LiteralPath $extractOut2 -Raw -Encoding UTF8
	if (([regex]::Matches($text2, '(?m)^\s*#_pragma\s+Resources\.Title\b')).Count -ne 1) { throw "exe21sp idempotent: title pragma duplicated: $text2" }
	if (([regex]::Matches($text2, '(?m)^\s*#_pragma\s+Resources\.Icon\b')).Count -ne 1) { throw "exe21sp idempotent: icon pragma duplicated: $text2" }

	# 9) Core 目标的 SDK 默认值（标题/公司/产品=程序集名，版本=1.0.0.0）不应被当成资源参数补回。
	if (Get-Command dotnet -ErrorAction Ignore) {
		$corePlain = Join-Path $buildDir 'core-resource-plain.exe'
		"Get-Date | Out-Null; Write-Output 'core-resource'" | ps12exe -Build @{Target='Core'} -outputFile $corePlain | Write-Host
		$coreOut = Join-Path $buildDir 'core-resource-plain.ps1'
		exe21sp -inputFile $corePlain -outputFile $coreOut
		$coreText = Get-Content -LiteralPath $coreOut -Raw -Encoding UTF8
		foreach ($unexpected in @('#_pragma Resources.Company', '#_pragma Resources.Product', '#_pragma Resources.Version', '#_pragma Resources.Title')) {
			if ($coreText -like "*$unexpected*") { throw "exe21sp Core defaults: unexpected [$unexpected] in: $coreText" }
		}
	}
}
catch {}
finally {
	Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}
if ($error) { Write-CIGitHubErrorReport }
Write-Output 'exe21sp tests OK'
