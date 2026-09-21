# ps12exe 端到端：编译、宿主行为、打包、目标框架、CLI 输出。
$deps = $script:CoreCompileDeps

Add-Test @{
	Name  = 'ps12exe.compile.error-clean'
	Group = 'ps12exe'
	Deps  = $deps
	Run   = {
		param($ctx)
		$src = Join-Path $ctx.WorkDir 'error-clean.ps1'
		$out = Join-Path $ctx.WorkDir 'error-clean.exe'
		[System.IO.File]::WriteAllText($src, "Write-Error 'a'; Write-Output 'error-clean'", [System.Text.UTF8Encoding]::new($true))
		$error.Clear()
		ps12exe -inputFile $src -outputFile $out -NoUpdateCheck | Out-Null
		Assert-FileExists $out 'error-clean 编译失败'
		Assert-True ($error.Count -eq 0) "成功编译却污染了 `$error：$($error | Out-String)"
	}
}

Add-Test @{
	Name  = 'ps12exe.self.compile'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{ Name = 'self'; InputFile = (Join-Path (Get-TestRepoRoot) 'ps12exe.ps1'); Output = 'ps12exe.exe' }
	Run   = {
		param($ctx)
		$self = Copy-BuildAs -BuildPath $ctx.Builds['self'] -WorkDir $ctx.WorkDir -Name 'ps12exe-self.exe'
		$src = Join-Path $ctx.WorkDir 'inner.ps1'
		[System.IO.File]::WriteAllText($src, "'self-built-ok'", [System.Text.UTF8Encoding]::new($true))
		$out = Join-Path $ctx.WorkDir 'self-built-inner.exe'
		& $self $src $out -NoUpdateCheck | Out-Null
		Assert-FileExists $out '用自编译的 ps12exe.exe 编译失败'
		$r = Invoke-ExeCaptureMergedOutput -ExePath $out
		Assert-Equal 0 $r.ExitCode 'self-built inner 退出码'
		Assert-Match $r.Output 'self-built-ok' 'self-built inner 输出'
	}
}

Add-Test @{
	Name   = 'ps12exe.host.hello-and-paths'
	Group  = 'ps12exe'
	Deps   = $deps
	Builds = @(
		@{ Name = 'hello'; InputText = "Get-Date | Out-Null; Write-Output 'Hello world!'"; Output = 'hello.exe' }
		@{ Name = 'paths'; InputText = "`$PSCommandPath`n`$PSScriptRoot"; Output = 'paths.exe' }
	)
	Run    = {
		param($ctx)
		$hello = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['hello']
		Assert-Match $hello.Output 'Hello world!' 'hello 输出'

		$pathsExe = Copy-BuildAs -BuildPath $ctx.Builds['paths'] -WorkDir $ctx.WorkDir -Name 'paths.exe'
		$result = @(& $pathsExe)
		$expected = @($pathsExe, $ctx.WorkDir)
		Assert-Equal $expected.Count $result.Count 'paths 行数'
		for ($i = 0; $i -lt $expected.Count; $i++) {
			Assert-Equal ([System.IO.Path]::GetFullPath($expected[$i])) ([System.IO.Path]::GetFullPath($result[$i])) "paths 第 $i 行"
		}
	}
}

Add-Test @{
	Name  = 'ps12exe.pack.size'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{ Name = 'packed'; InputText = "Get-Date | Out-Null; Write-Output 'packed-embed'"; Output = 'packed.exe' }
	Run   = {
		param($ctx)
		$packedSize = (Get-Item -LiteralPath $ctx.Builds['packed']).Length
		Assert-True ($packedSize -lt 25088) "非常量 exe 未按默认压缩负载打包（size=$packedSize）"
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['packed']
		Assert-Match $r.Output 'packed-embed' 'packed 运行输出'
	}
}

