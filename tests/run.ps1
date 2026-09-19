# ps12exe 统一测试入口。
#   pwsh tests/run.ps1                     # 按改动增量（本地无改动则跑 HEAD~1 的 diff；无 git 则全量）
#   pwsh tests/run.ps1 -All                # 全量
#   pwsh tests/run.ps1 -ChangedPathsFile changed.txt
#   pwsh tests/run.ps1 -Filter '*exe21sp*' -List
#   pwsh tests/run.ps1 -Group ps12exe -NoCache
#   pwsh tests/run.ps1 -PrintFingerprint    # 仅输出源码指纹（CI 缓存键用）
param(
	[string[]]$ChangedPaths = @(),
	[string]$ChangedPathsFile,
	[string[]]$Filter = @(),
	[string[]]$Group = @(),
	[switch]$All,
	[switch]$List,
	[switch]$NoCache,
	[int]$ThrottleLimit = 0,
	[int]$BuildThrottleLimit = 0,
	[int]$ShardCount = 1,
	[int]$ShardIndex = 0,
	[int]$TimeoutSeconds = 0,
	[switch]$KeepWorkDir,
	[switch]$PrintFingerprint
)
$ErrorActionPreference = 'Stop'
$script:AnyFailed = $false
$Filter = @($Filter | ForEach-Object { $_ -split ',' } | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })
$Group = @($Group | ForEach-Object { $_ -split ',' } | Where-Object { $_.Trim() } | ForEach-Object { $_.Trim() })

$libDir = Join-Path $PSScriptRoot 'lib'
. (Join-Path $libDir 'common.ps1')

# CI 用：输出编译输入指纹，供 actions/cache 键与构建缓存键同源（避免手写 hashFiles 列表漂移）。
# 只依赖 common.ps1，尽早退出以省去 exec/assert/framework 的加载开销。
if ($PrintFingerprint) {
	Write-Output (Get-SourceFingerprint -RepoRoot (Get-RepoRoot))
	exit 0
}

. (Join-Path $libDir 'exec.ps1')
. (Join-Path $libDir 'assert.ps1')
. (Join-Path $libDir 'framework.ps1')

$repoRoot = Get-TestRepoRoot
$env:REPO_ROOT = $repoRoot

$cases = @(Get-AllTestCases)

# ---- 变更解析与选择 ----
if ($ChangedPathsFile -and (Test-Path -LiteralPath $ChangedPathsFile)) {
	$fromFile = @(Get-Content -LiteralPath $ChangedPathsFile | Where-Object { $_.Trim() })
	if ($fromFile.Count) { $ChangedPaths = $fromFile }
}
if ($All) {
	$selected = @($cases)
	$selectionReason = 'all'
}
else {
	if (-not $ChangedPaths -or $ChangedPaths.Count -eq 0) { $ChangedPaths = @(Get-GitChangedPaths -RepoRoot $repoRoot) }
	if (-not $ChangedPaths -or $ChangedPaths.Count -eq 0) {
		$selected = @($cases)
		$selectionReason = 'no changes detected -> all'
	}
	else {
		$selected = @(Get-AffectedCases -Cases $cases -ChangedPaths $ChangedPaths -RepoRoot $repoRoot)
		$selectionReason = "changed: $($ChangedPaths.Count) path(s)"
	}
}
if ($Group) { $selected = @($selected | Where-Object { $Group -contains $_.Group }) }
if ($Filter) {
	$selected = @($selected | Where-Object {
		$name = $_.Name
		@($Filter | Where-Object { $name -like $_ }).Count -gt 0
	})
}

# 分片：CI 用 matrix 把用例拆到多个 runner 上并行，理论上限由最慢的一片决定。
if ($ShardCount -lt 1) { throw "ShardCount 必须 >= 1（当前 $ShardCount）" }
if ($ShardIndex -lt 0 -or $ShardIndex -ge $ShardCount) { throw "ShardIndex 必须落在 [0, $ShardCount)（当前 $ShardIndex）" }
if ($ShardCount -gt 1) {
	# 基于全部用例计算分片归属，保证同一用例跨 run 落在同一片（分片缓存可复用）。
	$shardAssignment = Get-ShardAssignment -Cases $cases -ShardCount $ShardCount
	$selected = @(Select-ShardCases -Cases $selected -ShardCount $ShardCount -ShardIndex $ShardIndex -Assignment $shardAssignment)
	$selectionReason += "（分片 $ShardIndex/$ShardCount）"
}

