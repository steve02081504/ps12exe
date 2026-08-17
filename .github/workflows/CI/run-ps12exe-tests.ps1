# ps12exe 构建与基础运行测试；无状态：测试前后恢复右键菜单状态。失败时输出 GitHub 友好 ::error/::group。
$ErrorActionPreference = 'Stop'
$error.Clear()
$repoRoot = $env:REPO_ROOT
if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }
$buildDir = Join-Path $repoRoot 'build'
$ciDir = Join-Path $repoRoot '.github/workflows/CI'

. (Join-Path $ciDir 'test-helpers.ps1')

$contextMenuWasEnabled = Save-ps12exeContextMenuState
try {
	Import-Module $repoRoot -Force
	New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

	# 构建主 exe
	& $repoRoot/ps12exe.ps1 $repoRoot/ps12exe.ps1 $repoRoot/build/ps12exe.exe -Verbose | Write-Host
	if (-not (Test-Path (Join-Path $buildDir 'ps12exe.exe'))) { throw 'ps12exe.exe not built' }

	# 无状态：仅在测试中临时启用右键菜单（若需测试菜单则启用），测试后恢复
	Set-ps12exeContextMenu -action enable | Out-Null

	# 控制台 + noConsole + 二次编译
	& $repoRoot/build/ps12exe.exe $repoRoot/ps12exe.ps1 -Verbose -noConsole -title 'lol' | Write-Host
	& $repoRoot/build/ps12exe.exe $repoRoot/ps12exe.ps1 $repoRoot/build/ps12exe2.exe -Verbose | Write-Host
	"'Hello 世界！👾'" | ps12exe -outputFile $repoRoot/build/hello.exe -Verbose | Write-Host
	& $repoRoot/build/ps12exe2.exe -Content '$PSCommandPath;$PSScriptRoot' -outputFile $repoRoot/build/pathtest.exe | Write-Host

	$pathresult = . $repoRoot/build/pathtest.exe
	$pathresultshouldbe = @("$repoRoot/build/pathtest.exe", "$repoRoot/build")
	if ($pathresult.Count -ne $pathresultshouldbe.Count) { Write-Error "pathresult.Count -ne pathresultshouldbe.Count" }
	for ($i = 0; $i -lt $pathresult.Count; $i++) {
		$path1 = [System.IO.Path]::GetFullPath($pathresult[$i])
		$path2 = [System.IO.Path]::GetFullPath($pathresultshouldbe[$i])
		if ($path1 -ne $path2) { Write-Error "$path1 -ne $path2" }
	}
	& $repoRoot/build/hello.exe | Write-Host

	# Native child stdout TTY（issue 59）：独立 console 下 `& powershell` 的 stdout 必须是 console，不能被宿主 Out-String 收成管道
	$ttyDir = Join-Path $buildDir 'tty'
	New-Item -ItemType Directory -Path $ttyDir -Force | Out-Null
	$ttyChildPs1 = Join-Path $ttyDir 'child.ps1'
	$ttyProbePs1 = Join-Path $ttyDir 'probe.ps1'
	$ttyProbeExe = Join-Path $ttyDir 'probe.exe'
	$ttyChildFlag = Join-Path $ttyDir 'child-redirected.txt'
	$ttyHostJson = Join-Path $ttyDir 'host.json'
	Set-Content -LiteralPath $ttyChildPs1 -Encoding UTF8 -Value @'
[System.IO.File]::WriteAllText($env:PS12EXE_TTY_CHILD, ([Console]::IsOutputRedirected).ToString())
'@
	Set-Content -LiteralPath $ttyProbePs1 -Encoding UTF8 -Value @'
@{
	hostName = $Host.Name
	inRedirected = [Console]::IsInputRedirected
	outRedirected = [Console]::IsOutputRedirected
} | ConvertTo-Json -Compress | Set-Content -LiteralPath $env:PS12EXE_TTY_HOST -Encoding UTF8
Remove-Item -LiteralPath $env:PS12EXE_TTY_CHILD -ErrorAction Ignore
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
& $powershell -NoProfile -NonInteractive -File $env:PS12EXE_TTY_CHILD_PS1
if ($LASTEXITCODE) { exit $LASTEXITCODE }
'@
	ps12exe -inputFile $ttyProbePs1 -outputFile $ttyProbeExe | Write-Host
	$env:PS12EXE_TTY_CHILD = $ttyChildFlag
	$env:PS12EXE_TTY_HOST = $ttyHostJson
	$env:PS12EXE_TTY_CHILD_PS1 = $ttyChildPs1
	$ttyExit = Invoke-ExeWithPrivateConsole -ExePath $ttyProbeExe
	if ($ttyExit -ne 0) { throw "tty probe exit $ttyExit" }
	$ttyHost = Get-Content -LiteralPath $ttyHostJson -Raw | ConvertFrom-Json
	if ($ttyHost.outRedirected) { throw "tty probe host stdout redirected (private console expected): $ttyHostJson" }
	$ttyChildRedirected = Get-Content -LiteralPath $ttyChildFlag -Raw
	if ($ttyChildRedirected.Trim() -ne 'False') {
		throw "native child stdout redirected under console EXE (issue 59): $ttyChildRedirected"
	}

	# 宿主 stdout 被管道接走时，native 输出仍应出现在捕获结果里
	$echoPs1 = Join-Path $buildDir 'native-echo.ps1'
	$echoExe = Join-Path $buildDir 'native-echo.exe'
	Set-Content -LiteralPath $echoPs1 -Encoding UTF8 -Value "cmd /c echo native-hello"
	ps12exe -inputFile $echoPs1 -outputFile $echoExe | Write-Host
	$echoOut = & $echoExe
	if ("$echoOut" -notmatch 'native-hello') { throw "redirected native stdout lost, got: $echoOut" }

	# Write-Error 与成功输出的先后应与 pwsh 一致（错误先于后续 Write-Output）
	$errOrderPs1 = Join-Path $buildDir 'err-order.ps1'
	$errOrderExe = Join-Path $buildDir 'err-order.exe'
	Set-Content -LiteralPath $errOrderPs1 -Encoding UTF8 -Value "Write-Error 'err-a'; Write-Output 'out-b'"
	ps12exe -inputFile $errOrderPs1 -outputFile $errOrderExe | Write-Host
	$errOrder = Invoke-ExeCaptureMergedOutput -ExePath $errOrderExe
	if ([string]::IsNullOrWhiteSpace($errOrder.Output)) {
		throw "err-order exe produced no captured output"
	}
	if ($errOrder.Output -notmatch '(?s)err-a.*out-b') {
		throw "Write-Error should appear before success output (pwsh order), got: $($errOrder.Output)"
	}

	# Pipeline/redirection: when stdout is redirected, ps12exe outputs only the exe path
	Set-Content -LiteralPath (Join-Path $buildDir 'redirect_test.ps1') -Value "Write-Output 'redirect-test'" -Encoding UTF8
	$expectedExePath = [System.IO.Path]::GetFullPath((Join-Path $buildDir 'redirect_test.exe'))
	$capturedPath = & $repoRoot/ps12exe.ps1 -inputFile (Join-Path $buildDir 'redirect_test.ps1') 2>$null
	if ([System.IO.Path]::GetFullPath($capturedPath) -ne $expectedExePath) { throw "ps12exe redirect: expected path $expectedExePath , got: $capturedPath" }

	# 供 workflow 上传产物：将 exe 拷到仓库根
	Copy-Item -LiteralPath (Join-Path $buildDir 'ps12exe.exe') -Destination (Join-Path $repoRoot 'ps12exe.exe') -Force
} catch {}
finally {
	Restore-ps12exeContextMenuState -WasEnabled $contextMenuWasEnabled
	Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}
if ($error) { Write-CIGitHubErrorReport }
Write-Output 'Nice CI!'