Add-Test @{
	Name   = 'ps12exe.pack.resources'
	Group  = 'ps12exe'
	Deps   = $deps
	Builds = @(
		@{
			Name      = 'respack'
			Output    = 'respack.exe'
			InputText = "Get-Date | Out-Null; Write-Output 'respack'"
			Params    = @{ Resources = @{ Title = 'PackTitle'; Version = '1.2.3.4'; Company = 'PackCo' } }
		}
		@{
			Name      = 'resdirect'
			Output    = 'resdirect.exe'
			InputText = "Get-Date | Out-Null; Write-Output 'resdirect'"
			Params    = @{ Resources = @{ Title = 'DirectTitle'; Version = '2.3.4.5' }; Build = @{ KeepSource = $true } }
		}
	)
	Run    = {
		param($ctx)
		$exe = $ctx.Builds['respack']
		# 最终 exe（launcher）携带文件属性
		$vi = (Get-Item -LiteralPath $exe).VersionInfo
		Assert-Equal 'PackTitle' $vi.FileDescription 'launcher 文件说明（AssemblyTitle）'
		Assert-Equal '1.2.3.4' $vi.FileVersion 'launcher 文件版本'
		Assert-Equal 'PackCo' $vi.CompanyName 'launcher 公司名'

		# 反解 launcher 内嵌的 payload：资源/版本属性只在最外层（launcher/直编帧）上；
		# payload 编译把帧里的标记替换为空（窗口标题运行期从 Assembly.GetEntryAssembly() 读，即 launcher）。
		$launcher = [System.Reflection.Assembly]::LoadFile($exe)
		Assert-Equal 1 (@($launcher.GetCustomAttributes([System.Reflection.AssemblyTitleAttribute], $false)).Count) 'launcher 应带 AssemblyTitle'
		$stream = $launcher.GetManifestResourceStream('main')
		Assert-True ($null -ne $stream) 'launcher 缺少 main 资源'
		$gz = [System.IO.Compression.GZipStream]::new($stream, [System.IO.Compression.CompressionMode]::Decompress)
		try {
			$ms = [System.IO.MemoryStream]::new()
			try {
				$gz.CopyTo($ms)
				$payload = [System.Reflection.Assembly]::Load($ms.ToArray())
			}
			finally { $ms.Dispose() }
		}
		finally { $gz.Dispose() }
		Assert-Equal 0 (@($payload.GetCustomAttributes([System.Reflection.AssemblyTitleAttribute], $false)).Count) 'payload 不应带 AssemblyTitle'
		Assert-Equal 0 (@($payload.GetCustomAttributes([System.Reflection.AssemblyFileVersionAttribute], $false)).Count) 'payload 不应带 AssemblyFileVersion'
		Assert-Equal 0 (@($payload.GetCustomAttributes([System.Reflection.AssemblyCompanyAttribute], $false)).Count) 'payload 不应带 AssemblyCompany'

		# 直编（pack 关闭）：属性由自身携带
		$dvi = (Get-Item -LiteralPath $ctx.Builds['resdirect']).VersionInfo
		Assert-Equal 'DirectTitle' $dvi.FileDescription '直编文件说明'
		Assert-Equal '2.3.4.5' $dvi.FileVersion '直编文件版本'
	}
}

Add-Test @{
	Name  = 'ps12exe.host.native-stdout'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{ Name = 'echo'; InputText = "cmd /c echo native-hello"; Output = 'native-echo.exe' }
	Run   = {
		param($ctx)
		$out = & $ctx.Builds['echo']
		Assert-Match "$out" 'native-hello' "宿主 stdout 被管道接走时 native 输出丢失：$out"
	}
}

Add-Test @{
	Name  = 'ps12exe.host.error-order'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{ Name = 'erro'; InputText = "Write-Error 'err-a'; Write-Output 'out-b'"; Output = 'err-order.exe' }
	Run   = {
		param($ctx)
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['erro']
		Assert-True (-not [string]::IsNullOrWhiteSpace($r.Output)) 'err-order 无捕获输出'
		Assert-Match $r.Output '(?s)err-a.*out-b' 'Write-Error 应出现在成功输出之前'
	}
}

Add-Test @{
	Name  = 'ps12exe.host.tty'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'probe'
		Output    = 'tty-probe.exe'
		InputText = @'
$dir = $PSScriptRoot
@{
	hostName = $Host.Name
	inRedirected = [Console]::IsInputRedirected
	outRedirected = [Console]::IsOutputRedirected
} | ConvertTo-Json -Compress | Set-Content -LiteralPath (Join-Path $dir 'host.json') -Encoding UTF8
$childFlag = Join-Path $dir 'child-redirected.txt'
Remove-Item -LiteralPath $childFlag -ErrorAction Ignore
$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
& $powershell -NoProfile -NonInteractive -File (Join-Path $dir 'tty-child.ps1') $childFlag
if ($LASTEXITCODE) { exit $LASTEXITCODE }
'@
	}
	Run   = {
		param($ctx)
		$child = Join-Path $ctx.WorkDir 'tty-child.ps1'
		$childFlag = Join-Path $ctx.WorkDir 'child-redirected.txt'
		$hostJson = Join-Path $ctx.WorkDir 'host.json'
		[System.IO.File]::WriteAllText($child, 'param($flag) [System.IO.File]::WriteAllText($flag, ([Console]::IsOutputRedirected).ToString())', [System.Text.UTF8Encoding]::new($true))
		$probe = Copy-BuildAs -BuildPath $ctx.Builds['probe'] -WorkDir $ctx.WorkDir -Name 'tty-probe.exe'
		$exit = Invoke-ExeWithPrivateConsole -ExePath $probe -WorkingDirectory $ctx.WorkDir
		Assert-Equal 0 $exit "tty probe 退出码"
		$hostInfo = Get-Content -LiteralPath $hostJson -Raw | ConvertFrom-Json
		Assert-False ([bool]$hostInfo.outRedirected) 'tty probe 宿主 stdout 应未重定向（独立 console）'
		$childRedirected = (Get-Content -LiteralPath $childFlag -Raw).Trim()
		Assert-Equal 'False' $childRedirected '独立 console 下 native 子进程 stdout 不应被重定向（issue 59）'
	}
}

