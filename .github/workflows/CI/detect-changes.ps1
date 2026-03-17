# 根据变更路径输出需要运行的测试组（JSON 数组），供 CI 增量测试使用。
# 用法: 从 stdin 或 -ChangedPaths 接收相对路径列表；输出 JSON 数组 ["ps12exe","exe21sp","tinysharp"]
# 若未提供变更列表（如 workflow_dispatch 全量），则输出全部组。

param(
	[string[]]$ChangedPaths = @()
)
$ErrorActionPreference = 'Stop'

# 路径模式 -> 测试组。若变更匹配某模式，则需运行对应组。
$pathToGroups = @{
	'ps12exe'   = @(
		'ps12exe.ps1', 'ps12exe.psm1', 'ps12exe.psd1',
		'src/CodeDomCompiler.ps1', 'src/CodeAnalysisCompiler.ps1', 'src/ExeSinker.ps1',
		'src/InitCompileThings.ps1', 'src/ConstProgramCheck.ps1', 'src/ReadScriptFile.ps1',
		'src/GUI/', 'src/Interact/main.ps1', 'src/WebServer/',
		'src/LocaleLoader.ps1', 'src/HelpShower.ps1', 'src/predicate.ps1',
		'.github/workflows/CI/run-ps12exe-tests.ps1'
	)
	'exe21sp'    = @(
		'exe21sp.ps1', 'src/Interact/exe21sp.ps1', 'src/programFrames/exe21sp.cs',
		'.github/workflows/CI/run-exe21sp-tests.ps1'
	)
	'tinysharp'  = @(
		'src/programFrames/TinySharp.cs', 'src/TinySharpCompiler.ps1', 'src/ConstProgramCheck.ps1',
		'.github/workflows/CI/run-tinysharp-tests.ps1'
	)
}

# 反向：组 -> 匹配用的路径前缀/精确
$groupPatterns = @{
	ps12exe   = @('ps12exe.ps1', 'ps12exe.psm1', 'ps12exe.psd1', 'src/CodeDom', 'src/CodeAnalysis', 'src/ExeSinker', 'src/InitCompile', 'src/ConstProgramCheck', 'src/ReadScriptFile', 'src/GUI/', 'src/Interact/main', 'src/WebServer/', 'src/LocaleLoader', 'src/HelpShower', 'src/predicate', '.github/workflows/CI/run-ps12exe')
	exe21sp   = @('exe21sp.ps1', 'src/Interact/exe21sp', 'src/programFrames/exe21sp.cs', '.github/workflows/CI/run-exe21sp')
	tinysharp = @('src/programFrames/TinySharp.cs', 'src/TinySharpCompiler', 'src/ConstProgramCheck', '.github/workflows/CI/run-tinysharp')
}

function PathMatchesGroup($relPath, $group) {
	$relPath = $relPath -replace '\\', '/'
	foreach ($p in $groupPatterns[$group]) {
		if ($relPath -eq $p -or $relPath -like "${p}*") { return $true }
	}
	return $false
}

$groupsToRun = [System.Collections.Generic.HashSet[string]]::new()
if ($ChangedPaths.Count -eq 0) {
	# 从 git 获取变更（CI 中由 env 或传入）
	$baseRef = $env:GITHUB_BASE_REF
	$headRef = $env:GITHUB_SHA
	if ($env:CI_CHANGED_PATHS) {
		$ChangedPaths = $env:CI_CHANGED_PATHS -split "`n" | Where-Object { $_.Trim() }
	} elseif ($baseRef -and $headRef) {
		try {
			$ChangedPaths = git diff --name-only "${baseRef}...${headRef}" 2>$null
			if (-not $ChangedPaths) { $ChangedPaths = git diff --name-only HEAD~1 2>$null }
		} catch {}
	}
}
if ($ChangedPaths.Count -eq 0) {
	# 无变更列表则全量
	$groupsToRun = @('ps12exe', 'exe21sp', 'tinysharp')
} else {
	foreach ($path in $ChangedPaths) {
		$path = $path.Trim() -replace '\\', '/'
		foreach ($group in $groupPatterns.Keys) {
			if (PathMatchesGroup $path $group) { [void]$groupsToRun.Add($group) }
		}
	}
	# 若未匹配任何组则默认跑全量，避免漏测
	if ($groupsToRun.Count -eq 0) { $groupsToRun = @('ps12exe', 'exe21sp', 'tinysharp') }
}

$arr = @($groupsToRun | Sort-Object)
# 保证始终输出 JSON 数组（单元素时 ConvertTo-Json 会变成纯字符串，导致 CI 解析失败）
if ($arr.Count -eq 0) { '[]' }
elseif ($arr.Count -eq 1) { '["' + $arr[0] + '"]' }
else { $arr | ConvertTo-Json -Compress }