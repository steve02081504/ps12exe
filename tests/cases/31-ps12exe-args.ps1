# ps12exe 参数与预处理：PSD 命令行参数、#_pragma 求值、嵌套 #_if、const-eval 回退。
$deps = $script:CoreCompileDeps

Add-Test @{
	Name  = 'ps12exe.args.psd'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'psd'
		Output    = 'psd.exe'
		InputText = @'
param([hashtable]$Config, [int]$N = 0)
"Type=$($Config.GetType().Name) a=$($Config.a) x=$($Config.x) N=$N"
'@
	}
	Run   = {
		param($ctx)
		$psdExe = Copy-BuildAs -BuildPath $ctx.Builds['psd'] -WorkDir $ctx.WorkDir -Name 'psd.exe'
		$out = (Invoke-ExeCaptureMergedOutput -ExePath $psdExe -Arguments @('-Config', "@{a='b'}", '-N', "[int]'42'")).Output
		Assert-Match $out 'Type=Hashtable' "PSD 参数未按哈希表解析：$out"
		Assert-Match $out 'a=b' "PSD 参数 a 丢失：$out"
		Assert-Match $out 'N=42' "PSD 安全类型转换失败：$out"
		$bad = (Invoke-ExeCaptureMergedOutput -ExePath $psdExe -Arguments @('-Config', "@{x=1+1}")).Output
		Assert-NotMatch $bad 'x=2' "PSD 参数被当作 PowerShell 求值了：$bad"
	}
}