Add-Test @{
	Name   = 'ps12exe.host.stdin'
	Group  = 'ps12exe'
	Deps   = $deps
	Builds = @(
		@{ Name = 'noinput'; InputText = "`$null = [System.IO.File]::Exists('')`n'no-input-ok'"; Output = 'no-input.exe' }
		@{ Name = 'withinput'; InputText = "'input=[' + ((@(`$input) -join ',')) + ']'"; Output = 'with-input.exe' }
	)
	Run    = {
		param($ctx)
		$noInputExe = Copy-BuildAs -BuildPath $ctx.Builds['noinput'] -WorkDir $ctx.WorkDir -Name 'no-input.exe'
		$psi = [System.Diagnostics.ProcessStartInfo]::new($noInputExe)
		$psi.RedirectStandardInput = $true
		$psi.RedirectStandardOutput = $true
		$psi.UseShellExecute = $false
		$psi.WorkingDirectory = $ctx.WorkDir
		$p = [System.Diagnostics.Process]::Start($psi)
		try {
			Assert-True ($p.WaitForExit(10000)) '顶层不用 $input 时，重定向 stdin 不应阻塞启动（issue 62）'
			Assert-Match ($p.StandardOutput.ReadToEnd()) 'no-input-ok' 'no-input 输出'
		}
		finally {
			if (-not $p.HasExited) { Stop-ProcessTree -ProcessId $p.Id }
			$p.Dispose()
		}

		$withInputExe = Copy-BuildAs -BuildPath $ctx.Builds['withinput'] -WorkDir $ctx.WorkDir -Name 'with-input.exe'
		$withInputOut = 'a', 'b' | & $withInputExe
		Assert-Match "$withInputOut" 'input=\[a,b\]' "编译后的 exe 未把重定向 stdin 作为管道输入（`$input）：$withInputOut"
	}
}

Add-Test @{
	Name    = 'ps12exe.host.nested'
	Group   = 'ps12exe'
	Deps    = $deps
	Timeout = 900
	Builds  = @(
		@{
			Name = 'okhost'; Output = 'nested-ok-host.exe'
			InputText = @"
Import-Module '$(Get-TestRepoRoot)' -Force
`$Error.Clear()
ps12exe -inputFile (Join-Path `$PSScriptRoot 'inner.ps1') -outputFile (Join-Path `$PSScriptRoot 'inner-ok.exe') -NoUpdateCheck
Write-Host "NESTED_LASTEXITCODE=`$LastExitCode"
Write-Host "NESTED_ERROR_COUNT=`$(`$Error.Count)"
"@
		}
		@{
			Name = 'failhost'; Output = 'nested-fail-host.exe'
			InputText = @"
Import-Module '$(Get-TestRepoRoot)' -Force
`$Error.Clear()
ps12exe -inputFile (Join-Path `$PSScriptRoot 'inner.ps1') -outputFile `$PSCommandPath -NoUpdateCheck
Write-Host "NESTED_LASTEXITCODE=`$LastExitCode"
Write-Host "NESTED_ERROR_COUNT=`$(`$Error.Count)"
`$Error | ForEach-Object { Write-Host "NESTED_ERROR_TEXT: `$_" }
"@
		}
	)
	Run     = {
		param($ctx)
		$inner = Join-Path $ctx.WorkDir 'inner.ps1'
		[System.IO.File]::WriteAllText($inner, "Write-Output 'inner-ok'", [System.Text.UTF8Encoding]::new($true))

		$okHost = Copy-BuildAs -BuildPath $ctx.Builds['okhost'] -WorkDir $ctx.WorkDir -Name 'nested-ok-host.exe'
		$ok = Invoke-ExeCaptureMergedOutput -ExePath $okHost -TimeoutSeconds 600
		Assert-FileExists (Join-Path $ctx.WorkDir 'inner-ok.exe') "嵌套 ps12exe（控制组）未产出 inner exe：$($ok.Output)"
		Assert-Match $ok.Output 'NESTED_LASTEXITCODE=0' "嵌套 ps12exe（控制组）未报告成功：$($ok.Output)"

		$failHost = Copy-BuildAs -BuildPath $ctx.Builds['failhost'] -WorkDir $ctx.WorkDir -Name 'nested-fail-host.exe'
		$fail = Invoke-ExeCaptureMergedOutput -ExePath $failHost -TimeoutSeconds 600
		Assert-Match $fail.Output 'NESTED_LASTEXITCODE=[1-3]' "嵌套自覆盖应以文档化 LastExitCode 失败：$($fail.Output)"
		Assert-Match $fail.Output '(?i)CS0016|being used by another process' "嵌套 ps12exe 吞掉了真实编译失败原因（issue 60）：$($fail.Output)"
	}
}

