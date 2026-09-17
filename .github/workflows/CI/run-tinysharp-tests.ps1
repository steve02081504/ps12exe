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

	# TinySharp 压缩负载：大且可压缩的常量输出走 XPRESS 内嵌 + 运行期解压，体积应明显小于原文
	$bigOutput = 'TinySharp-Compressed-OK 0123456789 abcdefghijklmnopqrstuvwxyz. ' * 60
	"'$bigOutput'" | ps12exe -outputFile $repoRoot/build/ts_compressed.exe -Verbose | Write-Host
	$rawSize = [Text.Encoding]::UTF8.GetByteCount($bigOutput)
	$compressedSize = (Get-Item $repoRoot/build/ts_compressed.exe).Length
	if ($compressedSize -ge $rawSize) { throw "TinySharp compressed exe expected smaller than raw payload ($rawSize), got $compressedSize" }
	$outCompressed = & $repoRoot/build/ts_compressed.exe 2>&1 | Out-String
	if ($outCompressed.TrimEnd("`r", "`n") -ne $bigOutput) { throw "TinySharp compressed output mismatch" }
	if ($LASTEXITCODE -ne 0) { throw "TinySharp compressed exit code expected 0, got $LASTEXITCODE" }

	# TinySharp 动态上限：超过 12.5KB 预算但可压缩的常量输出仍应走 TinySharp 壳，而不是退回普通编译
	$hugeOutput = 'TinySharp-Dynamic-Limit-OK line abcdefghijklmnopqrstuvwxyz 0123456789. ' * 400
	"'$hugeOutput'" | ps12exe -outputFile $repoRoot/build/ts_dynamic.exe -Verbose | Write-Host
	if ((Get-Item $repoRoot/build/ts_dynamic.exe).Length -ge 14kb) { throw "TinySharp dynamic-limit exe expected under a normal build (~14.5KB), got $((Get-Item $repoRoot/build/ts_dynamic.exe).Length)" }
	$outHuge = & $repoRoot/build/ts_dynamic.exe 2>&1 | Out-String
	if ($outHuge.TrimEnd("`r", "`n") -ne $hugeOutput) { throw "TinySharp dynamic-limit output mismatch" }

	# TinySharp GUI：MessageBox，需发送回车关闭（只取返回值中的退出码，避免管道混入 bool）
	"'TinySharp-GUI-OK'" | ps12exe -noConsole -outputFile $repoRoot/build/ts_gui.exe -Verbose -title 'CITitle' | Write-Host
	$raw = Invoke-ExeAndSendEnterToWindow -ExePath $repoRoot/build/ts_gui.exe -TimeoutSeconds 12
	$exitCode = if ($raw -is [array]) { $raw[-1] } else { $raw }
	if ($exitCode -ne 0) { throw "TinySharp GUI exit code expected 0, got $exitCode" }

	# TinySharp GUI 压缩负载：MessageBox 路径的大可压缩常量同样走 XPRESS 内嵌 + 运行期解压
	$bigGui = 'TinySharp-GUI-Compressed-OK 0123456789 abcdefghijklmnopqrstuvwxyz. ' * 60
	"'$bigGui'" | ps12exe -noConsole -outputFile $repoRoot/build/ts_gui_compressed.exe -Verbose | Write-Host
	$guiCompressedSize = (Get-Item $repoRoot/build/ts_gui_compressed.exe).Length
	if ($guiCompressedSize -ge [Text.Encoding]::Unicode.GetByteCount($bigGui)) { throw "TinySharp compressed GUI exe expected smaller than raw UTF-16 payload, got $guiCompressedSize" }
	$rawGui = Invoke-ExeAndSendEnterToWindow -ExePath $repoRoot/build/ts_gui_compressed.exe -TimeoutSeconds 12
	$exitCodeGui = if ($rawGui -is [array]) { $rawGui[-1] } else { $rawGui }
	if ($exitCodeGui -ne 0) { throw "TinySharp compressed GUI exit code expected 0, got $exitCodeGui" }
} catch {}
finally {
	Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}
if ($error) { Write-CIGitHubErrorReport }
Write-Output 'TinySharp tests OK'
