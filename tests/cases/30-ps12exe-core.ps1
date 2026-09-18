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
	Name  = 'ps12exe.host.hello-and-paths'
	Group = 'ps12exe'
	Deps  = $deps
	Builds = @(
		@{ Name = 'hello'; InputText = "Get-Date | Out-Null; Write-Output 'Hello world!'"; Output = 'hello.exe' }
		@{ Name = 'paths'; InputText = "`$PSCommandPath`n`$PSScriptRoot"; Output = 'paths.exe' }
	)
	Run   = {
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
	}
	Run   = {
		param($ctx)
		$child = Join-Path $ctx.WorkDir 'tty-child.ps1'
		$childFlag = Join-Path $ctx.WorkDir 'child-redirected.txt'
		$hostJson = Join-Path $ctx.WorkDir 'host.json'
		[System.IO.File]::WriteAllText($child, '[System.IO.File]::WriteAllText($env:PS12EXE_TTY_CHILD, ([Console]::IsOutputRedirected).ToString())', [System.Text.UTF8Encoding]::new($true))
		$probe = Copy-BuildAs -BuildPath $ctx.Builds['probe'] -WorkDir $ctx.WorkDir -Name 'tty-probe.exe'
		$env:PS12EXE_TTY_CHILD = $childFlag
		$env:PS12EXE_TTY_HOST = $hostJson
		$env:PS12EXE_TTY_CHILD_PS1 = $child
		$exit = Invoke-ExeWithPrivateConsole -ExePath $probe -WorkingDirectory $ctx.WorkDir
		Assert-Equal 0 $exit "tty probe 退出码"
		$hostInfo = Get-Content -LiteralPath $hostJson -Raw | ConvertFrom-Json
		Assert-False ([bool]$hostInfo.outRedirected) 'tty probe 宿主 stdout 应未重定向（独立 console）'
		$childRedirected = (Get-Content -LiteralPath $childFlag -Raw).Trim()
		Assert-Equal 'False' $childRedirected '独立 console 下 native 子进程 stdout 不应被重定向（issue 59）'
	}
}

Add-Test @{
	Name  = 'ps12exe.host.stdin'
	Group = 'ps12exe'
	Deps  = $deps
	Builds = @(
		@{ Name = 'noinput'; InputText = "`$null = [System.IO.File]::Exists('')`n'no-input-ok'"; Output = 'no-input.exe' }
		@{ Name = 'withinput'; InputText = "'input=[' + ((@(`$input) -join ',')) + ']'"; Output = 'with-input.exe' }
	)
	Run   = {
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
	Name  = 'ps12exe.host.nested'
	Group = 'ps12exe'
	Deps  = $deps
	Timeout = 900
	Builds = @(
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
	Run   = {
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
