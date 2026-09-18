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

	# winpwsh：引用收集不得往 $error 塞 Load 失败（EAP Stop 下会冒充编译失败，打出 CompilationFailed / OopsSomethingWentWrong）
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

	# 控制台 + Windowed + 二次编译
	& $repoRoot/build/ps12exe.exe $repoRoot/ps12exe.ps1 -Verbose -App @{Windowed=$true} | Write-Host
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

	# 命令行参数按 PSD 数据解析：脚本有 param 块时，表/数组/安全转换按对象传入；表达式/命令不参与求值
	$psdDir = Join-Path $buildDir 'psd'
	New-Item -ItemType Directory -Path $psdDir -Force | Out-Null
	$psdPs1 = Join-Path $psdDir 'psd.ps1'
	$psdExe = Join-Path $psdDir 'psd.exe'
	Set-Content -LiteralPath $psdPs1 -Encoding UTF8 -Value @'
param([hashtable]$Config, [int]$N = 0)
"Type=$($Config.GetType().Name) a=$($Config.a) x=$($Config.x) N=$N"
'@
	ps12exe -inputFile $psdPs1 -outputFile $psdExe | Write-Host
	# 用 cmd 合并捕获输出：Windows PowerShell 5.1 里 native stderr 经 2>&1 会产生 NativeCommandError（EAP Stop 下直接终止）。
	$psdOut = (Invoke-ExeCaptureMergedOutput -ExePath $psdExe -Arguments @('-Config', "@{a='b'}", '-N', "[int]'42'")).Output
	if ($psdOut -notmatch 'Type=Hashtable' -or $psdOut -notmatch 'a=b' -or $psdOut -notmatch 'N=42') {
		throw "PSD argument parsing failed: $psdOut"
	}
	$psdBad = (Invoke-ExeCaptureMergedOutput -ExePath $psdExe -Arguments @('-Config', "@{x=1+1}")).Output
	if ($psdBad -match 'x=2') { throw "PSD argument was evaluated as PowerShell: $psdBad" }

	# 非常量 exe 默认走“压缩负载 + 内存 launcher”，pathtest.exe 已覆盖 $PSCommandPath/$PSScriptRoot。
	$packedSize = (Get-Item -LiteralPath $repoRoot/build/pathtest.exe).Length
	if ($packedSize -ge 25088) { throw "non-const exe is not packed by default (size=$packedSize)" }

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

	# exe 宿主内嵌套跑 ps12exe（issue 60）：控制组编译到新路径必须成功；复现组目标是宿主自身（被占用）时，失败原因必须对用户可见，不能只打出"编译失败！"就没了根因不在 ps12exe.ps1 的输出方式，而在 default.cs 编译出的宿主如何渲染 Streams.Error：PSRunnerEntry.Main 里 Streams.Error.DataAdded 是纯异步单次回调，回调本身一旦抛异常（比如 Console.ForegroundColor在个别宿主控制台状态下会抛 IOException）会被 PS 引擎的事件分发悄悄吞掉——没有崩溃、没有第二次机会，这条错误就彻底消失，且不影响后续脚本继续跑（所以"编译失败！"这种后续提示还能正常出现，非常具有迷惑性）。修复方式：DataAdded 回调自身加 try/catch 兜底 + 记录已渲染下标；EndInvoke 后对 Streams.Error 做一次收尾扫描，把回调没成功渲染的错误补上。这是这两个宿主测试用例真正要守住的不变式，不是"能不能编译成功"这么简单。
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
ps12exe -inputFile '$nestedInnerPs1' -outputFile '$nestedOkInnerExe' -NoUpdateCheck
Write-Host "NESTED_LASTEXITCODE=`$LastExitCode"
Write-Host "NESTED_ERROR_COUNT=`$(`$Error.Count)"
"@
	ps12exe -inputFile $nestedOkHostPs1 -outputFile $nestedOkHostExe | Write-Host
	# CI runner 上每次编译约需 85s（见各编译点日志间隔），嵌套 run 内部还要再做一次完整编译，超时给足余量
	$nestedOk = Invoke-ExeCaptureMergedOutput -ExePath $nestedOkHostExe -TimeoutSeconds 300
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
ps12exe -inputFile '$nestedInnerPs1' -outputFile `$PSCommandPath -NoUpdateCheck
Write-Host "NESTED_LASTEXITCODE=`$LastExitCode"
Write-Host "NESTED_ERROR_COUNT=`$(`$Error.Count)"
`$Error | ForEach-Object { Write-Host "NESTED_ERROR_TEXT: `$_" }
"@
	ps12exe -inputFile $nestedFailHostPs1 -outputFile $nestedFailHostExe | Write-Host
	$nestedFail = Invoke-ExeCaptureMergedOutput -ExePath $nestedFailHostExe -TimeoutSeconds 300
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
	ps12exe -inputFile $fw20Ps1 -outputFile $fw20Exe -Build @{Target='Framework2.0'} | Write-Host
	if (-not (Test-Path -LiteralPath $fw20Exe)) { throw 'Framework2.0 compile produced no exe' }
	$fw20 = Invoke-ExeCaptureMergedOutput -ExePath $fw20Exe
	if ($fw20.Output -notmatch '(?s)a.*123') {
		throw "Framework2.0 exe output mismatch, got: $($fw20.Output)"
	}

	# Core（.NET）：dotnet publish 单文件 + Brotli 负载，产物框架依赖（目标机需 pwsh 与匹配的 .NET 运行时）
	if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core target requires the .NET SDK (dotnet)' }
	$corePs1 = Join-Path $buildDir 'core-run.ps1'
	$coreExe = Join-Path $buildDir 'core-run.exe'
	Set-Content -LiteralPath $corePs1 -Encoding UTF8 -Value "Get-Date | Out-Null; Write-Output 'core-run-ok'"
	ps12exe -inputFile $corePs1 -outputFile $coreExe -Build @{Target='Core'} | Write-Host
	if (-not (Test-Path -LiteralPath $coreExe)) { throw 'Core compile produced no exe' }
	$core = Invoke-ExeCaptureMergedOutput -ExePath $coreExe
	if ($core.Output -notmatch 'core-run-ok') {
		throw "Core exe output mismatch, got: $($core.Output)"
	}

	# 管道/重定向：stdout 被重定向时，ps12exe 只输出 exe 路径
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

	# #_pragma $(...) 子表达式求值（issue 60）：AST 白名单 + 访客模式安全
	# 直接对 Preprocessor 单测：非访客模式允许白名单内的 path 命令，拒绝实例方法/危险命令；访客模式额外拒绝 Get-Content。
	$script:GuestMode = $false
	$script:Params = @{}
	$ParamList = @{
		App       = @{ ParameterType = [hashtable] }
		Os        = @{ ParameterType = [hashtable] }
		Build     = @{ ParameterType = [hashtable] }
		Resources = @{ ParameterType = [hashtable] }
		Signing   = @{ ParameterType = [hashtable] }
	}
	$script:i18nWarnings = [System.Collections.Generic.List[string]]::new()
	function Write-I18n {
		param($PipeLineType, $Mid, $FormatArgs, $Category)
		if ($PipeLineType -eq 'Error') { throw "PragmaError:$Mid" }
		if ($PipeLineType -eq 'Warning') { $script:i18nWarnings.Add($Mid) }
	}
	. (Join-Path $repoRoot 'src/ReadScriptFile.ps1')
	function Get-ParamByPath($Params, [string]$Path) {
		$cur = $Params
		foreach ($seg in ($Path -split '\.')) { $cur = $cur[$seg] }
		$cur
	}
	function Invoke-PragmaTest([string]$pragma, [bool]$guest, [string]$expect, [string]$assertParam = 'Resources.Icon') {
		$script:GuestMode = $guest
		$script:Params = @{}
		$rejected = $false
		try { [void](Preprocessor @($pragma) "C:\compiled\main.ps1") } catch { $rejected = $true; $Error.Clear() }
		$actual = if ($rejected) { 'REJECTED' } else { Get-ParamByPath $script:Params $assertParam }
		if ($expect -eq 'REJECTED') {
			if (-not $rejected) { throw "pragma should be rejected: [$pragma] guest=$guest got value: $actual" }
		}
		else {
			if ($rejected) { throw "pragma should resolve: [$pragma] guest=$guest was rejected" }
			if ("$actual" -ne $expect) { throw "pragma value mismatch: [$pragma] guest=$guest expected [$expect] got [$actual]" }
		}
	}
	$userProfileFoo = Join-Path $env:USERPROFILE 'foo.ico'
	$pwshSource = (Get-Command pwsh).Source
	$secretFile = Join-Path $buildDir 'pragma-secret.txt'
	Set-Content -LiteralPath $secretFile -Encoding UTF8 -Value 'secret-value'
	$env:PRAGMA_SECRET = $secretFile
	Invoke-PragmaTest '#_pragma Resources.Icon $(Join-Path $env:USERPROFILE "foo.ico")' $false $userProfileFoo
	Invoke-PragmaTest '#_pragma Resources.Icon $(Join-Path $env:USERPROFILE "foo.ico")' $true $userProfileFoo
	Invoke-PragmaTest '#_pragma Resources.Icon $((Get-Command pwsh).Source)' $false $pwshSource
	Invoke-PragmaTest '#_pragma Resources.Icon $((Join-Path $env:USERPROFILE "Foo.ico").ToLower())' $false (Join-Path $env:USERPROFILE 'foo.ico')
	Invoke-PragmaTest '#_pragma Resources.Icon $((Get-Item C:\Windows).Delete())' $false 'REJECTED'
	Invoke-PragmaTest '#_pragma Resources.Icon $(Remove-Item C:\x -Recurse)' $false 'REJECTED'
	Invoke-PragmaTest '#_pragma Resources.Icon $(Get-Content $env:PRAGMA_SECRET)' $false 'secret-value'
	Invoke-PragmaTest '#_pragma Resources.Icon $(Get-Content $env:PRAGMA_SECRET)' $true 'REJECTED'
	Invoke-PragmaTest '#_pragma Resources.Icon $PSScriptRoot/foo.ico' $false 'C:\compiled/foo.ico'
	Invoke-PragmaTest '#_pragma Resources.Title "prefix$(Split-Path $PSScriptRoot -Leaf)suffix"' $false 'prefixcompiledsuffix' 'Resources.Title'
	Invoke-PragmaTest '#_pragma Signing.Certificate C:\cert.pfx' $false 'C:\cert.pfx' 'Signing.Certificate'
	Invoke-PragmaTest '#_pragma Resources.meta.deep C:\deep\v' $false 'C:\deep\v' 'Resources.meta.deep'
	# 嵌套 pragma 的根参数必须是哈希表，否则告警 UnknownPragma
	$script:i18nWarnings.Clear()
	$script:GuestMode = $false
	$script:Params = @{}
	[void](Preprocessor @('#_pragma notTable.key value') "C:\compiled\main.ps1")
	if ($script:i18nWarnings -notcontains 'UnknownPragma') { throw "nested pragma with non-hashtable root did not warn: $($script:i18nWarnings -join ',')" }
	Remove-Item Env:\PRAGMA_SECRET -ErrorAction SilentlyContinue

	# 嵌套 #_if：#_endif 必须与最近的 #_if 配对，外层分支不能被内层 #_endif 提前截断；嵌套即有一支死代码，需告警。
	$script:i18nWarnings.Clear()
	$nestedIfResult = Preprocessor @(
		'#_if PSEXE'
		'outer-true'
		'#_if PSScript'
		'inner-false'
		'#_else'
		'inner-true'
		'#_endif'
		'outer-tail'
		'#_else'
		'outer-false'
		'#_endif'
	) 'C:\compiled\main.ps1'
	$nestedIfText = $nestedIfResult -join "`n"
	foreach ($expected in @('outer-true', 'inner-true', 'outer-tail')) {
		if ($nestedIfText -notmatch $expected) { throw "nested #_if dropped '$expected': $nestedIfText" }
	}
	foreach ($unexpected in @('inner-false', 'outer-false')) {
		if ($nestedIfText -match $unexpected) { throw "nested #_if kept '$unexpected': $nestedIfText" }
	}
	if ($script:i18nWarnings -notcontains 'PreprocessNestedIfDeadCode') {
		throw "nested #_if did not warn about dead code, warnings: $($script:i18nWarnings -join ', ')"
	}

	# Const-eval 回退（issue 63）：所有回退路径（超时/超长/异常/显式声明）都必须把 IsConst 置回 $false。否则下游会拿从未赋值的 $RowResult 去走 TinySharp，编出一个只输出空行的哑 exe（默认宿主编译被跳过）。Build.ConstEval.Enabled=0 / Build.ConstEval.Timeout=1 是脚本可用的显式逃生舱，也让本测试无需真的等 7 秒超时。先单测 ConstProgramCheck.ps1 的回退分支，避免为造超时再跑一次完整宿主编译。
	$AstAnalyzeResult = @{ IsConst = $true }
	$noConstEval = $false
	$constEvalTimeout = $true
	. (Join-Path $repoRoot 'src/ConstProgramCheck.ps1')
	if ($AstAnalyzeResult.IsConst) {
		throw 'Build.ConstEval.Timeout left IsConst=$true (issue 63): should fall back to the normal program frame'
	}

	$AstAnalyzeResult = @{ IsConst = $true }
	$noConstEval = $true
	$constEvalTimeout = $false
	. (Join-Path $repoRoot 'src/ConstProgramCheck.ps1')
	if ($AstAnalyzeResult.IsConst) {
		throw 'Build.ConstEval.Enabled=0 left IsConst=$true (issue 63): should skip const eval'
	}

	# 端到端：带逃生舱 pragma 的脚本必须回退成可用的普通宿主 exe（而不是哑 exe），且预处理器不得把它当未知 pragma 报错。
	$constE2ePs1 = Join-Path $buildDir 'const-fallback-e2e.ps1'
	$constE2eExe = Join-Path $buildDir 'const-fallback-e2e.exe'
	Set-Content -LiteralPath $constE2ePs1 -Encoding UTF8 -Value @'
