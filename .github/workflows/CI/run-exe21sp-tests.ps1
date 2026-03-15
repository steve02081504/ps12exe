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
	pwsh -NoProfile -Command "Import-Module '$repoEsc' -Force; exe21sp -ExePath '$pathEsc'" | Out-String
}
# Pipeline input: exe path from pipeline, script to stdout (same behavior as -ExePath when redirected)
function Get-Exe21spContentFromPipeline {
	param([string]$RelPath)
	$exePath = Join-Path $repoRoot $RelPath
	$pathEsc = $exePath -replace "'", "''"
	pwsh -NoProfile -Command "Import-Module '$repoEsc' -Force; '$pathEsc' | exe21sp" | Out-String
}

try {
	# 1) 普通程序框架 exe（嵌入 main.par）或 TinySharp 常量化
	$normalScript = "Write-Output 'normal-embed'"
	$normalScript | ps12exe -outputFile $repoRoot/build/normal.exe -Verbose | Write-Host
	$extracted = Get-Exe21spContent 'build/normal.exe'
	if ($extracted -notmatch 'normal-embed') { throw "exe21sp normal: expected 'normal-embed' in: $extracted" }
	# exe21sp pipeline input: same exe path via pipeline yields same script on stdout
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
	"'tinysharp-gui-zero'" | ps12exe -noConsole -outputFile $repoRoot/build/ts_gui_0.exe -Verbose -title 'CI' | Write-Host
	if (Test-Path $repoRoot/build/ts_gui_0.exe) {
		$e4 = Get-Exe21spContent 'build/ts_gui_0.exe'
		if ($e4 -notmatch "tinysharp-gui-zero") { throw "exe21sp TinySharp GUI 0: expected content, got: $e4" }
	}

	# 5) TinySharp GUI、非零退出码
	"'tinysharp-gui-42'; exit 42" | ps12exe -noConsole -outputFile $repoRoot/build/ts_gui_42.exe -Verbose -title 'CI' | Write-Host
	if (Test-Path $repoRoot/build/ts_gui_42.exe) {
		$e5 = Get-Exe21spContent 'build/ts_gui_42.exe'
		if ($e5 -notmatch "tinysharp-gui-42" -or $e5 -notmatch "exit 42") { throw "exe21sp TinySharp GUI 42: expected content+exit 42, got: $e5" }
	}

	# exe21sp without -OutFile and without redirect: saves to <exe>.ps1 in same directory (call without pipe; when stdout is not redirected, exe21sp writes to file)
	$normalExeFull = [System.IO.Path]::GetFullPath((Join-Path $repoRoot 'build/normal.exe'))
	$expectedPs1Path = [System.IO.Path]::GetDirectoryName($normalExeFull) + [System.IO.Path]::DirectorySeparatorChar + [System.IO.Path]::GetFileNameWithoutExtension($normalExeFull) + '.ps1'
	if (Test-Path -LiteralPath $expectedPs1Path) { Remove-Item -LiteralPath $expectedPs1Path -Force }
	$stdoutNotRedirected = -not [System.Console]::IsOutputRedirected
	if ($stdoutNotRedirected) {
		exe21sp -ExePath $normalExeFull
		if (-not (Test-Path -LiteralPath $expectedPs1Path)) { throw "exe21sp no-OutFile no-redirect: expected file $expectedPs1Path" }
		$savedContent = Get-Content -LiteralPath $expectedPs1Path -Raw -Encoding UTF8
		if ($savedContent -notmatch 'normal-embed') { throw "exe21sp no-OutFile no-redirect: expected 'normal-embed' in saved file, got: $savedContent" }
	}
	# Redirect case (script to stdout) is covered by Get-Exe21spContent / Get-Exe21spContentFromPipeline above.
} catch {}
finally {
	Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}
if ($error) { Write-CIGitHubErrorReport }
Write-Output 'exe21sp tests OK'
