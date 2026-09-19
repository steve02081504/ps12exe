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
	Deps  = @('src/SyntaxErrorDataBuilder.ps1', 'src/SyntaxErrorI18nDataGetter.ps1', 'src/SyntaxErrorI18nDataBuilder.ps1')
	Run   = {
		param($ctx)
		$content = "# comment 1`n# comment 2`nfunction {`n# trailing comment"
		$data = & (Join-Path $ctx.RepoRoot 'src/SyntaxErrorI18nDataGetter.ps1') -Content $content -Locale 'en-US'
		Assert-True (@($data).Count -ge 1) '无效脚本应产生语法错误数据'
		$first = @($data)[0]
		Assert-True ([bool]$first.Message) '语法错误缺少 Message'
		Assert-True ($first.Spoce.Line -ge 1) '语法错误缺少行号'
		Assert-True ([bool]$first.ErrorId) '语法错误缺少 ErrorId'
		# 报错应只显示出错那一行，而不是把整个脚本都打出来
		$expectedLine = ($content -split "`n")[$first.Spoce.Line - 1]
		Assert-Equal $expectedLine $first.Text '语法错误应只显示出错行'
	}
}

Add-Test @{
	Name  = 'coverage.build-component-fingerprint'
	Group = 'coverage'
	Deps  = @('tests/lib/common.ps1', 'tests/lib/framework.ps1')
	Run   = {
		param($ctx)
		$root = $ctx.RepoRoot
		$all = @(Get-CompilerInputFiles -RepoRoot $root)
		Assert-True ($all.Count -gt 0) '编译输入为空'
		# 只影响编译期消息/测试运行、不进入产物的文件不得出现在构建指纹里（否则无关改动会打掉全部构建缓存）。
		foreach ($unrelated in @('exe21sp.ps1', 'src/GUI/', 'src/WebServer/', 'src/locale/', 'src/TaskbarProgress.ps1')) {
			$hit = @($all | Where-Object { (Get-NormalizedRelPath -Path $_ -Base $root) -like "$unrelated*" })
			Assert-Equal 0 $hit.Count "构建指纹不应包含无关输入：$unrelated"
		}
		# 各编译器只落在自己的组件里。
		$expect = @{
			'src/CoreCompiler.ps1'      = 'core'
			'src/CodeDomCompiler.ps1'   = 'codeDom'
			'src/TinySharpCompiler.ps1' = 'tinySharp'
		}
		foreach ($rel in $expect.Keys) {
			$owners = @()
			foreach ($c in @('common', 'codeDom', 'tinySharp', 'core', 'ps2exe')) {
				if (@(Get-ComponentInputFiles -RepoRoot $root -Component $c | Where-Object { (Get-NormalizedRelPath -Path $_ -Base $root) -eq $rel }).Count) { $owners += $c }
			}
			Assert-Equal $expect[$rel] ($owners -join ',') "$rel 的组件归属错误"
		}
		# 组件指纹相互独立。
		$coreFp = Get-SourceFingerprint -RepoRoot $root -Components @('common', 'core')
		$winFp = Get-SourceFingerprint -RepoRoot $root -Components @('common', 'codeDom', 'tinySharp')
		Assert-True ($coreFp -ne $winFp) 'Core 与 Windows 组件指纹不应相同'
		# 构建 → 组件映射。
		Assert-True ((Get-BuildFingerprintComponents -Spec @{ Compiler = 'ps12exe'; Params = @{ Build = @{ Target = 'Core' } } }) -contains 'core') 'Core 目标应依赖 core 组件'
		$win = @(Get-BuildFingerprintComponents -Spec @{ Compiler = 'ps12exe' })
		Assert-True ($win -contains 'codeDom' -and $win -contains 'tinySharp' -and $win -notcontains 'core') '非 Core 目标组件映射错误'
		Assert-True ((Get-BuildFingerprintComponents -Spec @{ Compiler = 'ps2exe' }) -contains 'ps2exe') 'ps2exe 兼容层应依赖 ps2exe 组件'
	}
}

Add-Test @{
	Name  = 'coverage.shard-partition'
	Group = 'coverage'
	Deps  = @('tests/lib/framework.ps1')
	Run   = {
		param($ctx)
		$cases = @(Get-AllTestCases)
		$count = 3
		$map = Get-ShardAssignment -Cases $cases -ShardCount $count
		foreach ($c in $cases) {
			$s = $map[$c.Name]
			Assert-True ($s -ge 0 -and $s -lt $count) "用例 $($c.Name) 的分片越界：$s"
		}
		# 三片并集 == 全部用例，且不重不漏。
		$seen = @{}
		$loads = @()
		for ($i = 0; $i -lt $count; $i++) {
			$sel = @(Select-ShardCases -Cases $cases -ShardCount $count -ShardIndex $i -Assignment $map)
			$builds = 0
			foreach ($c in $sel) {
				Assert-False $seen.ContainsKey($c.Name) "用例 $($c.Name) 落在多个分片"
				$seen[$c.Name] = $true
				$builds += @(Get-CaseBuildSpecs -Case $c).Count
			}
			$loads += $builds
		}
		Assert-Equal $cases.Count $seen.Count '分片并集未覆盖全部用例'
		# 贪心均衡：各片构建数差异不应过大。
		$spread = ($loads | Measure-Object -Maximum).Maximum - ($loads | Measure-Object -Minimum).Minimum
		Assert-True ($spread -le 2) "分片构建数不均衡：$($loads -join '/')"
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
			Set-ps12exeContextMenu -action disable -SkipEditorExtension
			Set-ps12exeContextMenu -action disable -SkipEditorExtension
			Assert-False (Test-Path -LiteralPath $key) '未启用时禁用右键菜单应不报错且保持不存在'
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