#_pragma Build.ConstEval.Timeout 1
'const-fallback-e2e-ok'
'@
	ps12exe -inputFile $constE2ePs1 -outputFile $constE2eExe | Write-Host
	$constE2e = Invoke-ExeCaptureMergedOutput -ExePath $constE2eExe
	if ($constE2e.Output -notmatch 'const-fallback-e2e-ok') {
		throw "const-eval fallback produced a broken exe (issue 63), got: $($constE2e.Output)"
	}

	# 标准输入按需消费（issue 62）：脚本顶层不用 $input 时，重定向 stdin 不被读取，父进程一直保持管道打开也不会阻塞启动；用到 $input 的脚本仍能收到管道输入。
	$stdinDir = Join-Path $buildDir 'stdin'
	New-Item -ItemType Directory -Path $stdinDir -Force | Out-Null

	$noInputPs1 = Join-Path $stdinDir 'no-input.ps1'
	$noInputExe = Join-Path $stdinDir 'no-input.exe'
	Set-Content -LiteralPath $noInputPs1 -Encoding UTF8 -Value @'
$null = [System.IO.File]::Exists('')
'no-input-ok'
'@
	ps12exe -inputFile $noInputPs1 -outputFile $noInputExe | Write-Host
	$psi = [System.Diagnostics.ProcessStartInfo]::new($noInputExe)
	$psi.RedirectStandardInput = $true
	$psi.RedirectStandardOutput = $true
	$psi.UseShellExecute = $false
	$p = [System.Diagnostics.Process]::Start($psi)
	try {
		if (-not $p.WaitForExit(10000)) {
			throw 'compiled exe blocked on an open redirected stdin even though the script never uses $input (issue 62)'
		}
		$noInputOut = $p.StandardOutput.ReadToEnd()
		if ($noInputOut -notmatch 'no-input-ok') {
			throw "no-input exe output mismatch: $noInputOut"
		}
	}
	finally {
		if (-not $p.HasExited) { Stop-ProcessTree -ProcessId $p.Id }
		$p.Dispose()
	}

	$withInputPs1 = Join-Path $stdinDir 'with-input.ps1'
	$withInputExe = Join-Path $stdinDir 'with-input.exe'
	Set-Content -LiteralPath $withInputPs1 -Encoding UTF8 -Value @'
'input=[' + ((@($input) -join ',')) + ']'
'@
	ps12exe -inputFile $withInputPs1 -outputFile $withInputExe | Write-Host
	$withInputOut = 'a', 'b' | & $withInputExe
	if ("$withInputOut" -notmatch 'input=\[a,b\]') {
		throw "compiled exe did not receive redirected stdin as pipeline input (`$input): $withInputOut"
	}

	# 供 workflow 上传产物：将 exe 拷到仓库根
	Copy-Item -LiteralPath (Join-Path $buildDir 'ps12exe.exe') -Destination (Join-Path $repoRoot 'ps12exe.exe') -Force
}
catch {}
finally {
	Restore-ps12exeContextMenuState -WasEnabled $contextMenuWasEnabled
	Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
}
if ($error) { Write-CIGitHubErrorReport }
Write-Output 'Nice CI!'