if ($List) {
	Write-Output "用例（$($selected.Count)/$($cases.Count)），选择依据：$selectionReason"
	foreach ($c in $selected) {
		Write-Output ("  {0,-10} {1,-42} deps={2}" -f $c.Group, $c.Name, (@($c.Deps) -join ','))
	}
	exit 0
}

if ($selected.Count -eq 0) {
	Write-Output "没有需要运行的用例（$selectionReason）。"
	exit 0
}

$cacheRoot = Join-Path $PSScriptRoot '.cache'
$buildCacheDir = Join-Path $cacheRoot 'builds'
$jobsDir = Join-Path $cacheRoot 'jobs'
$workRoot = Join-Path $cacheRoot 'work'
foreach ($d in @($cacheRoot, $buildCacheDir, $jobsDir, $workRoot)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }

$pwshExe = (Get-Process -Id $PID).Path
if (-not $pwshExe) { $pwshExe = (Get-Command pwsh).Source }
$workerPs1 = Join-Path $libDir 'worker.ps1'
# 测试并发保持保守（GUI/私有控制台等用例对并发敏感）；构建并发可适当超订以掩盖
# 进程创建/杀毒扫描/dotnet publish 的 I/O 等待，默认取 CPU 的约 2 倍、上限 8。
$cpuCount = [Environment]::ProcessorCount
$throttle = if ($ThrottleLimit -gt 0) { $ThrottleLimit } else { [Math]::Max(1, [Math]::Min($cpuCount, 4)) }
$buildThrottle = if ($BuildThrottleLimit -gt 0) { $BuildThrottleLimit }
elseif ($ThrottleLimit -gt 0) { $ThrottleLimit }
else { [Math]::Max($throttle, [Math]::Min($cpuCount * 2, 8)) }

function New-JobFiles {
	param([string]$Prefix)
	$id = "$Prefix-" + [guid]::NewGuid().ToString('N')
	return @{
		JobFile    = Join-Path $jobsDir "$id.job.json"
		ResultFile = Join-Path $jobsDir "$id.result.json"
		LogFile    = Join-Path $jobsDir "$id.log.txt"
		ErrFile    = Join-Path $jobsDir "$id.err.txt"
	}
}

function Invoke-WorkerJobs {
	param([array]$Jobs, [int]$Throttle)
	$results = @()
	if (-not $Jobs -or $Jobs.Count -eq 0) { return $results }
	$queue = [System.Collections.Generic.Queue[object]]::new()
	foreach ($j in $Jobs) { $queue.Enqueue($j) }
	$running = @()
	$total = $Jobs.Count
	$done = 0
	while ($queue.Count -gt 0 -or $running.Count -gt 0) {
		while ($running.Count -lt $Throttle -and $queue.Count -gt 0) {
			$j = $queue.Dequeue()
			$j.Started = [DateTime]::UtcNow
			$argsStr = '-NoProfile -NonInteractive -File "{0}" -Mode {1} -JobFile "{2}" -ResultFile "{3}"' -f $workerPs1, $j.Mode, $j.JobFile, $j.ResultFile
			$j.Proc = Start-Process -FilePath $pwshExe -ArgumentList $argsStr -PassThru -NoNewWindow -RedirectStandardOutput $j.LogFile -RedirectStandardError $j.ErrFile
			$running += , $j
		}
		Start-Sleep -Milliseconds 120
		foreach ($j in @($running)) {
			$exited = $false
			try { $exited = $j.Proc.HasExited } catch { $exited = $true }
			if ($exited) {
				$running = @($running | Where-Object { $_ -ne $j })
				$done++
				$res = Read-JsonFile -Path $j.ResultFile
				if (-not $res) { $res = [pscustomobject]@{ Success = $false; Error = 'worker 未产出结果文件'; Stack = $null; Assertions = 0 } }
				$results += , @{ Job = $j; Result = $res }
				Write-Host ("  [{0}/{1}] {2}" -f $done, $total, $j.Label)
			}
			elseif ((([DateTime]::UtcNow - $j.Started).TotalSeconds) -gt $j.Timeout) {
				Stop-ProcessTree -ProcessId $j.Proc.Id
				$running = @($running | Where-Object { $_ -ne $j })
				$done++
				$results += , @{ Job = $j; Result = [pscustomobject]@{ Success = $false; Error = "超时 $($j.Timeout)s"; Stack = $null; Assertions = 0 } }
				Write-Host ("  [{0}/{1}] {2} (timeout)" -f $done, $total, $j.Label)
			}
		}
	}
	return $results
}

