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
		$pwshSource = (Get-Command pwsh).Source
		$secretFile = Join-Path $ctx.WorkDir 'pragma-secret.txt'
		[System.IO.File]::WriteAllText($secretFile, 'secret-value', [System.Text.UTF8Encoding]::new($false))
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

		$script:i18nWarnings.Clear()
		$script:GuestMode = $false
		$script:Params = @{}
		[void](Preprocessor @('#_pragma notTable.key value') "C:\compiled\main.ps1")
		Assert-True ($script:i18nWarnings -contains 'UnknownPragma') "非哈希表根的嵌套 pragma 未告警：$($script:i18nWarnings -join ',')"
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