Add-Test @{
	Name  = 'ps12exe.pragma.eval'
	Group = 'ps12exe'
	Deps  = $deps
	Run   = {
		param($ctx)
		$script:GuestMode = $false
		$script:Params = @{}
		$script:ParamList = @{
			App           = @{ ParameterType = [hashtable] }
			Os            = @{ ParameterType = [hashtable] }
			Build         = @{ ParameterType = [hashtable] }
			Resources     = @{ ParameterType = [hashtable] }
			Signing       = @{ ParameterType = [hashtable] }
			outputFile    = @{ ParameterType = [string] }
			Golf          = @{ ParameterType = [switch] }
			NoUpdateCheck = @{ ParameterType = [switch] }
		}
		$script:i18nWarnings = [System.Collections.Generic.List[string]]::new()
		function Write-I18n {
			param($PipeLineType, $Mid, $FormatArgs, $Category)
			if ($PipeLineType -eq 'Error') { throw "PragmaError:$Mid" }
			if ($PipeLineType -eq 'Warning') { $script:i18nWarnings.Add($Mid) }
		}
		. (Join-Path $ctx.RepoRoot 'src/ReadScriptFile.ps1')
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
				Assert-True $rejected "pragma 应被拒绝：[$pragma] guest=$guest 得到：$actual"
			}
			else {
				Assert-False $rejected "pragma 应能求值：[$pragma] guest=$guest 被拒绝"
				Assert-Equal $expect "$actual" "pragma 值不符：[$pragma] guest=$guest"
			}
		}
		$userProfileFoo = Join-Path $env:USERPROFILE 'foo.ico'
		$windirFoo = Join-Path $env:windir 'foo.ico'
		$pwshSource = (Get-Command pwsh).Source
		$secretFile = Join-Path $ctx.WorkDir 'pragma-secret.txt'
		[System.IO.File]::WriteAllText($secretFile, 'secret-value', [System.Text.UTF8Encoding]::new($false))
		$env:PRAGMA_SECRET = $secretFile
		# 非访客预处理求值允许读 env；访客只允许白名单 env（windir/SystemRoot），其余拒绝。
		Invoke-PragmaTest '#_pragma Resources.Icon $(Join-Path $env:USERPROFILE "foo.ico")' $false $userProfileFoo
		Invoke-PragmaTest '#_pragma Resources.Icon $(Join-Path $env:USERPROFILE "foo.ico")' $true 'REJECTED'
		Invoke-PragmaTest '#_pragma Resources.Icon $(Join-Path $env:windir "foo.ico")' $true $windirFoo
		Invoke-PragmaTest '#_pragma Resources.Icon $((Get-Command pwsh).Source)' $false $pwshSource
		Invoke-PragmaTest '#_pragma Resources.Icon $((Join-Path $env:USERPROFILE "Foo.ico").ToLower())' $false (Join-Path $env:USERPROFILE 'foo.ico')
		Invoke-PragmaTest '#_pragma Resources.Icon $((Get-Item C:\Windows).Delete())' $false 'REJECTED'
		Invoke-PragmaTest '#_pragma Resources.Icon $(Remove-Item C:\x -Recurse)' $false 'REJECTED'
		Invoke-PragmaTest '#_pragma Resources.Icon "$($global:PSVersionTable.PSVersion)"' $false 'REJECTED'
		Invoke-PragmaTest '#_pragma Resources.Icon $(Get-Content $env:PRAGMA_SECRET)' $false 'secret-value'
		Invoke-PragmaTest '#_pragma Resources.Icon $(Get-Content $env:PRAGMA_SECRET)' $true 'REJECTED'
		Invoke-PragmaTest '#_pragma Resources.Icon $PSScriptRoot/foo.ico' $false 'C:\compiled/foo.ico'
		Invoke-PragmaTest '#_pragma Resources.Title "prefix$(Split-Path $PSScriptRoot -Leaf)suffix"' $false 'prefixcompiledsuffix' 'Resources.Title'
		Invoke-PragmaTest '#_pragma Signing.Certificate C:\cert.pfx' $false 'C:\cert.pfx' 'Signing.Certificate'
		Invoke-PragmaTest '#_pragma Resources.meta.deep C:\deep\v' $false 'C:\deep\v' 'Resources.meta.deep'
		# get-date 是白名单内的只读命令（生成构建时间戳/年份），访客模式同样放行。
		$currentYear = Get-Date -Format yyyy
		Invoke-PragmaTest '#_pragma Resources.Title "$(Get-Date -Format yyyy)"' $false $currentYear 'Resources.Title'
		Invoke-PragmaTest '#_pragma Resources.Title "$(Get-Date -Format yyyy)"' $true $currentYear 'Resources.Title'
		# 只放行 get-date 本身：与其它命令串联时仍被 AST 拦截。
		Invoke-PragmaTest '#_pragma Resources.Icon "$(Get-Date -Format yyyy; Remove-Item C:\x -Recurse)"' $false 'REJECTED'
		# 裸 $env: 引用无需 $(...) 也走安全展开；访客模式仍按 env 白名单（非白名单被拒）。
		Invoke-PragmaTest '#_pragma Resources.Icon $env:windir\foo.ico' $true $windirFoo
		Invoke-PragmaTest '#_pragma Resources.Icon $env:USERPROFILE\foo.ico' $false $userProfileFoo
		Invoke-PragmaTest '#_pragma Resources.Icon $env:USERPROFILE\foo.ico' $true 'REJECTED'
		Invoke-PragmaTest '#_pragma Resources.Title $env:PRAGMA_SECRET' $false $secretFile 'Resources.Title'
		Invoke-PragmaTest '#_pragma Resources.Icon "$env:USERPROFILE\foo.ico"' $false $userProfileFoo
		# 单引号仍是字面量：可保留字面 $env:。
		Invoke-PragmaTest '#_pragma Resources.Title ''$env:VERSION''' $false '$env:VERSION' 'Resources.Title'

		# 访客模式：禁止 pragma 改写 outputFile / Build.TempDir / Build.Minify（写入任意路径 / 注入编译期脚本）与 Signing.Certificate（读本地 PFX / 时间戳 SSRF）。
		$script:i18nWarnings.Clear()
		foreach ($case in @(
				@{ Pragma = '#_pragma outputFile C:\evil.exe'; Name = 'outputFile' },
				@{ Pragma = '#_pragma Build.TempDir C:\evil-temp'; Name = 'Build.TempDir' },
				@{ Pragma = "#_pragma Build.Minify Get-ChildItem"; Name = 'Build.Minify' },
				@{ Pragma = '#_pragma Signing.Certificate C:\evil.pfx'; Name = 'Signing.Certificate' }
			)) {
			$script:GuestMode = $true
			$script:Params = @{}
			[void](Preprocessor @($case.Pragma) "C:\compiled\main.ps1")
			$set = $null
			if ($script:Params.ContainsKey('outputFile')) { $set = $script:Params.outputFile }
			elseif ($script:Params.Build -and $script:Params.Build.ContainsKey('TempDir')) { $set = $script:Params.Build.TempDir }
			elseif ($script:Params.Build -and $script:Params.Build.ContainsKey('Minify')) { $set = $script:Params.Build.Minify }
			elseif ($script:Params.Signing -and $script:Params.Signing.ContainsKey('Certificate')) { $set = $script:Params.Signing.Certificate }
			Assert-True ($null -eq $set) "访客模式下受限 pragma 仍被设置：$($case.Pragma) -> $set"
			Assert-True ($script:i18nWarnings -contains 'PragmaForbiddenInGuestMode') "访客模式下受限 pragma 未告警：$($case.Pragma)"
		}
		# 非访客仍可正常设置（确认没有误伤）
		$script:GuestMode = $false
		$script:Params = @{}
		[void](Preprocessor @('#_pragma Build.TempDir C:\ok-temp') "C:\compiled\main.ps1")
		Assert-Equal 'C:\ok-temp' $script:Params.Build.TempDir '非访客 Build.TempDir 被误伤'

		$script:i18nWarnings.Clear()
		$script:GuestMode = $false
		$script:Params = @{}
		[void](Preprocessor @('#_pragma notTable.key value') "C:\compiled\main.ps1")
		Assert-True ($script:i18nWarnings -contains 'UnknownPragma') "非哈希表根的嵌套 pragma 未告警：$($script:i18nWarnings -join ',')"

		# 开关用真实参数名：`#_pragma Golf 0` 关闭、`#_pragma NoUpdateCheck` 开启。
		$script:Params = @{}
		[void](Preprocessor @('#_pragma Golf') "C:\compiled\main.ps1")
		Assert-Equal $true ([bool]$script:Params.Golf) '`#_pragma Golf` 未开启开关'
		$script:Params = @{}
		[void](Preprocessor @('#_pragma Golf 0') "C:\compiled\main.ps1")
		Assert-Equal $false ([bool]$script:Params.Golf) '`#_pragma Golf 0` 未关闭开关'
		$script:Params = @{}
		[void](Preprocessor @('#_pragma NoUpdateCheck') "C:\compiled\main.ps1")
		Assert-Equal $true ([bool]$script:Params.NoUpdateCheck) '`#_pragma NoUpdateCheck` 未开启开关'

		# 不再支持 `no` 前缀：`#_pragma noGolf` 是未知 pragma，也不会改写 Golf / 映射到 NoUpdateCheck。
		$script:i18nWarnings.Clear()
		$script:Params = @{}
		[void](Preprocessor @('#_pragma noGolf') "C:\compiled\main.ps1")
		Assert-True ($script:i18nWarnings -contains 'UnknownPragma') "`#_pragma noGolf` 未报未知 pragma：$($script:i18nWarnings -join ',')"
		Assert-False $script:Params.ContainsKey('Golf') '`#_pragma noGolf` 不应修改 Golf'
		$script:i18nWarnings.Clear()
		$script:Params = @{}
		[void](Preprocessor @('#_pragma UpdateCheck 0') "C:\compiled\main.ps1")
		Assert-True ($script:i18nWarnings -contains 'UnknownPragma') "`#_pragma UpdateCheck 0` 未报未知 pragma：$($script:i18nWarnings -join ',')"
		Assert-False $script:Params.ContainsKey('NoUpdateCheck') '`#_pragma UpdateCheck 0` 不应映射到 NoUpdateCheck'
		Remove-Item Env:\PRAGMA_SECRET -ErrorAction SilentlyContinue
	}
}