function Get-JobLog {
	param($Job)
	$text = ''
	foreach ($f in @($Job.LogFile, $Job.ErrFile)) {
		if ($f -and (Test-Path -LiteralPath $f)) { $text += (Get-Content -LiteralPath $f -Raw -ErrorAction SilentlyContinue) + "`n" }
	}
	return $text
}

# ---- 构建阶段：内容哈希去重 + 缓存 ----
# 每个构建按自身依赖的组件算指纹：改 CoreCompiler 不会连带失效 CodeDom/TinySharp 构建。
$fingerprintCache = @{}
function Get-SpecFingerprint([hashtable]$Spec) {
	$names = @(Get-BuildFingerprintComponents -Spec $Spec)
	$id = $names -join '+'
	if (-not $fingerprintCache.ContainsKey($id)) {
		$fingerprintCache[$id] = Get-SourceFingerprint -RepoRoot $repoRoot -Components $names
	}
	return $fingerprintCache[$id]
}
$buildPlan = @{}
foreach ($c in $selected) {
	$c.BuildMap = @{}
	foreach ($entry in (Get-CaseBuildSpecs -Case $c)) {
		$key = Get-BuildKey -Fingerprint (Get-SpecFingerprint -Spec $entry.Spec) -Spec $entry.Spec
		$c.BuildMap[$entry.Name] = $key
		if (-not $buildPlan.ContainsKey($key)) {
			$outputName = if ($entry.Spec.Output) { [string]$entry.Spec.Output } else { 'out.exe' }
			$outputDir = Join-Path $buildCacheDir $key
			$buildPlan[$key] = @{
				Key        = $key
				CaseName   = $c.Name
				BuildName  = $entry.Name
				OutputDir  = $outputDir
				OutputName = $outputName
			}
		}
	}
}

$buildOutputs = @{}
$buildJobs = @()
$cachedCount = 0
foreach ($key in $buildPlan.Keys) {
	$bp = $buildPlan[$key]
	$outPath = Join-Path $bp.OutputDir $bp.OutputName
	$okMarker = Join-Path $bp.OutputDir '.ok'
	if (-not $NoCache -and (Test-Path -LiteralPath $okMarker) -and (Test-Path -LiteralPath $outPath)) {
		$buildOutputs[$key] = $outPath
		$cachedCount++
		continue
	}
	if (Test-Path -LiteralPath $bp.OutputDir) { Remove-Item -LiteralPath $bp.OutputDir -Recurse -Force -ErrorAction SilentlyContinue }
	$files = New-JobFiles -Prefix "build-$($key.Substring(0,8))"
	Write-JsonFile -Path $files.JobFile -Object @{ Key = $key; CaseName = $bp.CaseName; BuildName = $bp.BuildName; OutputDir = $bp.OutputDir }
	$files.Mode = 'Build'
	$files.Label = "build $($bp.CaseName)/$($bp.BuildName)"
	$files.Timeout = if ($TimeoutSeconds -gt 0) { $TimeoutSeconds } else { 900 }
	$files.Key = $key
	$files.OutputName = $bp.OutputName
	$files.OutputDir = $bp.OutputDir
	$buildJobs += , $files
}

if ($buildJobs.Count) {
	Write-Host "== 构建阶段：$($buildJobs.Count) 个构建（缓存命中 $cachedCount，并行度 $buildThrottle）=="
	$buildResults = Invoke-WorkerJobs -Jobs $buildJobs -Throttle $buildThrottle
	foreach ($br in $buildResults) {
		$j = $br.Job
		if ($br.Result.Success) {
			Write-TextFileNoBom -Path (Join-Path $j.OutputDir '.ok') -Text $j.Key
			$buildOutputs[$j.Key] = Join-Path $j.OutputDir $j.OutputName
		}
		else {
			$script:AnyFailed = $true
			Write-Output "::error title=BUILD $($j.Label)::$($br.Result.Error)"
			Write-Output "构建失败：$($j.Label) -> $($br.Result.Error)"
			$log = (Get-JobLog -Job $j)
			if ($log) { Write-Output (($log -split "`r?`n" | Select-Object -Last 60) -join "`n") }
		}
	}
}
elseif ($cachedCount) {
	Write-Host "== 构建阶段：全部命中缓存（$cachedCount）=="
}

