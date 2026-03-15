# TinySharp 运行测试：控制台 exe 输出/退出码；GUI exe 通过向窗口发送回车关闭 MessageBox 并校验退出码。失败时输出 GitHub 友好 ::error/::group。
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
	# TinySharp 控制台：输出与退出码 0
	"'TinySharp-Console-OK'" | ps12exe -outputFile $repoRoot/build/ts_console.exe -Verbose | Write-Host
	$out = & $repoRoot/build/ts_console.exe 2>&1 | Out-String
	if ($out -notmatch 'TinySharp-Console-OK') { throw "TinySharp console output expected 'TinySharp-Console-OK', got: $out" }
	if ($LASTEXITCODE -ne 0) { throw "TinySharp console exit code expected 0, got $LASTEXITCODE" }

	# TinySharp GUI：MessageBox，需发送回车关闭
	"'TinySharp-GUI-OK'" | ps12exe -noConsole -outputFile $repoRoot/build/ts_gui.exe -Verbose -title 'CITitle' | Write-Host
	$exitCode = Invoke-ExeAndSendEnterToWindow -ExePath $repoRoot/build/ts_gui.exe -TimeoutSeconds 12
	if ($exitCode -ne 0) { throw "TinySharp GUI exit code expected 0, got $exitCode" }
} catch {}
finally {
	Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}
if ($error) { Write-CIGitHubErrorReport }
Write-Output 'TinySharp tests OK'