Add-Test @{
	Name  = 'ps12exe.pragma.nested-if'
	Group = 'ps12exe'
	Deps  = $deps
	Run   = {
		param($ctx)
		$script:GuestMode = $false
		$script:Params = @{}
		$script:ParamList = @{ App = @{ ParameterType = [hashtable] }; Os = @{ ParameterType = [hashtable] }; Build = @{ ParameterType = [hashtable] }; Resources = @{ ParameterType = [hashtable] }; Signing = @{ ParameterType = [hashtable] } }
		$script:i18nWarnings = [System.Collections.Generic.List[string]]::new()
		function Write-I18n {
			param($PipeLineType, $Mid, $FormatArgs, $Category)
			if ($PipeLineType -eq 'Error') { throw "PragmaError:$Mid" }
			if ($PipeLineType -eq 'Warning') { $script:i18nWarnings.Add($Mid) }
		}
		. (Join-Path $ctx.RepoRoot 'src/ReadScriptFile.ps1')
		$result = Preprocessor @(
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
		$text = $result -join "`n"
		foreach ($expected in @('outer-true', 'inner-true', 'outer-tail')) { Assert-Match $text ([regex]::Escape($expected)) "嵌套 #_if 丢掉了 $expected" }
		foreach ($unexpected in @('inner-false', 'outer-false')) { Assert-NotMatch $text ([regex]::Escape($unexpected)) "嵌套 #_if 保留了 $unexpected" }
		Assert-True ($script:i18nWarnings -contains 'PreprocessNestedIfDeadCode') "嵌套 #_if 未告警死代码：$($script:i18nWarnings -join ', ')"
	}
}

Add-Test @{
	Name  = 'ps12exe.branch-bang-warnings'
	Group = 'ps12exe'
	Deps  = $deps
	Run   = {
		param($ctx)
		$script:GuestMode = $false
		$script:Params = @{}
		$script:i18nWarnings = [System.Collections.Generic.List[string]]::new()
		function Write-I18n {
			param($PipeLineType, $Mid, $FormatArgs, $Category)
			if ($PipeLineType -eq 'Warning') { $script:i18nWarnings.Add($Mid) }
		}
		. (Join-Path $ctx.RepoRoot 'src/ReadScriptFile.ps1')
		function Get-WarningCount([string]$Mid) { @($script:i18nWarnings | Where-Object { $_ -eq $Mid }).Count }

		# PSEXE 分支会编译进 EXE，其中的普通代码必须带 #_!!；而 PSScript 分支中的 #_!! 在直接运行时会变成注释。
		[void](Preprocessor @(
			'#_if PSEXE'
			'$needsBang = 1'
			'#_!! $escaped = 2'
			'# comment'
			'#_else'
			'$direct = 3'
			'#_!! $wrongBang = 4'
			'#_endif'
		) 'C:\compiled\main.ps1')
		Assert-Equal 1 (Get-WarningCount 'PreprocessPsexeBranchCode') "PSEXE 分支中的普通代码未告警：$($script:i18nWarnings -join ', ')"
		Assert-Equal 1 (Get-WarningCount 'PreprocessPsscriptBranchBang') "PSScript 上下文中的 #_!! 未告警：$($script:i18nWarnings -join ', ')"

		# 嵌套时只有所有外层分支都在编译期选中的行才进入 EXE：内层 PSEXE 仍处于直接运行宿主。
		$script:i18nWarnings.Clear()
		[void](Preprocessor @(
			'#_if PSScript'
			'#_if PSEXE'
			'$inner = 1'
			'#_!! $innerBang = 2'
			'#_endif'
			'#_endif'
		) 'C:\compiled\main.ps1')
		Assert-Equal 0 (Get-WarningCount 'PreprocessPsexeBranchCode') '嵌套在未选中的 PSScript 分支中的 PSEXE 不应要求 #_!!'
		Assert-Equal 1 (Get-WarningCount 'PreprocessPsscriptBranchBang') '嵌套在未选中的 PSScript 分支中的 #_!! 应告警'
	}
}

Add-Test @{
	Name  = 'ps12exe.const-eval.unit'
	Group = 'ps12exe'
	Deps  = $deps
	Run   = {
		param($ctx)
		function Write-I18n { param($PipeLineType, $Mid, $FormatArgs, $Category) }
		$noConsole = $false
		$architecture = 'anycpu'
		$requireAdmin = $false
		$isCoreTarget = $false

		$AstAnalyzeResult = @{ IsConst = $true }
		$noConstEval = $false
		$constEvalTimeout = $true
		. (Join-Path $ctx.RepoRoot 'src/ConstProgramCheck.ps1')
		Assert-False $AstAnalyzeResult.IsConst 'Build.ConstEval.Timeout 未把 IsConst 置回 $false（issue 63）'

		$AstAnalyzeResult = @{ IsConst = $true }
		$noConstEval = $true
		$constEvalTimeout = $false
		. (Join-Path $ctx.RepoRoot 'src/ConstProgramCheck.ps1')
		Assert-False $AstAnalyzeResult.IsConst 'Build.ConstEval.Enabled=0 未跳过常量求值（issue 63）'
	}
}

Add-Test @{
	Name  = 'ps12exe.guest-url-guard'
	Group = 'ps12exe'
	Deps  = @('src/GuestUrlGuard.ps1')
	Run   = {
		param($ctx)
		. (Join-Path $ctx.RepoRoot 'src/GuestUrlGuard.ps1')
		$blocked = @(
			'http://127.0.0.1/x',
			'http://127.1.2.3/x',
			'http://localhost/x',
			'http://foo.localhost/x',
			'http://[::1]/x',
			'http://[::ffff:127.0.0.1]/x',
			'http://0.0.0.0/x',
			'http://10.0.0.1/x',
			'http://172.16.0.1/x',
			'http://172.31.255.255/x',
			'http://192.168.1.1/x',
			'http://169.254.169.254/latest/meta-data/',
			'http://100.64.0.1/x',
			'http://192.0.0.5/x',
			'http://192.0.2.1/x',
			'http://198.18.0.1/x',
			'http://198.51.100.1/x',
			'http://203.0.113.1/x',
			'http://[fe80::1]/x',
			'http://[fc00::1]/x',
			'http://[fd12:3456::1]/x',
			'http://[::192.168.1.1]/x',
			'http://[2002:7f00:1::]/x',
			'http://[2001:0:0:0:0:0:0:1]/x',
			'http://[64:ff9b::c0a8:101]/x',
			'ftp://example.com/x',
			'file:///C:/Windows/win.ini',
			'gopher://example.com/x'
		)
		foreach ($u in $blocked) { Assert-False (Test-GuestUrlAllowed $u) "访客模式应拦截：$u" }
		# 公网字面量 IP 不触发 DNS，避免测试机离线时抖动。
		Assert-True (Test-GuestUrlAllowed 'http://8.8.8.8/x') '公网 IP 应放行：http://8.8.8.8/x'
		Assert-True (Test-GuestUrlAllowed 'https://93.184.216.34/x') '公网 HTTPS IP 应放行'
	}
}

Add-Test @{
	Name  = 'ps12exe.guest-local-path-guard'
	Group = 'ps12exe'
	Deps  = @('src/GuestUrlGuard.ps1')
	Run   = {
		param($ctx)
		. (Join-Path $ctx.RepoRoot 'src/GuestUrlGuard.ps1')
		# 无害的系统图片放行（用系统 ico 的正常需求），其余本地/UNC 一律拒绝。
		Assert-True (Test-GuestLocalFilePathAllowed (Join-Path $env:windir 'System32\foo.ico')) 'Windows 目录下应放行'
		Assert-True (Test-GuestLocalFilePathAllowed (Join-Path $env:SystemRoot 'foo.ico')) 'SystemRoot 下应放行'
		Assert-False (Test-GuestLocalFilePathAllowed (Join-Path $ctx.WorkDir 'foo.ico')) '工作目录应拒绝'
		Assert-False (Test-GuestLocalFilePathAllowed (Join-Path $env:USERPROFILE 'foo.ico')) '用户目录应拒绝'
		Assert-False (Test-GuestLocalFilePathAllowed '\\server\share\foo.ico') 'UNC 应拒绝'
		Assert-False (Test-GuestLocalFilePathAllowed 'C:\WindowsExtra\foo.ico') '与 Windows 同前缀的兄弟目录应拒绝'
		Assert-False (Test-GuestLocalFilePathAllowed '') '空路径应拒绝'
	}
}

Add-Test @{
	Name  = 'ps12exe.icon.from-pe'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'icoext'
		InputText = "Write-Output 'icoext-ok'"
		Params    = @{ Resources = @{ Icon = "$env:windir\System32\shell32.dll,3" } }
		Output    = 'icoext.exe'
	}
	Run   = {
		param($ctx)
		# desktop.ini 风格 "shell32.dll,3"：从 PE 资源抽第 3 个图标并嵌入。
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['icoext']
		Assert-Match $r.Output 'icoext-ok' "带 PE 图标编译的 exe 运行异常：$($r.Output)"
		Add-Type -AssemblyName System.Drawing
		$ico = [System.Drawing.Icon]::ExtractAssociatedIcon($ctx.Builds['icoext'])
		Assert-True ($null -ne $ico) 'PE 图标未嵌入产物'
		if ($ico) { $ico.Dispose() }
	}
}

