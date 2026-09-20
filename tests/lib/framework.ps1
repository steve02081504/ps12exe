# 数据驱动测试框架：用例注册、依赖选择、构建去重与缓存键。
$ErrorActionPreference = 'Stop'

$script:RepoRoot = Get-RepoRoot
$script:TestCases = [System.Collections.Generic.List[hashtable]]::new()

# 编译器核心输入：影响「把任意脚本编成 exe」的源文件。用例引用它做增量选择；
# 刻意逐文件枚举而非用 `src/` 前缀，好让未列入的新文件触发「零匹配 -> 全量」安全网。
$script:CoreCompileDeps = @(
	'ps12exe.ps1', 'ps12exe.psm1', 'ps12exe.psd1',
	'src/CodeDomCompiler.ps1', 'src/CoreCompiler.ps1', 'src/TinySharpCompiler.ps1', 'src/BuildFrame.ps1',
	'src/InitCompileThings.ps1', 'src/ConstProgramCheck.ps1', 'src/ReadScriptFile.ps1', 'src/AstAnalyze.ps1',
	'src/ExeSinker.ps1', 'src/GolfModeHeader.ps1', 'src/predicate.ps1', 'src/PSObjectToString.ps1',
	'src/WriteI18n.ps1', 'src/LocaleLoader.ps1', 'src/GuestUrlGuard.ps1',
	'src/OutputCache.ps1', 'src/AsmWarmup.ps1',
	'src/programFrames/', 'src/RuntimePwsh2.0/', 'src/bin/'
)

function Get-TestRepoRoot { return $script:RepoRoot }

function Add-Test {
	param([Parameter(Mandatory)][hashtable]$Descriptor)
	if (-not $Descriptor.Name) { throw 'Add-Test: Name is required' }
	$d = @{
		Name       = [string]$Descriptor.Name
		Group      = if ($Descriptor.Group) { [string]$Descriptor.Group } else { 'misc' }
		Deps       = @($Descriptor.Deps | Where-Object { $_ })
		Build      = $Descriptor.Build
		Builds     = @($Descriptor.Builds | Where-Object { $_ })
		Run        = $Descriptor.Run
		Serial     = [bool]$Descriptor.Serial
		Timeout    = if ($Descriptor.Timeout) { [int]$Descriptor.Timeout } else { 600 }
	}
	if ($d.Build) { $d.Builds = @($d.Build) + $d.Builds }
	[void]$script:TestCases.Add($d)
}

function Get-AllTestCases {
	param([string]$CasesDir)
	if (-not $CasesDir) { $CasesDir = Join-Path $script:RepoRoot 'tests/cases' }
	if (-not (Test-Path -LiteralPath $CasesDir)) { throw "找不到用例目录：$CasesDir" }
	# 幂等：重复调用时先清空，避免用例被叠加注册。
	$script:TestCases = [System.Collections.Generic.List[hashtable]]::new()
	Get-ChildItem -LiteralPath $CasesDir -Filter '*.ps1' -File | Sort-Object Name | ForEach-Object { . $_.FullName }
	return $script:TestCases
}

# 归一化某个用例的构建清单，返回 @( @{ Name; Spec } )。
function Get-CaseBuildSpecs {
	param([hashtable]$Case)
	$result = @()
	$i = 0
	foreach ($b in @($Case.Builds)) {
		if (-not $b) { continue }
		$name = if ($b.Name) { [string]$b.Name } else { "build$i" }
		$result += , @{ Name = $name; Spec = $b }
		$i++
	}
	return $result
}

function Get-ArgKeyText {
	param($Value)
	if ($null -eq $Value) { return '$null' }
	if ($Value -is [hashtable]) {
		$pairs = $Value.Keys | Sort-Object | ForEach-Object { "$_=$(Get-ArgKeyText $Value[$_])" }
		return '{' + ($pairs -join ',') + '}'
	}
	if ($Value -is [System.Collections.IEnumerable] -and $Value -isnot [string]) {
		return '[' + ((@($Value) | ForEach-Object { Get-ArgKeyText $_ }) -join ',') + ']'
	}
	return [string]$Value
}

function Get-BuildKey {
	param([string]$Fingerprint, [hashtable]$Spec)
	$inputHash = ''
	if ($null -ne $Spec.InputText) { $inputHash = Get-StringHash ([string]$Spec.InputText) }
	elseif ($Spec.InputFile) {
		$p = [string]$Spec.InputFile
		if (-not [System.IO.Path]::IsPathRooted($p)) { $p = Join-Path $script:RepoRoot $p }
		if (Test-Path -LiteralPath $p) { $inputHash = Get-StringHash ([System.IO.File]::ReadAllText($p)) }
		else { $inputHash = "missing:$p" }
	}
	$inputId = if ($Spec.InputFile) { Get-NormalizedRelPath -Path ([string]$Spec.InputFile) -Base $script:RepoRoot } else { 'inline' }
	$paramsText = ''
	if ($Spec.Params) {
		$paramsText = (($Spec.Params.Keys | Sort-Object) | ForEach-Object { "$_=$(Get-ArgKeyText $Spec.Params[$_])" }) -join ';'
	}
	$envText = ''
	if ($Spec.Env) {
		$envText = (($Spec.Env.Keys | Sort-Object) | ForEach-Object { "$_=$($Spec.Env[$_])" }) -join ';'
	}
	$out = if ($Spec.Output) { [string]$Spec.Output } else { 'out.exe' }
	$compiler = if ($Spec.Compiler) { [string]$Spec.Compiler } else { 'ps12exe' }
	$raw = "fp=$Fingerprint|compiler=$compiler|inputId=$inputId|input=$inputHash|params=$paramsText|env=$envText|out=$out"
	return (Get-StringHash $raw).Substring(0, 24)
}

