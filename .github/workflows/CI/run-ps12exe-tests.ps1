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

	# winpwsh：引用收集不得往 $error 塞 Load 失败（EAP Stop 下会冒充编译失败，打出 CompilationFailed / OppsSomethingWentWrong）
	$error.Clear()
	$errCleanPs1 = Join-Path $buildDir 'error-clean.ps1'
	$errCleanExe = Join-Path $buildDir 'error-clean.exe'
	Set-Content -LiteralPath $errCleanPs1 -Encoding UTF8 -Value "Write-Error 'a'; Write-Output 'error-clean'"
	ps12exe -inputFile $errCleanPs1 -outputFile $errCleanExe | Write-Host
	if (-not (Test-Path -LiteralPath $errCleanExe)) { throw 'error-clean compile produced no exe' }
	if ($error.Count) {
		throw "ps12exe polluted `$error during successful compile: $($error | Out-String)"
	}

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

	# exe 宿主内嵌套跑 ps12exe（issue 60）：控制组编译到新路径必须成功；复现组目标是宿主自身（被占用）时，失败原因必须对用户可见，不能只打出"编译失败！"就没了
	# 根因不在 ps12exe.ps1 的输出方式，而在 default.cs 编译出的宿主如何渲染 Streams.Error：
	# PSRunnerEntry.Main 里 Streams.Error.DataAdded 是纯异步单次回调，回调本身一旦抛异常（比如 Console.ForegroundColor
	# 在个别宿主控制台状态下会抛 IOException）会被 PS 引擎的事件分发悄悄吞掉——没有崩溃、没有第二次机会，这条错误就彻底消失，
	# 且不影响后续脚本继续跑（所以"编译失败！"这种后续提示还能正常出现，非常具有迷惑性）。
	# 修复方式：DataAdded 回调自身加 try/catch 兜底 + 记录已渲染下标；EndInvoke 后对 Streams.Error 做一次收尾扫描，
	# 把回调没成功渲染的错误补上。这是这两个宿主测试用例真正要守住的不变式，不是"能不能编译成功"这么简单。
	$nestedDir = Join-Path $buildDir 'nested'
	New-Item -ItemType Directory -Path $nestedDir -Force | Out-Null
	$nestedInnerPs1 = Join-Path $nestedDir 'inner.ps1'
	Set-Content -LiteralPath $nestedInnerPs1 -Encoding UTF8 -Value "Write-Output 'inner-ok'"

	$nestedOkHostPs1 = Join-Path $nestedDir 'host-ok.ps1'
	$nestedOkHostExe = Join-Path $nestedDir 'host-ok.exe'
	$nestedOkInnerExe = Join-Path $nestedDir 'inner-ok.exe'
	Set-Content -LiteralPath $nestedOkHostPs1 -Encoding UTF8 -Value @"
Import-Module '$repoRoot' -Force
`$Error.Clear()
ps12exe -inputFile '$nestedInnerPs1' -outputFile '$nestedOkInnerExe' -SkipVersionCheck
Write-Host "NESTED_LASTEXITCODE=`$LastExitCode"
Write-Host "NESTED_ERROR_COUNT=`$(`$Error.Count)"
"@
	ps12exe -inputFile $nestedOkHostPs1 -outputFile $nestedOkHostExe | Write-Host
	$nestedOk = Invoke-ExeCaptureMergedOutput -ExePath $nestedOkHostExe -TimeoutSeconds 60
	if (-not (Test-Path -LiteralPath $nestedOkInnerExe)) {
		throw "nested ps12exe (control) did not produce inner exe, host output: $($nestedOk.Output)"
	}
	if ($nestedOk.Output -notmatch 'NESTED_LASTEXITCODE=0') {
		throw "nested ps12exe (control) did not report success exit code, got: $($nestedOk.Output)"
	}

	$nestedFailHostPs1 = Join-Path $nestedDir 'host-fail.ps1'
	$nestedFailHostExe = Join-Path $nestedDir 'host-fail.exe'
	Set-Content -LiteralPath $nestedFailHostPs1 -Encoding UTF8 -Value @"
Import-Module '$repoRoot' -Force
`$Error.Clear()
ps12exe -inputFile '$nestedInnerPs1' -outputFile `$PSCommandPath -SkipVersionCheck
Write-Host "NESTED_LASTEXITCODE=`$LastExitCode"
Write-Host "NESTED_ERROR_COUNT=`$(`$Error.Count)"
`$Error | ForEach-Object { Write-Host "NESTED_ERROR_TEXT: `$_" }
"@
	ps12exe -inputFile $nestedFailHostPs1 -outputFile $nestedFailHostExe | Write-Host
	$nestedFail = Invoke-ExeCaptureMergedOutput -ExePath $nestedFailHostExe -TimeoutSeconds 60
	if ($nestedFail.Output -notmatch 'NESTED_LASTEXITCODE=[1-3]') {
		throw "nested ps12exe (self-overwrite) should fail with a documented LastExitCode, got: $($nestedFail.Output)"
	}
	if ($nestedFail.Output -notmatch '(?i)CS0016|being used by another process') {
		throw "nested ps12exe swallowed the real compile failure reason (issue 60), got: $($nestedFail.Output)"
	}

	# Framework2.0：PS2 引擎缺失时仍应能编过（引用需含 System.Core，否则 CS0012 IDynamicMetaObjectProvider）
	$fw20Ps1 = Join-Path $buildDir 'fw20-err-order.ps1'
	$fw20Exe = Join-Path $buildDir 'fw20-err-order.exe'
	Set-Content -LiteralPath $fw20Ps1 -Encoding UTF8 -Value "Write-Error 'a'; Write-Output '123'"
	ps12exe -inputFile $fw20Ps1 -outputFile $fw20Exe -targetRuntime Framework2.0 | Write-Host
	if (-not (Test-Path -LiteralPath $fw20Exe)) { throw 'Framework2.0 compile produced no exe' }
	$fw20 = Invoke-ExeCaptureMergedOutput -ExePath $fw20Exe
	if ($fw20.Output -notmatch '(?s)a.*123') {
		throw "Framework2.0 exe output mismatch, got: $($fw20.Output)"
	}

	# Pipeline/redirection: when stdout is redirected, ps12exe outputs only the exe path
	$redirectPs1 = Join-Path $buildDir 'redirect_test.ps1'
	$redirectExe = Join-Path $buildDir 'redirect_test.exe'
	Set-Content -LiteralPath $redirectPs1 -Value "Write-Output 'redirect-test'" -Encoding UTF8
	$expectedExePath = [System.IO.Path]::GetFullPath($redirectExe)
	$capturedPath = & $repoRoot/ps12exe.ps1 -inputFile $redirectPs1 -outputFile $redirectExe 2>$null
	if ([string]::IsNullOrWhiteSpace($capturedPath)) {
		throw "ps12exe redirect: stdout empty after compile (expected path $expectedExePath)"
	}
	if ([System.IO.Path]::GetFullPath($capturedPath) -ne $expectedExePath) {
		throw "ps12exe redirect: expected path $expectedExePath , got: $capturedPath"
	}

	# 供 workflow 上传产物：将 exe 拷到仓库根
	Copy-Item -LiteralPath (Join-Path $buildDir 'ps12exe.exe') -Destination (Join-Path $repoRoot 'ps12exe.exe') -Force
} catch {}
finally {
	Restore-ps12exeContextMenuState -WasEnabled $contextMenuWasEnabled
	Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}
if ($error) { Write-CIGitHubErrorReport }
Write-Output 'Nice CI!'