Add-Test @{
	Name    = 'ps12exe.guest-url-redirect-blocked'
	Group   = 'ps12exe'
	Deps    = @('src/GuestUrlGuard.ps1')
	Timeout = 120
	Run     = {
		param($ctx)
		. (Join-Path $ctx.RepoRoot 'src/GuestUrlGuard.ps1')
		# 重定向目标解析必须拒绝私网/非 http，避免公网主机 302 到内网/云元数据。
		# 全部用公网字面量 IP 作基准，不触发 DNS，避免测试机离线时抖动。
		Assert-Equal '' (Resolve-GuestRedirectLocation 'http://8.8.8.8/a' 'http://127.0.0.1/x') '重定向到 loopback 应被拒绝'
		Assert-Equal '' (Resolve-GuestRedirectLocation 'http://8.8.8.8/a' '//169.254.169.254/latest/meta-data/') '协议相对重定向到云元数据应被拒绝'
		Assert-Equal '' (Resolve-GuestRedirectLocation 'http://8.8.8.8/a' 'ftp://8.8.8.8/x') '重定向到 ftp 应被拒绝'
		Assert-Equal 'http://8.8.8.8/b' (Resolve-GuestRedirectLocation 'http://8.8.8.8/a' 'b') '相对重定向应归一化并放行'
		Assert-Equal 'http://1.1.1.1/x' (Resolve-GuestRedirectLocation 'http://8.8.8.8/a' 'http://1.1.1.1/x') '公网重定向应放行'

		# 端到端：本地服务器 302 到云元数据地址，Invoke-GuestHttpRequest 必须在跟随前拦截。
		$port = Get-Random -Minimum 39000 -Maximum 40000
		$prefix = "http://127.0.0.1:$port/"
		$serverPs1 = Join-Path $ctx.WorkDir 'redirect-server.ps1'
		$serverCode = @'
param($Prefix)
$listener = [System.Net.HttpListener]::new()
$listener.Prefixes.Add($Prefix)
$listener.Start()
try {
	while ($true) {
		$context = $listener.GetContext()
		$context.Response.StatusCode = 302
		$context.Response.RedirectLocation = 'http://169.254.169.254/latest/meta-data/'
		$context.Response.Close()
	}
}
finally { $listener.Stop() }
'@
		[System.IO.File]::WriteAllText($serverPs1, $serverCode, [System.Text.UTF8Encoding]::new($true))
		$pwsh = (Get-Process -Id $PID).Path
		$log = Join-Path $ctx.WorkDir 'redirect-server.log'
		$err = Join-Path $ctx.WorkDir 'redirect-server.err'
		$proc = Start-Process -FilePath $pwsh -ArgumentList @('-NoProfile', '-NonInteractive', '-File', $serverPs1, $prefix) -PassThru -NoNewWindow -RedirectStandardOutput $log -RedirectStandardError $err
		try {
			$ready = $false
			for ($i = 0; $i -lt 40; $i++) {
				Start-Sleep -Milliseconds 250
				if ($proc.HasExited) { break }
				try { $client = [System.Net.Sockets.TcpClient]::new('127.0.0.1', $port); $client.Close(); $ready = $true; break }
				catch {}
			}
			$diag = (Get-Content -LiteralPath $log -Raw -ErrorAction Ignore) + "`n" + (Get-Content -LiteralPath $err -Raw -ErrorAction Ignore)
			Assert-True $ready "重定向测试服务器未启动：$diag"
			$threw = $false
			$msg = ''
			try {
				# Validator 只放行本地起点；重定向目标由真实的 Test-GuestUrlAllowed 校验。
				Invoke-GuestHttpRequest -Url $prefix -Validator { param($u) $u -like 'http://127.0.0.1:*' }
			}
			catch { $threw = $true; $msg = $_.Exception.Message }
			Assert-True $threw 'Invoke-GuestHttpRequest 未拦截重定向'
			Assert-Match $msg 'Blocked redirect' "拦截信息不符：$msg"
		}
		finally {
			if (-not $proc.HasExited) { Stop-ProcessTree -ProcessId $proc.Id }
		}
	}
}

