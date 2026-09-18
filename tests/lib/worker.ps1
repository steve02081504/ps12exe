# 测试 worker：在独立进程中执行单个构建或单个用例，保证环境变量/工作目录隔离。
param(
	[Parameter(Mandatory)][ValidateSet('Build', 'Test')][string]$Mode,
	[Parameter(Mandatory)][string]$JobFile,
	[Parameter(Mandatory)][string]$ResultFile
)
$ErrorActionPreference = 'Stop'

. (Join-Path $PSScriptRoot 'common.ps1')
. (Join-Path $PSScriptRoot 'exec.ps1')
. (Join-Path $PSScriptRoot 'assert.ps1')
. (Join-Path $PSScriptRoot 'framework.ps1')

$repoRoot = $script:RepoRoot
$job = ConvertTo-HashtableDeep (Read-JsonFile -Path $JobFile)
$result = @{ Success = $false; OutputPath = $null; Error = $null; Stack = $null; Assertions = 0 }

function Find-TestCase {
	param([string]$Name)
	$cases = @(Get-AllTestCases)
	$case = $cases | Where-Object { $_.Name -eq $Name } | Select-Object -First 1
	if (-not $case) { throw "找不到用例：$Name" }
	return $case
}

function Invoke-BuildSpec {
	param([hashtable]$Spec)
	if ($Spec.Env) {
		foreach ($k in @($Spec.Env.Keys)) { Set-Item -Path "Env:$k" -Value ([string]$Spec.Env[$k]) }
	}
	$outDir = [string]$job.OutputDir
	New-Item -ItemType Directory -Path $outDir -Force | Out-Null
	$outputName = if ($Spec.Output) { [string]$Spec.Output } else { 'out.exe' }
	$outPath = Join-Path $outDir $outputName
	$named = @{}
	if ($Spec.Params) { foreach ($k in @($Spec.Params.Keys)) { $named[$k] = $Spec.Params[$k] } }
	Import-Module $repoRoot -Force
	if ($Spec.Compiler -eq 'ps2exe') {
		Initialize-Ps2exeShim -RepoRoot $repoRoot
		if ($null -ne $Spec.InputText) {
			$inputFile = Join-Path $outDir 'input.ps1'
			[System.IO.File]::WriteAllText($inputFile, [string]$Spec.InputText, [System.Text.UTF8Encoding]::new($true))
			$null = [string]$Spec.InputText | ps2exe @named -outputFile $outPath
		}
		else {
			$inputFile = [string]$Spec.InputFile
			if (-not [System.IO.Path]::IsPathRooted($inputFile)) { $inputFile = Join-Path $repoRoot $inputFile }
			if (-not (Test-Path -LiteralPath $inputFile -PathType Leaf)) { throw "构建输入不存在：$inputFile" }
			$null = ps2exe @named -inputFile $inputFile -outputFile $outPath
		}
	}
	elseif ($null -ne $Spec.InputText) {
		$inputFile = Join-Path $outDir 'input.ps1'
		[System.IO.File]::WriteAllText($inputFile, [string]$Spec.InputText, [System.Text.UTF8Encoding]::new($true))
		$null = [string]$Spec.InputText | ps12exe @named -outputFile $outPath -NoUpdateCheck
	}
	else {
		$inputFile = [string]$Spec.InputFile
		if (-not [System.IO.Path]::IsPathRooted($inputFile)) { $inputFile = Join-Path $repoRoot $inputFile }
		if (-not (Test-Path -LiteralPath $inputFile -PathType Leaf)) { throw "构建输入不存在：$inputFile" }
		$null = ps12exe @named -inputFile $inputFile -outputFile $outPath -NoUpdateCheck
	}
	if (-not (Test-Path -LiteralPath $outPath -PathType Leaf)) { throw "构建未产出：$outPath" }
	return $outPath
}

try {
	switch ($Mode) {
		'Build' {
			$case = Find-TestCase -Name ([string]$job.CaseName)
			$specs = Get-CaseBuildSpecs -Case $case
			$entry = $specs | Where-Object { $_.Name -eq ([string]$job.BuildName) } | Select-Object -First 1
			if (-not $entry) { throw "用例 $($job.CaseName) 不存在构建 $($job.BuildName)" }
			$result.OutputPath = Invoke-BuildSpec -Spec $entry.Spec
			$result.Success = $true
		}
		'Test' {
			$case = Find-TestCase -Name ([string]$job.Name)
			Import-Module $repoRoot -Force
			New-Item -ItemType Directory -Path ([string]$job.WorkDir) -Force | Out-Null
			$builds = @{}
			if ($job.Builds) { foreach ($k in $job.Builds.Keys) { $builds[$k] = [string]$job.Builds[$k] } }
			$ctx = @{
				RepoRoot = $repoRoot
				WorkDir  = [string]$job.WorkDir
				CacheDir = [string]$job.CacheDir
				Builds   = $builds
				Case     = $case
			}
			if ($case.Run) { & $case.Run $ctx }
			$result.Success = $true
		}
	}
}
catch {
	$result.Success = $false
	$result.Error = $_.Exception.Message
	$result.Stack = $_.ScriptStackTrace
}
finally {
	$result.Assertions = Get-AssertionCount
	Write-JsonFile -Path $ResultFile -Object $result
}