# ---- 测试阶段 ----
$testJobs = @()
$serialCases = @()
foreach ($c in $selected) {
	$builds = @{}
	$missing = $false
	foreach ($name in $c.BuildMap.Keys) {
		$key = $c.BuildMap[$name]
		if (-not $buildOutputs.ContainsKey($key) -or -not (Test-Path -LiteralPath $buildOutputs[$key])) { $missing = $true; break }
		$builds[$name] = $buildOutputs[$key]
	}
	if ($missing) { $script:AnyFailed = $true; Write-Output "::error title=TEST $($c.Name)::依赖的构建未成功，跳过用例"; continue }
	if ($c.Serial) { $serialCases += , @{ Case = $c; Builds = $builds }; continue }
	$safe = $c.Name -replace '[^\w\.\-]', '_'
	$workDir = Join-Path $workRoot "$safe-$([guid]::NewGuid().ToString('N').Substring(0,8))"
	$files = New-JobFiles -Prefix "test-$safe"
	Write-JsonFile -Path $files.JobFile -Object @{ Name = $c.Name; WorkDir = $workDir; CacheDir = $cacheRoot; Builds = $builds }
	$files.Mode = 'Test'
	$files.Label = "test $($c.Name)"
	$files.Timeout = if ($TimeoutSeconds -gt 0) { $TimeoutSeconds } else { $c.Timeout }
	$files.Case = $c
	$files.WorkDir = $workDir
	$testJobs += , $files
}

function Convert-TestResults {
	param([array]$RawResults)
	$out = @()
	foreach ($tr in $RawResults) {
		$j = $tr.Job
		$ok = [bool]$tr.Result.Success
		$out += , @{
			Name       = $j.Case.Name
			Group      = $j.Case.Group
			Success    = $ok
			Error      = [string]$tr.Result.Error
			Stack      = [string]$tr.Result.Stack
			Assertions = [int]$tr.Result.Assertions
			Log        = (Get-JobLog -Job $j)
			WorkDir    = $j.WorkDir
		}
	}
	return $out
}

$testResults = @()
if ($testJobs.Count) {
	Write-Host "== 测试阶段：$($testJobs.Count) 个用例（并行度 $throttle）=="
	$testResults += Convert-TestResults (Invoke-WorkerJobs -Jobs $testJobs -Throttle $throttle)
}

# 串行用例（会改动共享环境，如注册表），在并行批次之后独占执行。
foreach ($sc in $serialCases) {
	$c = $sc.Case
	$safe = $c.Name -replace '[^\w\.\-]', '_'
	$workDir = Join-Path $workRoot "$safe-$([guid]::NewGuid().ToString('N').Substring(0,8))"
	$files = New-JobFiles -Prefix "test-$safe"
	Write-JsonFile -Path $files.JobFile -Object @{ Name = $c.Name; WorkDir = $workDir; CacheDir = $cacheRoot; Builds = $sc.Builds }
	$files.Mode = 'Test'
	$files.Label = "test $($c.Name) [serial]"
	$files.Timeout = if ($TimeoutSeconds -gt 0) { $TimeoutSeconds } else { $c.Timeout }
	$files.Case = $c
	$files.WorkDir = $workDir
	Write-Host "== 串行用例：$($c.Name) =="
	$testResults += Convert-TestResults (Invoke-WorkerJobs -Jobs @($files) -Throttle 1)
}

# ---- 汇总 ----
$failures = @($testResults | Where-Object { -not $_.Success })
foreach ($f in $failures) {
	$script:AnyFailed = $true
	Write-CIGitHubReport -Failures @(@{ Name = $f.Name; Error = $f.Error; Stack = $f.Stack; Log = $f.Log })
}

$totalAssertions = ($testResults | Measure-Object -Property Assertions -Sum).Sum
Write-Host ''
Write-Host '==================== 测试汇总 ===================='
foreach ($r in ($testResults | Sort-Object Name)) {
	$status = if ($r.Success) { 'PASS' } else { 'FAIL' }
	Write-Host ("  {0,-6} {1,-12} {2,-42} asserts={3}" -f $status, $r.Group, $r.Name, $r.Assertions)
}
$passed = @($testResults | Where-Object { $_.Success }).Count
$failed = $failures.Count
Write-Host ("用例：{0} 通过 / {1} 失败；断言 {2}；构建缓存命中 {3}" -f $passed, $failed, $totalAssertions, $cachedCount)

if (-not $KeepWorkDir) {
	foreach ($r in $testResults) {
		if ($r.WorkDir -and (Test-Path -LiteralPath $r.WorkDir)) { Remove-Item -LiteralPath $r.WorkDir -Recurse -Force -ErrorAction SilentlyContinue }
	}
}

if ($script:AnyFailed -or $failed -gt 0) { exit 1 }
Write-Output 'Nice CI!'
exit 0