Add-Test @{
	Name  = 'ps12exe.const-classify.env-scope'
	Group = 'ps12exe'
	Deps  = @('src/AstAnalyze.ps1')
	Run   = {
		param($ctx)
		. (Join-Path $ctx.RepoRoot 'src/AstAnalyze.ps1')
		# 读 env 一律不算常量；作用域限定（$global:/$script:）不能绕过 EffectVariables 名单。
		$cases = [ordered]@{
			'Write-Output $env:USERNAME' = $false
			'Write-Output $ENV:windir'   = $false
			'Write-Output $global:PWD'   = $false
			'Write-Output $script:HOME'  = $false
			'Write-Output $HOME'         = $false
			"Write-Output 'hi'"          = $true
		}
		foreach ($code in $cases.Keys) {
			$Tokens = $null
			$Errors = $null
			$Ast = [System.Management.Automation.Language.Parser]::ParseInput($code, [ref]$Tokens, [ref]$Errors)
			$Result = AstAnalyze $Ast
			Assert-Equal $cases[$code] $Result.IsConst "常量判定错误：[$code] IsConst=$($Result.IsConst)"
		}
	}
}

Add-Test @{
	Name  = 'ps12exe.const-eval.fallback-e2e'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'fallback'
		Output    = 'const-fallback-e2e.exe'
		InputText = @'
#_pragma Build.ConstEval.Timeout 1
'const-fallback-e2e-ok'
'@
	}
	Run   = {
		param($ctx)
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['fallback']
		Assert-Match $r.Output 'const-fallback-e2e-ok' "const-eval 回退产出了坏 exe（issue 63）：$($r.Output)"
	}
}

