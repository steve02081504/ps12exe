# 本地 CI：默认按 git diff 增量跑测试；-Full 全量；-RunPs12exe/-RunExe21sp/-RunTinysharp 显式指定要跑的项。
param(
	[switch]$Full,
	[switch]$RunPs12exe,
	[switch]$RunExe21sp,
	[switch]$RunTinysharp
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$env:REPO_ROOT = $repoRoot
$ciDir = Join-Path $repoRoot '.github/workflows/CI'

$runPs12exe = $false
$runExe21sp = $false
$runTinysharp = $false

$anySpecified = $RunPs12exe -or $RunExe21sp -or $RunTinysharp
if ($Full -or (-not $anySpecified)) {
	$runPs12exe = $true
	$runExe21sp = $true
	$runTinysharp = $true
}
if ($anySpecified) {
	if ($RunPs12exe) { $runPs12exe = $true }
	if ($RunExe21sp) { $runExe21sp = $true }
	if ($RunTinysharp) { $runTinysharp = $true }
}

if (-not $Full -and $anySpecified) {
	# 仅跑勾选的项，不再用 git diff
} elseif (-not $Full) {
	# 按 git diff 增量
	$changed = @()
	$diffWorking = git diff --name-only 2>$null
	$diffCached = git diff --name-only --cached 2>$null
	if ($diffWorking) { $changed += $diffWorking }
	if ($diffCached) { $changed += $diffCached }
	$changed = $changed | Sort-Object -Unique | Where-Object { $_.Trim() }
	if ($changed.Count -gt 0) {
		$json = & pwsh -NoProfile -File (Join-Path $ciDir 'detect-changes.ps1') -ChangedPaths $changed
		$arr = $json | ConvertFrom-Json
		if ($arr -isnot [array]) { $arr = @($arr) }
		$runPs12exe = $arr -contains 'ps12exe'
		$runExe21sp = $arr -contains 'exe21sp'
		$runTinysharp = $arr -contains 'tinysharp'
	}
	Write-Output "CI (incremental): RunPs12exe=$runPs12exe RunExe21sp=$runExe21sp RunTinysharp=$runTinysharp"
}

if ($runPs12exe) { & (Join-Path $ciDir 'run-ps12exe-tests.ps1') }
if ($runExe21sp) { & (Join-Path $ciDir 'run-exe21sp-tests.ps1') }
if ($runTinysharp) { & (Join-Path $ciDir 'run-tinysharp-tests.ps1') }
