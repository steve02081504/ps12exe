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

try {
	# 1) 普通程序框架 exe（嵌入 main.par）
	$normalScript = "Write-Output 'normal-embed'"
	$normalScript | ps12exe -outputFile $repoRoot/build/normal.exe -Verbose | Write-Host
	$extracted = exe21sp -ExePath $repoRoot/build/normal.exe 2>&1 | Out-String
	if ($extracted -notmatch 'normal-embed') { throw "exe21sp normal: expected 'normal-embed' in: $extracted" }

	# 2) TinySharp 控制台、退出码 0
	"'tinysharp-console-zero'" | ps12exe -outputFile $repoRoot/build/ts_console_0.exe -Verbose | Write-Host
	$e2 = exe21sp -ExePath $repoRoot/build/ts_console_0.exe 2>&1 | Out-String
	if ($e2 -notmatch "tinysharp-console-zero") { throw "exe21sp TinySharp console 0: expected content, got: $e2" }
	$exit0 = & $repoRoot/build/ts_console_0.exe; if ($LASTEXITCODE -ne 0) { throw "ts_console_0.exe exit code expected 0, got $LASTEXITCODE" }

	# 3) TinySharp 控制台、非零退出码（若 const 支持 'x'; exit N）
	$scriptNonZero = "'tinysharp-console-42'; exit 42"
	$scriptNonZero | ps12exe -outputFile $repoRoot/build/ts_console_42.exe -Verbose | Write-Host
	if (Test-Path $repoRoot/build/ts_console_42.exe) {
		$e3 = exe21sp -ExePath $repoRoot/build/ts_console_42.exe 2>&1 | Out-String
		if ($e3 -notmatch "tinysharp-console-42" -or $e3 -notmatch "exit 42") { throw "exe21sp TinySharp console 42: expected content+exit 42, got: $e3" }
		& $repoRoot/build/ts_console_42.exe | Out-Null
		if ($LASTEXITCODE -ne 42) { throw "ts_console_42.exe exit code expected 42, got $LASTEXITCODE" }
	}

	# 4) TinySharp GUI、退出码 0（MessageBox，需无头或发送回车；此处仅测 exe21sp 提取）
	"'tinysharp-gui-zero'" | ps12exe -noConsole -outputFile $repoRoot/build/ts_gui_0.exe -Verbose -title 'CI' | Write-Host
	if (Test-Path $repoRoot/build/ts_gui_0.exe) {
		$e4 = exe21sp -ExePath $repoRoot/build/ts_gui_0.exe 2>&1 | Out-String
		if ($e4 -notmatch "tinysharp-gui-zero") { throw "exe21sp TinySharp GUI 0: expected content, got: $e4" }
	}

	# 5) TinySharp GUI、非零退出码
	"'tinysharp-gui-42'; exit 42" | ps12exe -noConsole -outputFile $repoRoot/build/ts_gui_42.exe -Verbose -title 'CI' | Write-Host
	if (Test-Path $repoRoot/build/ts_gui_42.exe) {
		$e5 = exe21sp -ExePath $repoRoot/build/ts_gui_42.exe 2>&1 | Out-String
		if ($e5 -notmatch "tinysharp-gui-42" -or $e5 -notmatch "exit 42") { throw "exe21sp TinySharp GUI 42: expected content+exit 42, got: $e5" }
	}
} catch {}
finally {
	Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}
if ($error) { Write-CIGitHubErrorReport }
Write-Output 'exe21sp tests OK'