Add-Test @{
	Name  = 'ps12exe.pragma.minify'
	Group = 'ps12exe'
	Deps  = $deps
	Run   = {
		param($ctx)
		# #_pragma Build.Minify 必须真的在本次编译期执行 minifier，不能被参数读取顺序吞掉。
		$marker = Join-Path $ctx.WorkDir 'minify-marker.txt'
		$content = @(
			"#_pragma Build.Minify 'Set-Content -LiteralPath `"$marker`" -Value ran'"
			'Get-Date | Out-Null'
			"Write-Output 'minify-pragma'"
		) -join "`n"
		$src = Join-Path $ctx.WorkDir 'minify.ps1'
		[System.IO.File]::WriteAllText($src, $content, [System.Text.UTF8Encoding]::new($true))
		# -PreprocessOnly 在 minify 之后返回，minifier 的副作用可直接观察。
		$null = ps12exe -inputFile $src -PreprocessOnly -NoUpdateCheck
		Assert-True (Test-Path -LiteralPath $marker) '#_pragma Build.Minify 未在编译期执行'
	}
}

Add-Test @{
	Name  = 'ps12exe.args.core-validation'
	Group = 'ps12exe'
	Deps  = $deps
	Run   = {
		param($ctx)
		$src = Join-Path $ctx.WorkDir 'core-val.ps1'
		[System.IO.File]::WriteAllText($src, "'ok'", [System.Text.UTF8Encoding]::new($true))
		$run = {
			param($extra)
			$out = Join-Path $ctx.WorkDir ('core-val-' + [guid]::NewGuid().ToString('N') + '.exe')
			$global:LastExitCode = 0
			& ps12exe -inputFile $src -outputFile $out -NoUpdateCheck @extra *> $null
			[pscustomobject]@{ Exit = $global:LastExitCode; Exists = (Test-Path -LiteralPath $out) }
		}
		# 高级 Core 选项必须搭配 Backend='Bundled'
		$r = & $run @{ Build = @{ Target = 'Core'; Core = @{ SelfContained = $true } } }
		Assert-Equal 2 $r.Exit 'Shared 后端下的 SelfContained 应报调用错误'
		Assert-False $r.Exists '校验失败不应产出文件'
		# Aot 需要 SelfContained
		$r = & $run @{ Build = @{ Target = 'Core'; Core = @{ Backend = 'Bundled'; Aot = $true } } }
		Assert-Equal 2 $r.Exit 'Aot 缺少 SelfContained 应报调用错误'
		# TrimMode 需要 Trimmed
		$r = & $run @{ Build = @{ Target = 'Core'; Core = @{ Backend = 'Bundled'; TrimMode = 'full' } } }
		Assert-Equal 2 $r.Exit 'TrimMode 缺少 Trimmed 应报调用错误'
		# ConHost 与 Windowed 互斥
		$r = & $run @{ App = @{ Windowed = $true; ConHost = $true } }
		Assert-Equal 2 $r.Exit 'ConHost 与 Windowed 不能共存'
		# Build.Core 在非 Core 目标下被忽略且不报错
		$r = & $run @{ Build = @{ Core = @{ TargetOs = 'Linux' } } }
		Assert-Equal 0 $r.Exit '非 Core 目标的 Build.Core 应被忽略'
		Assert-True $r.Exists '非 Core 目标应正常产出'
	}
}

Add-Test @{
	Name  = 'ps12exe.args.quiet'
	Group = 'ps12exe'
	Deps  = $deps
	Run   = {
		param($ctx)
		$src = Join-Path $ctx.WorkDir 'quiet.ps1'
		[System.IO.File]::WriteAllText($src, "Get-Date | Out-Null; 'quiet-ok'", [System.Text.UTF8Encoding]::new($true))
		$o1 = Join-Path $ctx.WorkDir 'quiet-normal.exe'
		$o2 = Join-Path $ctx.WorkDir 'quiet-quiet.exe'
		$normal = (& ps12exe -inputFile $src -outputFile $o1 -NoUpdateCheck *>&1 | Out-String)
		$quiet = (& ps12exe -inputFile $src -outputFile $o2 -NoUpdateCheck -Quiet *>&1 | Out-String)
		Assert-True (Test-Path -LiteralPath $o2) '-Quiet 编译未产出'
		Assert-True ($quiet.Trim().Length -lt $normal.Trim().Length) "-Quiet 未减少信息输出（normal=$($normal.Trim().Length) quiet=$($quiet.Trim().Length)）"
	}
}

# DarkMode 编译期定死：Off 时 default.cs 里的 DarkMode 类型整段不编译，On/Auto 则编译（Auto 再运行时探测）。
$dmProbe = @'
$exe = [System.Reflection.Assembly]::GetEntryAssembly().Location
$marker = $exe + '.dm'
$darkModeType = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType('PSRunnerNS.DarkMode') } | Where-Object { $_ } | Select-Object -First 1
[System.IO.File]::WriteAllText($marker, $(if ($darkModeType) { 'present' } else { 'absent' }))
'@

Add-Test @{
	Name   = 'ps12exe.app.darkmode'
	Group  = 'ps12exe'
	Deps   = $deps
	Builds = @(
		@{ Name = 'dm_on'; Output = 'dm_on.exe'; Params = @{ App = @{ Windowed = $true; DarkMode = 'On' } }; InputText = $dmProbe }
		@{ Name = 'dm_auto'; Output = 'dm_auto.exe'; Params = @{ App = @{ Windowed = $true; DarkMode = 'Auto' } }; InputText = $dmProbe }
		@{ Name = 'dm_off'; Output = 'dm_off.exe'; Params = @{ App = @{ Windowed = $true; DarkMode = 'Off' } }; InputText = $dmProbe }
	)
	Run    = {
		param($ctx)
		foreach ($name in @('dm_on', 'dm_auto', 'dm_off')) {
			$exe = Copy-BuildAs -BuildPath $ctx.Builds[$name] -WorkDir $ctx.WorkDir -Name "$name.exe"
			$marker = "$exe.dm"
			if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }
			$p = Start-Process -FilePath $exe -PassThru -Wait
			Assert-Equal 0 $p.ExitCode "$name 退出码"
			$value = (Get-Content -LiteralPath $marker -Raw).Trim()
			if ($name -eq 'dm_off') { Assert-Equal 'absent' $value 'DarkMode=Off 仍编译了暗色代码' }
			else { Assert-Equal 'present' $value "$name 未编译暗色代码" }
		}
	}
}

# 开屏不闪：DarkMode=On 时，窗体首次绘制时的背景必须已是暗色（说明染色发生在 WinForms 绘制之前）。
$dmFlashProbe = @'
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
$marker = [System.Reflection.Assembly]::GetEntryAssembly().Location + '.paint'
$form = New-Object System.Windows.Forms.Form
$form.Text = 'darkmode-paint'
$form.Size = New-Object System.Drawing.Size(360, 220)
$script:recorded = $false
$form.Add_Paint({
	# 只记「可见」窗口的首次绘制：不可见时的离屏绘制不算开屏闪。
	if (-not $script:recorded -and $form.Visible) {
		$script:recorded = $true
		[System.IO.File]::WriteAllText($marker, "$($form.BackColor.R),$($form.BackColor.G),$($form.BackColor.B)")
	}
})
$timer = New-Object System.Windows.Forms.Timer
$timer.Interval = 1200
$timer.Add_Tick({ $form.Close() })
$timer.Start()
[System.Windows.Forms.Application]::Run($form)
'@