Add-Test @{
	Name  = 'ps12exe.target.framework20'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{ Name = 'fw20'; InputText = "Write-Error 'a'; Write-Output '123'"; Params = @{ Build = @{ Target = 'Framework2.0' } }; Output = 'fw20.exe' }
	Run   = {
		param($ctx)
		Assert-FileExists $ctx.Builds['fw20'] 'Framework2.0 编译未产出'
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['fw20']
		Assert-Match $r.Output '(?s)a.*123' "Framework2.0 输出不符：$($r.Output)"
	}
}

Add-Test @{
	Name  = 'ps12exe.target.core'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{ Name = 'core'; InputText = "Get-Date | Out-Null; Write-Output 'core-run-ok'"; Params = @{ Build = @{ Target = 'Core' } }; Output = 'core-run.exe' }
	Run   = {
		param($ctx)
		if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core 目标需要 .NET SDK（dotnet）' }
		Assert-FileExists $ctx.Builds['core'] 'Core 编译未产出'
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['core']
		Assert-Match $r.Output 'core-run-ok' "Core 输出不符：$($r.Output)"
	}
}

Add-Test @{
	Name  = 'ps12exe.cli.redirect'
	Group = 'ps12exe'
	Deps  = $deps
	Run   = {
		param($ctx)
		$exe = Join-Path $ctx.WorkDir 'redirect_test.exe'
		$redirectPs1 = Join-Path $ctx.WorkDir 'redirect_test.ps1'
		[System.IO.File]::WriteAllText($redirectPs1, "Write-Output 'redirect-test'", [System.Text.UTF8Encoding]::new($true))
		$expected = [System.IO.Path]::GetFullPath($exe)
		$captured = & (Join-Path $ctx.RepoRoot 'ps12exe.ps1') -inputFile $redirectPs1 -outputFile $exe 2>$null
		Assert-True (-not [string]::IsNullOrWhiteSpace($captured)) "重定向时 stdout 为空（期望路径 $expected）"
		Assert-Equal $expected ([System.IO.Path]::GetFullPath("$captured")) '重定向时 stdout 应只输出 exe 路径'
	}
}

Add-Test @{
	Name  = 'ps12exe.target.core-explicit-tfm'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'coretfm'
		InputText = "Get-Date | Out-Null; Write-Output 'core-tfm-ok'"
		Params    = @{ Build = @{ Target = 'Core'; Core = @{ TargetFramework = "net$([System.Environment]::Version.Major).$([System.Environment]::Version.Minor)" } } }
		Output    = 'core-tfm.exe'
	}
	Run   = {
		param($ctx)
		if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core 目标需要 .NET SDK（dotnet）' }
		Assert-FileExists $ctx.Builds['coretfm'] '显式 TargetFramework 的 Core 编译未产出'
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['coretfm']
		Assert-Match $r.Output 'core-tfm-ok' "显式 TargetFramework 的 Core 输出不符：$($r.Output)"
	}
}

Add-Test @{
	Name  = 'ps12exe.target.core-bundled-const'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'corebundle'
		InputText = "'bundled-const-ok'"
		Params    = @{ Build = @{ Target = 'Core'; Core = @{ Backend = 'Bundled' } } }
		Output    = 'core-bundle.exe'
	}
	Run   = {
		param($ctx)
		if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core 目标需要 .NET SDK（dotnet）' }
		Assert-FileExists $ctx.Builds['corebundle'] 'Bundled 后端常量编译未产出'
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['corebundle']
		Assert-Match $r.Output 'bundled-const-ok' "Bundled 常量输出不符：$($r.Output)"
	}
}

