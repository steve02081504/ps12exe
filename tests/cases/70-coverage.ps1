# 其余可测代码：模块导出、Golf/Sandbox/PreprocessOnly、predicate/PSObjectToString、语法错误数据、WebServer 冒烟。
$deps = $script:CoreCompileDeps

Add-Test @{
	Name  = 'modules.exports'
	Group = 'coverage'
	Deps  = @('ps12exe.psm1', 'ps12exe.psd1', 'src/GUI/', 'src/WebServer/', 'src/Interact/')
	Run   = {
		param($ctx)
		$mod = Import-Module (Join-Path $ctx.RepoRoot 'ps12exe.psd1') -Force -PassThru
		$expected = @('ps12exe', 'ps12exeGUI', 'Set-ps12exeContextMenu', 'Start-ps12exeWebServer', 'Enter-ps12exeInteract', 'exe21sp')
		foreach ($fn in $expected) {
			Assert-True ($null -ne (Get-Command $fn -ErrorAction Ignore)) "模块未导出命令 $fn"
		}
		$exported = @($mod.ExportedFunctions.Keys)
		foreach ($fn in $expected) { Assert-True ($exported -contains $fn) "声明导出的函数缺少 $fn" }
	}
}

Add-Test @{
	Name  = 'ps12exe.preprocess-only'
	Group = 'coverage'
	Deps  = $deps
	Run   = {
		param($ctx)
		$src = Join-Path $ctx.WorkDir 'pre.ps1'
		[System.IO.File]::WriteAllText($src, @'
#_if PSScript
'kept-script'
#_else
'kept-exe'
#_endif
#_pragma Resources.Title 'PreTitle'
'@, [System.Text.UTF8Encoding]::new($true))
		$content = ps12exe -inputFile $src -PreprocessOnly
		Assert-Match "$content" 'kept-exe' 'PreprocessOnly 未保留 PSEXE 分支'
		Assert-NotMatch "$content" 'kept-script' 'PreprocessOnly 未剔除 PSScript 分支'
		Assert-Match "$content" 'PreTitle' 'PreprocessOnly 未保留 pragma'
	}
}

Add-Test @{
	Name  = 'golf.unit'
	Group = 'coverage'
	Deps  = @('src/GolfModeHeader.ps1')
	Run   = {
		param($ctx)
		. (Join-Path $ctx.RepoRoot 'src/GolfModeHeader.ps1')
		Assert-Equal 5 (gcd 10 15) 'gcd 错误'
		Assert-Equal 120 (fac 5) 'fac 错误'
		Assert-Equal 55 (fib 10) 'fib 错误'
		Assert-Equal $true (isprime 7) 'isprime 7 应为真'
		Assert-Equal $false (isprime 8) 'isprime 8 应为假'
		Assert-Equal 'ABC' ($('abc' | up)) 'up 错误'
		Assert-Equal 'aGk=' (b64e 'hi') 'b64e 错误'
		Assert-Equal 'hi' (b64d 'aGk=') 'b64d 错误'
		Assert-Equal 6 ($(@(1, 2, 3) | sum)) 'sum 错误'
		Assert-Equal '1,2,3' ((jo @(1, 2, 3) ',') ) 'jo 错误'
	}
}

Add-Test @{
	Name  = 'golf.compile'
	Group = 'coverage'
	Deps  = $deps
	Build = @{ Name = 'golf'; InputText = "gcd 10 15"; Params = @{ Golf = $true }; Output = 'golf.exe' }
	Run   = {
		param($ctx)
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['golf']
		Assert-Match $r.Output '5' "Golf 模式输出不符：$($r.Output)"
	}
}

Add-Test @{
	Name  = 'sandbox.compile'
	Group = 'coverage'
	Deps  = $deps
	Build = @{ Name = 'sandbox'; InputText = "Get-Date | Out-Null; Write-Output 'sandbox-ok'"; Params = @{ Sandbox = $true }; Output = 'sandbox.exe' }
	Run   = {
		param($ctx)
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['sandbox']
		Assert-Match $r.Output 'sandbox-ok' "Sandbox 模式输出不符：$($r.Output)"
	}
}

Add-Test @{
	Name  = 'units.predicate-psobject'
	Group = 'coverage'
	Deps  = @('src/predicate.ps1', 'src/PSObjectToString.ps1')
	Run   = {
		param($ctx)
		. (Join-Path $ctx.RepoRoot 'src/predicate.ps1')
		foreach ($v in @('on', 'true', 'Y', 'Yes', '1', 'enable', '$true')) { Assert-True (IsEnable $v) "IsEnable 应接受 $v" }
		foreach ($v in @('off', 'false', 'N', 'No', '0', 'disable', '$false')) { Assert-True (IsDisable $v) "IsDisable 应接受 $v" }
		Assert-False (IsEnable 'maybe') "IsEnable 不应接受 maybe"

		. (Join-Path $ctx.RepoRoot 'src/PSObjectToString.ps1')
		Assert-Equal "'a''b'" (PSObjectToString "a'b") '字符串转义错误'
		Assert-Equal 42 (PSObjectToString 42) '整数转换错误'
		Assert-Equal '$true' (PSObjectToString $true) '布尔转换错误'
		$oneLine = PSObjectToString @{ a = 1 } -OneLine
		Assert-Match $oneLine 'a = 1' '哈希表转换错误'
		Assert-Equal '-a:1' (Get-ArgsString @{ a = 1 }) 'Get-ArgsString 错误'
	}
}

Add-Test @{
	Name  = 'units.syntax-error-data'
	Group = 'coverage'
	Deps  = @('src/SyntaxErrorDataBuilder.ps1', 'src/SyntaxErrorI18nDataGetter.ps1')
	Run   = {
		param($ctx)
		$data = & (Join-Path $ctx.RepoRoot 'src/SyntaxErrorI18nDataGetter.ps1') -Content 'function {' -Locale 'en-US'
		Assert-True (@($data).Count -ge 1) '无效脚本应产生语法错误数据'
		$first = @($data)[0]
		Assert-True ([bool]$first.Message) '语法错误缺少 Message'
		Assert-True ($first.Spoce.Line -ge 1) '语法错误缺少行号'
		Assert-True ([bool]$first.ErrorId) '语法错误缺少 ErrorId'
	}
}

Add-Test @{
	Name  = 'webserver.smoke'
	Group = 'coverage'
	Deps  = @('src/WebServer/', 'src/WebServer/main.ps1')
	Timeout = 180
	Run   = {
		param($ctx)
		$port = Get-Random -Minimum 41000 -Maximum 49000
		$url = "http://localhost:$port/"
		$serverPs1 = Join-Path $ctx.WorkDir 'serve.ps1'
		[System.IO.File]::WriteAllText($serverPs1, "Import-Module '$($ctx.RepoRoot)' -Force`nStart-ps12exeWebServer -HostUrl '$url'", [System.Text.UTF8Encoding]::new($true))
		$pwsh = (Get-Process -Id $PID).Path
		$log = Join-Path $ctx.WorkDir 'server.log'
		$err = Join-Path $ctx.WorkDir 'server.err'
		$proc = Start-Process -FilePath $pwsh -ArgumentList @('-NoProfile', '-NonInteractive', '-File', $serverPs1) -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError $err
		try {
			$ok = $false
			for ($i = 0; $i -lt 40; $i++) {
				Start-Sleep -Milliseconds 500
				if ($proc.HasExited) { break }
				try {
					$resp = Invoke-WebRequest -Uri $url -UseBasicParsing -TimeoutSec 3
					if ($resp.StatusCode -ge 200 -and $resp.StatusCode -lt 300) { $ok = $true; break }
				}
				catch {}
			}
			$diag = (Get-Content -LiteralPath $log -Raw -ErrorAction Ignore) + "`n" + (Get-Content -LiteralPath $err -Raw -ErrorAction Ignore)
			Assert-True $ok "WebServer 未在预期时间内响应 $url；日志：$diag"
		}
		finally {
			if (-not $proc.HasExited) { Stop-ProcessTree -ProcessId $proc.Id }
		}
	}
}

Add-Test @{
	Name   = 'contextmenu.toggle'
	Group  = 'coverage'
	Serial = $true
	Deps   = @('src/GUI/ContextMenuAdder.ps1', 'ps12exe.psm1')
	Run    = {
		param($ctx)
		$key = 'Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\ps12exeCompile'
		$wasEnabled = [bool](Test-Path -LiteralPath $key)
		try {
			Set-ps12exeContextMenu -action enable -SkipEditorExtension
			Assert-True (Test-Path -LiteralPath $key) '启用后右键菜单应存在'
			Set-ps12exeContextMenu -action disable -SkipEditorExtension
			Assert-False (Test-Path -LiteralPath $key) '禁用后右键菜单应不存在'
		}
		finally {
			if ($wasEnabled) { Set-ps12exeContextMenu -action enable -SkipEditorExtension }
			else { Set-ps12exeContextMenu -action disable -SkipEditorExtension }
		}
	}
}