Add-Test @{
	Name  = 'ps12exe.app.darkmode.no-flash'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'dm_flash'
		Output    = 'dm_flash.exe'
		Params    = @{ App = @{ Windowed = $true; DarkMode = 'On' } }
		InputText = $dmFlashProbe
	}
	Run   = {
		param($ctx)
		$exe = Copy-BuildAs -BuildPath $ctx.Builds['dm_flash'] -WorkDir $ctx.WorkDir -Name 'dm_flash.exe'
		$marker = "$exe.paint"
		if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }
		$process = Start-Process -FilePath $exe -PassThru
		if (-not $process.WaitForExit(30000)) { $process.Kill(); Assert-True $false 'darkmode 窗口未在超时内退出' }
		Assert-True (Test-Path -LiteralPath $marker) '窗体从未绘制（无桌面会话？）'
		$value = (Get-Content -LiteralPath $marker -Raw).Trim()
		Assert-Equal '32,32,32' $value "首次绘制背景不是暗色，开屏会闪一下：$value"
	}
}

# 常量 GUI：所有窗口化常量均走 constexpr 帧，使用同一套 WinForms 对话框和亮/暗调色板。
# 控制台常量脚本仍走 ~1KB 的 TinySharp 壳。
Add-Test @{
	Name   = 'ps12exe.app.darkmode.const'
	Group  = 'ps12exe'
	Deps   = $deps
	Builds = @(
		@{ Name = 'dm_const_on'; Output = 'dm_const_on.exe'; Params = @{ App = @{ Windowed = $true; DarkMode = 'On' } }; InputText = "'const-dm'" }
		@{ Name = 'dm_const_auto'; Output = 'dm_const_auto.exe'; Params = @{ App = @{ Windowed = $true; DarkMode = 'Auto' } }; InputText = "'const-dm'" }
		@{ Name = 'dm_const_off'; Output = 'dm_const_off.exe'; Params = @{ App = @{ Windowed = $true; DarkMode = 'Off' } }; InputText = "'const-dm'" }
		@{ Name = 'dm_const_con_auto'; Output = 'dm_const_con_auto.exe'; Params = @{ App = @{ DarkMode = 'Auto' } }; InputText = "'const-dm'" }
	)
	Run    = {
		param($ctx)
		foreach ($name in @('dm_const_on', 'dm_const_auto')) {
			$text = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($ctx.Builds[$name]))
			Assert-True ($text.Contains('ConstMessageBox')) "$name 是窗口化常量脚本，未走统一渲染的 constexpr 帧"
			Assert-True ($text.Contains('DarkWindowColor')) "$name 未包含暗色调色板"
		}
		$offText = [System.Text.Encoding]::UTF8.GetString([System.IO.File]::ReadAllBytes($ctx.Builds['dm_const_off']))
		Assert-True ($offText.Contains('ConstMessageBox')) 'dm_const_off 未走统一渲染的 constexpr 帧'
		Assert-False ($offText.Contains('DarkWindowColor')) 'DarkMode=Off 的 constexpr 帧不应包含暗色调色板'
		foreach ($name in @('dm_const_con_auto')) {
			$bytes = [System.IO.File]::ReadAllBytes($ctx.Builds[$name])
			$text = [System.Text.Encoding]::UTF8.GetString($bytes)
			Assert-False ($text.Contains('DarkMode')) "$name 不应包含暗色代码（应走 ~1KB 的 TinySharp 壳）"
			Assert-True ($bytes.Length -lt 4096) "$name 体积异常，可能未走 TinySharp：$($bytes.Length)"
		}
	}
}

# 内置对话框：windowed 时始终有统一渲染的 MessageBoxHelper、自绘进度条与可取消的进度窗体；
# 系统按钮本地化对所有主题配置均可用。
$dmDialogProbe = @'
$exe = [System.Reflection.Assembly]::GetEntryAssembly().Location
$marker = $exe + '.dlg'
$names = @('PSRunnerNS.MessageBoxHelper', 'PSRunnerNS.FlatProgressBar', 'PSRunnerNS.IShellProgressDialog')
$lines = foreach ($name in $names) {
	$type = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType($name) } | Where-Object { $_ } | Select-Object -First 1
	$(if ($type) { 'present' } else { 'absent' })
}
$dialogText = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType('PSRunnerNS.SystemDialogText') } | Where-Object { $_ } | Select-Object -First 1
$lines += $(if ($dialogText.GetMethod('GetButtonLabel', [System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::Public)) { 'present' } else { 'absent' })
$ui = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType('PSRunnerNS.PSRunnerUI') } | Where-Object { $_ } | Select-Object -First 1
$formatInputPrompt = $ui.GetMethod('FormatInputPrompt', [System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::NonPublic)
$lines += ([string]$formatInputPrompt.Invoke($null, [object[]]@('Input'))).Replace(' ', '_')
$lines += ([string]$formatInputPrompt.Invoke($null, [object[]]@('Input:'))).Replace(' ', '_')
$helper = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType('PSRunnerNS.MessageBoxHelper') } | Where-Object { $_ } | Select-Object -First 1
$lines += $(if ($helper.GetMethod('ShowLight', [System.Reflection.BindingFlags]::Static -bor [System.Reflection.BindingFlags]::NonPublic)) { 'present' } else { 'absent' })
$progressForm = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType('PSRunnerNS.Progress_Form') } | Where-Object { $_ } | Select-Object -First 1
$lines += $(if ($progressForm.GetConstructor([type[]]@([string], [ConsoleColor], [Action]))) { 'present' } else { 'absent' })
$ui = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType('PSRunnerNS.PSRunnerUI') } | Where-Object { $_ } | Select-Object -First 1
$lines += $(if ($ui.GetField('CancelPipeline', [System.Reflection.BindingFlags]::Instance -bor [System.Reflection.BindingFlags]::Public)) { 'present' } else { 'absent' })
[System.IO.File]::WriteAllText($marker, ($lines -join ','))
'@