# Shared 单文件：Add-Type 的静态初始化器会去「入口程序集目录\ref」找引用程序集，单文件下入口程序集
# Location 为空；编译器把 $PSHOME\ref 作为内容发布并自解压后才可用（PS2EXE.Core #24）。
Add-Test @{
	Name  = 'ps12exe.core.addtype-singlefile'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'addtype'
		Output    = 'addtype.exe'
		InputText = @'
Add-Type -TypeDefinition 'public static class Ps12exeAddTypeProbe { public static string Get() { return "addtype-ok"; } }'
Write-Output ([Ps12exeAddTypeProbe]::Get())
'@
		Params    = @{ Build = @{ Target = 'Core' } }
	}
	Run   = {
		param($ctx)
		if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core 目标需要 .NET SDK（dotnet）' }
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['addtype']
		Assert-Match $r.Output 'addtype-ok' "Shared 单文件 Add-Type -TypeDefinition 失败：$($r.Output)"
	}
}

# Shared 多文件：ref 目录必须随产物一起落到 exe 旁，否则 Add-Type 找不到引用程序集（PS2EXE.Core #24）。
Add-Test @{
	Name  = 'ps12exe.core.addtype-multifile-ref'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'addtypemulti'
		Output    = 'addtypemulti.exe'
		InputText = @'
Add-Type -TypeDefinition 'public static class Ps12exeAddTypeProbe2 { public static string Get() { return "addtype-multi-ok"; } }'
Write-Output ([Ps12exeAddTypeProbe2]::Get())
'@
		Params    = @{ Build = @{ Target = 'Core'; Core = @{ SingleFile = $false } } }
	}
	Run   = {
		param($ctx)
		if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core 目标需要 .NET SDK（dotnet）' }
		$exe = $ctx.Builds['addtypemulti']
		Assert-True (Test-Path -LiteralPath (Join-Path (Split-Path -Parent $exe) 'ref')) 'Shared 多文件未在 exe 旁发布 ref 引用程序集'
		$r = Invoke-ExeCaptureMergedOutput -ExePath $exe
		Assert-Match $r.Output 'addtype-multi-ok' "Shared 多文件 Add-Type -TypeDefinition 失败：$($r.Output)"
	}
}

# Console 应用用 WinForms/WPF：Shared 下 WPF 会误解析到 .NET Framework GAC 版本，必须显式 UseWPF；
# Bundled 下 WinForms/WPF 都需显式引用（PS2EXE.Core #6）。
Add-Test @{
	Name    = 'ps12exe.core.gui-console-shared'
	Group   = 'ps12exe'
	Deps    = $deps
	Timeout = 900
	Build   = @{
		Name      = 'guishared'
		Output    = 'guishared.exe'
		InputText = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Write-Output ('wf=' + [System.Windows.Forms.Form].FullName)
Write-Output ('wpf=' + [System.Windows.Window].FullName)
'@
		Params    = @{ Build = @{ Target = 'Core' } }
	}
	Run     = {
		param($ctx)
		if (-not $IsWindows) { return }
		if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core 目标需要 .NET SDK（dotnet）' }
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['guishared']
		Assert-Match $r.Output 'wf=System\.Windows\.Forms\.Form' "Shared console 不能用 WinForms：$($r.Output)"
		Assert-Match $r.Output 'wpf=System\.Windows\.Window' "Shared console 不能用 WPF：$($r.Output)"
	}
}

Add-Test @{
	Name    = 'ps12exe.core.gui-console-bundled'
	Group   = 'ps12exe'
	Deps    = $deps
	Timeout = 1800
	Build   = @{
		Name      = 'guibundled'
		Output    = 'guibundled.exe'
		InputText = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName PresentationFramework
Write-Output ('wf=' + [System.Windows.Forms.Form].FullName)
Write-Output ('wpf=' + [System.Windows.Window].FullName)
'@
		Params    = @{ Build = @{ Target = 'Core'; Core = @{ Backend = 'Bundled' } } }
	}
	Run     = {
		param($ctx)
		if (-not $IsWindows) { return }
		if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core 目标需要 .NET SDK（dotnet）' }
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['guibundled']
		Assert-Match $r.Output 'wf=System\.Windows\.Forms\.Form' "Bundled console 不能用 WinForms：$($r.Output)"
		Assert-Match $r.Output 'wpf=System\.Windows\.Window' "Bundled console 不能用 WPF：$($r.Output)"
	}
}