# 一个构建的缓存键只依赖它真正用到的编译组件。Core 目标走 CoreCompiler；
# 其余（含 TinySharp 常量壳、Framework2.0/4.0）都走 CodeDom/TinySharp；ps2exe 兼容层再加 shim。
function Get-BuildFingerprintComponents {
	param([hashtable]$Spec)
	$names = [System.Collections.Generic.List[string]]::new()
	$names.Add('common')
	$target = ''
	if ($Spec.Params -and $Spec.Params['Build'] -and $Spec.Params['Build']['Target']) {
		$target = [string]$Spec.Params['Build']['Target']
	}
	if ($Spec.Compiler -eq 'ps2exe') {
		$names.Add('codeDom'); $names.Add('tinySharp'); $names.Add('ps2exe')
	}
	elseif ($target -eq 'Core') {
		$names.Add('core')
	}
	else {
		$names.Add('codeDom'); $names.Add('tinySharp')
	}
	return @($names)
}

# 全量用例的分片归属：按「构建数」贪心均衡到各片。基于全部用例（而非本次选中集）计算，
# 因此同一用例的分片是稳定的，分片缓存可跨 run 复用；纯测试用例按权重 1 参与均衡。
function Get-ShardAssignment {
	param([array]$Cases, [int]$ShardCount)
	if ($ShardCount -le 1) {
		$single = @{}
		foreach ($c in $Cases) { $single[$c.Name] = 0 }
		return $single
	}
	$load = New-Object 'int[]' $ShardCount
	$map = @{}
	$ordered = @($Cases | Sort-Object @{ Expression = { @(Get-CaseBuildSpecs -Case $_).Count }; Descending = $true }, @{ Expression = { $_.Name } })
	foreach ($c in $ordered) {
		$weight = @(Get-CaseBuildSpecs -Case $c).Count
		if ($weight -lt 1) { $weight = 1 }
		$target = 0
		for ($i = 1; $i -lt $ShardCount; $i++) { if ($load[$i] -lt $load[$target]) { $target = $i } }
		$map[$c.Name] = $target
		$load[$target] += $weight
	}
	return $map
}

function Select-ShardCases {
	param([array]$Cases, [int]$ShardCount, [int]$ShardIndex, [hashtable]$Assignment)
	if ($ShardCount -le 1) { return @($Cases) }
	if (-not $Assignment) { $Assignment = Get-ShardAssignment -Cases $Cases -ShardCount $ShardCount }
	return @($Cases | Where-Object { $Assignment[$_.Name] -eq $ShardIndex })
}

function Test-DepMatchesPath {
	param([string]$RelPath, [string]$Dep)
	$Dep = $Dep -replace '\\', '/'
	if ($Dep.EndsWith('/')) { return $RelPath.StartsWith($Dep, [System.StringComparison]::OrdinalIgnoreCase) }
	if ($Dep -like '*`**') { return $RelPath -like $Dep }
	return $RelPath -eq $Dep
}

# 测试基础设施变更（tests/ 或 workflow）时全量；否则按 Deps 选择。
function Get-AffectedCases {
	param([array]$Cases, [string[]]$ChangedPaths, [string]$RepoRoot)
	$changed = @($ChangedPaths | Where-Object { $_ } | ForEach-Object {
		($_.Trim() -replace '\\', '/').TrimStart('./')
	})
	if ($changed.Count -eq 0) { return @($Cases) }

	$infraChanged = $changed | Where-Object { $_ -like 'tests/*' -or $_ -like '.github/workflows/*' }
	if ($infraChanged) { return @($Cases) }

	$selected = @()
	$matched = @()
	foreach ($c in $Cases) {
		if (@($c.Deps).Count -eq 0) { $selected += , $c; continue }
		$hit = $false
		foreach ($path in $changed) {
			foreach ($dep in $c.Deps) {
				if (Test-DepMatchesPath -RelPath $path -Dep $dep) { $hit = $true; break }
			}
			if ($hit) { break }
		}
		if ($hit) { $selected += , $c; $matched += , $c }
	}

	if ($matched.Count -eq 0) {
		$productRoots = @('ps12exe.ps1', 'ps12exe.psm1', 'ps12exe.psd1', 'exe21sp.ps1', 'src/')
		$productChanged = $changed | Where-Object {
			$p = $_
			@($productRoots | Where-Object { $p -eq $_ -or $p.StartsWith($_, [System.StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
		}
		# 改了产品源码却没有用例声明依赖它，属于用例映射缺口，保守全量。
		if ($productChanged) { return @($Cases) }
	}
	return @($selected)
}

function Get-GitChangedPaths {
	param([string]$RepoRoot)
	Push-Location -LiteralPath $RepoRoot
	try {
		# 本地优先看未提交改动（含未跟踪文件）；干净时才看最后一次提交。
		$paths = @(git diff --name-only HEAD 2>$null)
		$paths += @(git ls-files --others --exclude-standard 2>$null)
		$paths = @($paths | Where-Object { $_ })
		if (-not $paths) { $paths = @(git diff --name-only 'HEAD~1' 2>$null) }
		return @($paths | Where-Object { $_ })
	}
	finally { Pop-Location }
}