Add-Test @{
	Name   = 'ps12exe.app.darkmode.dialogs'
	Group  = 'ps12exe'
	Deps   = $deps
	Builds = @(
		@{ Name = 'dm_dlg_on'; Output = 'dm_dlg_on.exe'; Params = @{ App = @{ Windowed = $true; DarkMode = 'On' } }; InputText = $dmDialogProbe }
		@{ Name = 'dm_dlg_off'; Output = 'dm_dlg_off.exe'; Params = @{ App = @{ Windowed = $true; DarkMode = 'Off' } }; InputText = $dmDialogProbe }
	)
	Run    = {
		param($ctx)
		foreach ($pair in @(@('dm_dlg_on', 'present,present,absent,present,Input:_,Input:_,absent,present,present'), @('dm_dlg_off', 'present,present,absent,present,Input:_,Input:_,absent,present,present'))) {
			$name = $pair[0]; $expected = $pair[1]
			$exe = Copy-BuildAs -BuildPath $ctx.Builds[$name] -WorkDir $ctx.WorkDir -Name "$name.exe"
			$marker = "$exe.dlg"
			if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }
			$process = Start-Process -FilePath $exe -PassThru -Wait
			Assert-Equal 0 $process.ExitCode "$name 退出码"
			$value = (Get-Content -LiteralPath $marker -Raw).Trim()
			Assert-Equal $expected $value "$name 内置对话框类型编译情况不符"
		}
	}
}

Add-Test @{
	Name  = 'ps12exe.app.progress.cancel'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'progress_cancel'
		Output    = 'progress_cancel.exe'
		InputText = "Write-Progress -Activity 'Working' -Status 'Waiting for cancellation'; Start-Sleep -Seconds 30"
		Params    = @{ App = @{ Windowed = $true; DarkMode = 'Off' } }
	}
	Run   = {
		param($ctx)
		$process = Start-Process -FilePath $ctx.Builds['progress_cancel'] -WorkingDirectory $ctx.WorkDir -PassThru
		$clicked = $false
		try {
			$deadline = [DateTime]::UtcNow.AddSeconds(10)
			while (-not $process.HasExited -and [DateTime]::UtcNow -lt $deadline -and -not $clicked) {
				$clicked = [CIWindowHelper]::ClickFirstButtonInProcessMainWindow($process.Id)
				if (-not $clicked) { Start-Sleep -Milliseconds 50 }
			}
			Assert-True $clicked '进度窗体未显示可点击的取消按钮'
			Assert-True ($process.WaitForExit(5000)) '点击进度窗体的取消按钮后流水线仍未停止'
			Assert-Equal 1 $process.ExitCode '取消进度操作的退出码'
		} finally {
			if (-not $process.HasExited) { Stop-ProcessTree -ProcessId $process.Id }
			$process.Dispose()
		}
	}
}

# Auto 跟着系统主题实时切换：只有 Auto（未编译期强制）才带 ThemeChangeWindow 监听 WM_SETTINGCHANGE + ImmersiveColorSet；On 不需要。
$dmLiveProbe = @'
$exe = [System.Reflection.Assembly]::GetEntryAssembly().Location
$marker = $exe + '.live'
$themeChangeWindowType = [AppDomain]::CurrentDomain.GetAssemblies() | ForEach-Object { $_.GetType('PSRunnerNS.DarkMode+ThemeChangeWindow') } | Where-Object { $_ } | Select-Object -First 1
[System.IO.File]::WriteAllText($marker, $(if ($themeChangeWindowType) { 'present' } else { 'absent' }))
'@

Add-Test @{
	Name   = 'ps12exe.app.darkmode.live-switch'
	Group  = 'ps12exe'
	Deps   = $deps
	Builds = @(
		@{ Name = 'dm_live_auto'; Output = 'dm_live_auto.exe'; Params = @{ App = @{ Windowed = $true; DarkMode = 'Auto' } }; InputText = $dmLiveProbe }
		@{ Name = 'dm_live_on'; Output = 'dm_live_on.exe'; Params = @{ App = @{ Windowed = $true; DarkMode = 'On' } }; InputText = $dmLiveProbe }
	)
	Run    = {
		param($ctx)
		foreach ($pair in @(@('dm_live_auto', 'present'), @('dm_live_on', 'absent'))) {
			$name = $pair[0]; $expected = $pair[1]
			$exe = Copy-BuildAs -BuildPath $ctx.Builds[$name] -WorkDir $ctx.WorkDir -Name "$name.exe"
			$marker = "$exe.live"
			if (Test-Path -LiteralPath $marker) { Remove-Item -LiteralPath $marker -Force }
			$process = Start-Process -FilePath $exe -PassThru -Wait
			Assert-Equal 0 $process.ExitCode "$name 退出码"
			$value = (Get-Content -LiteralPath $marker -Raw).Trim()
			Assert-Equal $expected $value "$name 的系统主题监听器编译情况不符"
		}
	}
}
