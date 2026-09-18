<#
.SYNOPSIS
	针对 README 的“Comparative Advantages”章节，对 ps12exe 与 MScholtes/PS2EXE 进行基准测试。
.DESCRIPTION
	用本仓库中的 ps12exe 模块和本地安装的最新 PS2EXE 编译常量 / 非常量（可选 Core）hello-world 脚本，然后打印与 README“Size & Speed Benchmark”表相呼应的 markdown（相同的行、标签、组分隔符和大小格式）。-ProbeRuntime 还会打印“Compiled-EXE Runtime Behaviour”表。PS2EXE 永不下载：使用本地安装的最新 ps2exe 模块。找不到时会跳过其行，并在末尾打印安装提示。要求：Windows、Windows PowerShell 5.1、pwsh 7+，以及使用 -IncludeCore 时的 .NET SDK。
.PARAMETER Runs
	每个目标的热运行次数。默认为 20。
.PARAMETER IncludeCore
	同时构建 Core（PowerShell 7+）目标。需要 .NET SDK，且更慢。
.PARAMETER ProbeRuntime
	同时探测运行时行为（console TTY、原始 stdin、特殊路径变量）。
.PARAMETER KeepTemp
	运行结束后保留临时工作目录。
.EXAMPLE
	./Compare-Compilers.ps1
.EXAMPLE
	./Compare-Compilers.ps1 -Runs 30 -IncludeCore -ProbeRuntime
#>
[CmdletBinding()]
param(
	[int]$Runs = 20,
	[switch]$IncludeCore,
	[switch]$ProbeRuntime,
	[switch]$KeepTemp
)

$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$tempDir = Join-Path ([System.IO.Path]::GetTempPath()) ("ps12exe-bench-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tempDir -Force | Out-Null
Write-Host "Working directory: $tempDir"

function New-Script([string]$name, [string]$content) {
	$path = Join-Path $tempDir $name
	[System.IO.File]::WriteAllText($path, $content, [System.Text.UTF8Encoding]::new($false))
	return $path
}

function Format-Size([long]$bytes) {
	if ($bytes -le 0) { return '—' }
	if ($bytes -ge 102400) { return ('~{0} KB' -f [math]::Round($bytes / 1024)) }
	return "$bytes bytes"
}

$measurements = @{}

# 非交互运行时（CI、输出被捕获的终端）stdin 是永不关闭的管道；PS2EXE 生成的 exe 会把重定向的 stdin 一直读到 EOF，一旦继承这种管道就会看起来卡死。此时给被测进程一个立即 EOF 的空 stdin，其余行为不变。
$stdinIsRedirected = [System.Console]::IsInputRedirected
function Invoke-MeasuredTarget([string]$exe, [string[]]$argv) {
	if ($stdinIsRedirected) { $null | & $exe @argv *> $null }
	else { & $exe @argv *> $null }
}

function Measure-Exe([string]$Id, [string]$Label, [string]$Path) {
	$size = (Get-Item -LiteralPath $Path).Length
	Invoke-MeasuredTarget $Path @()
	$sw = [System.Diagnostics.Stopwatch]::StartNew()
	for ($i = 0; $i -lt $Runs; $i++) { Invoke-MeasuredTarget $Path @() }
	$sw.Stop()
	$measurements[$Id] = [pscustomobject]@{ Label = $Label; Bytes = [long]$size; Ms = [math]::Round($sw.Elapsed.TotalMilliseconds / $Runs) }
}

function Measure-Script([string]$Id, [string]$Label, [string[]]$Argv) {
	$exe = $Argv[0]
	$rest = if ($Argv.Count -gt 1) { @($Argv[1..($Argv.Count - 1)]) } else { @() }
	Invoke-MeasuredTarget $exe $rest
	$sw = [System.Diagnostics.Stopwatch]::StartNew()
	for ($i = 0; $i -lt $Runs; $i++) { Invoke-MeasuredTarget $exe $rest }
	$sw.Stop()
	$measurements[$Id] = [pscustomobject]@{ Label = $Label; Bytes = [long]0; Ms = [math]::Round($sw.Elapsed.TotalMilliseconds / $Runs) }
}

$constScript = New-Script 'hello_const.ps1' "Write-Output 'Hello World'`n"
$nonConstScript = New-Script 'hello_nonconst.ps1' "#_pragma Build.ConstEval.Enabled 0`nWrite-Output `"Hello World `$env:COMPUTERNAME`"`n"
$helloScript = New-Script 'hello.ps1' "Write-Output 'Hello World'`n"

# --- ps12exe（本仓库）---
Import-Module (Join-Path $repoRoot 'ps12exe.psd1') -Force
$exe = Join-Path $tempDir 'const.exe'
ps12exe $constScript $exe -NoUpdateCheck
Measure-Exe 'ps12-const-fw' 'ps12exe · constant · Framework4.0' $exe

$exe = Join-Path $tempDir 'nonconst.exe'
ps12exe $nonConstScript $exe -NoUpdateCheck
Measure-Exe 'ps12-nonconst-fw' 'ps12exe · non-constant · Framework4.0' $exe

if ($IncludeCore) {
	if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw '-IncludeCore requires the .NET SDK.' }
	$exe = Join-Path $tempDir 'const_core.exe'
	ps12exe $constScript $exe -Build @{Target='Core'} -NoUpdateCheck
	Measure-Exe 'ps12-const-core' 'ps12exe · constant · Core' $exe
	$exe = Join-Path $tempDir 'nonconst_core.exe'
	ps12exe $nonConstScript $exe -Build @{Target='Core'} -NoUpdateCheck
	Measure-Exe 'ps12-nonconst-core' 'ps12exe · non-constant · Core' $exe
}

# --- MScholtes/PS2EXE（仅使用本地安装的最新模块；本脚本永不下载）---
$ps2exeModule = Get-Module -ListAvailable -Name ps2exe | Sort-Object Version -Descending | Select-Object -First 1

$ps2exeAvailable = [bool]$ps2exeModule
if ($ps2exeAvailable) {
	$PS2EXEVersion = "$((Import-PowerShellDataFile -LiteralPath $ps2exeModule.Path).ModuleVersion)"
	$ps2exeName = "PS2EXE $PS2EXEVersion"
	$ps2exeAt = "MScholtes/PS2EXE@$PS2EXEVersion"
	Import-Module $ps2exeModule.Path -Force
	Write-Host "Using local PS2EXE $PS2EXEVersion ($($ps2exeModule.Path))"
	$exe = Join-Path $tempDir 'ps2exe.exe'
	Invoke-ps2exe -inputFile $helloScript -outputFile $exe
	Measure-Exe 'ps2exe-fw' "$ps2exeName · non-constant" $exe
}
else {
	$ps2exeName = 'PS2EXE'
	$ps2exeAt = 'MScholtes/PS2EXE'
	Write-Host 'No local PS2EXE found; its rows will be skipped (this script never downloads).'
}

# --- 基线 ---
Measure-Script 'base-fw' 'Windows PowerShell 5.1 running the script directly' @('powershell.exe', '-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $helloScript)
Measure-Script 'base-core' 'pwsh 7 running the script directly' @('pwsh.exe', '-NoProfile', '-File', $helloScript)

function Write-Row([string]$Id, [string]$Fallback) {
	if ($measurements.ContainsKey($Id)) {
		$m = $measurements[$Id]
		Write-Host ("| {0} | {1} | ~{2} ms |" -f $m.Label, (Format-Size $m.Bytes), $m.Ms)
	}
	else {
		Write-Host ("| {0} | — | — |" -f $Fallback)
	}
}

Write-Host ''
Write-Host '### Size & Speed Benchmark'
Write-Host ''
Write-Host '| Build | Output size | Warm startup |'
Write-Host '| ----- | ----------- | ------------ |'
Write-Row 'base-fw' 'Windows PowerShell 5.1 running the script directly'
Write-Row 'ps12-const-fw' 'ps12exe · constant · Framework4.0'
Write-Row 'ps12-nonconst-fw' 'ps12exe · non-constant · Framework4.0'
Write-Row 'ps2exe-fw' "$ps2exeName · non-constant"
Write-Host '| ----- | ----------- | ------------ |'
Write-Row 'base-core' 'pwsh 7 running the script directly'
Write-Row 'ps12-const-core' 'ps12exe · constant · Core'
Write-Row 'ps12-nonconst-core' 'ps12exe · non-constant · Core'
Write-Host ("| {0} · non-constant · Core | not support | not support |" -f $ps2exeName)
if (-not $IncludeCore) { Write-Host ''; Write-Host '# Core rows require -IncludeCore.' }

if ($ProbeRuntime) {
	function Get-Mark($value) {
		if ($value -eq $true) { return '✔️' }
		if ($value -eq $false) { return '❌' }
		return '—'
	}

	$probeScript = New-Script 'probe.ps1' @'
#_pragma Build.ConstEval.Enabled 0
$joined = [Console]::In.ReadToEnd()
Write-Output ("raw=[" + $joined + "]")
Write-Output ("PSCommandPath=[" + $PSCommandPath + "]")
Write-Output ("PSScriptRoot=[" + $PSScriptRoot + "]")
'@
	$probe = [ordered]@{
		'ps12exe' = [pscustomobject]@{ File = (Join-Path $tempDir 'probe_ps12.exe'); Stdin = $null; Path = $null; TTY = $null }
		'ps2exe'  = [pscustomobject]@{ File = (Join-Path $tempDir 'probe_ps2exe.exe'); Stdin = $null; Path = $null; TTY = $null }
	}
	ps12exe $probeScript $probe['ps12exe'].File -NoUpdateCheck
	if ($ps2exeAvailable) { Invoke-ps2exe -inputFile $probeScript -outputFile $probe['ps2exe'].File }
	foreach ($key in $probe.Keys) {
		if (-not (Test-Path -LiteralPath $probe[$key].File)) { continue }
		$lines = @('hello' | & $probe[$key].File)
		$stdin = $lines | Where-Object { $_ -like 'raw=*' } | Select-Object -First 1
		$path = $lines | Where-Object { $_ -like 'PSCommandPath=*' } | Select-Object -First 1
		$probe[$key].Stdin = [bool]($stdin -replace 'raw=\[|\]$', '')
		$probe[$key].Path = [bool]($path -replace 'PSCommandPath=\[|\]$', '')
	}

	# TTY 探测：需要真实的控制台窗口，因此 node 缺失时跳过。
	if (Get-Command node -ErrorAction Ignore) {
		$js = New-Script 'tty.js' "const fs=require('fs');fs.writeFileSync(process.env.OUT,JSON.stringify({nodeOutTTY:!!process.stdout.isTTY}))"
		$ttyScript = New-Script 'tty.ps1' ("& node `"$js`"`n")
		$probe['ps12exe'].TTY = Join-Path $tempDir 'tty_ps12.exe'
		ps12exe $ttyScript $probe['ps12exe'].TTY -NoUpdateCheck
		if ($ps2exeAvailable) {
			$probe['ps2exe'].TTY = Join-Path $tempDir 'tty_ps2exe.exe'
			Invoke-ps2exe -inputFile $ttyScript -outputFile $probe['ps2exe'].TTY
		}
		foreach ($key in $probe.Keys) {
			if (-not $probe[$key].TTY) { continue }
			$out = Join-Path $tempDir ('tty_' + [Guid]::NewGuid().ToString('N') + '.json')
			$env:OUT = $out
			$probe[$key].TTY = 'not tested'
			try {
				Start-Process -FilePath $probe[$key].TTY -Wait -ErrorAction Stop
				if (Test-Path $out) { $probe[$key].TTY = [bool](((Get-Content $out -Raw) -match '"nodeOutTTY":true')) }
			}
			catch {}
		}
	}

	$ps12Stdin = if ($probe['ps12exe'].Stdin) { '✔️ (unless the script uses `$input`)' } else { '❌' }
	$ps12Path = if ($probe['ps12exe'].Path) { '✔️ (exe path / exe directory)' } else { '❌' }
	Write-Host ''
	Write-Host '### Compiled-EXE Runtime Behaviour'
	Write-Host ''
	Write-Host ("| Capability | ps12exe | [`{0}`](https://github.com/MScholtes/PS2EXE/tree/05c62615) |" -f $ps2exeAt)
	Write-Host '| ---------- | ------- | ------------ |'
	Write-Host ("| Native child process sees a console TTY (`isTTY`) | {0} | {1} |" -f (Get-Mark $probe['ps12exe'].TTY), (Get-Mark $probe['ps2exe'].TTY))
	Write-Host ("| Raw stdin (`[Console]::In`) readable | {0} | {1} |" -f $ps12Stdin, (Get-Mark $probe['ps2exe'].Stdin))
	Write-Host ('| `$PSCommandPath` / `$PSScriptRoot` resolve | {0} | {1} |' -f $ps12Path, (Get-Mark $probe['ps2exe'].Path))
}

if (-not $ps2exeAvailable) {
	Write-Host ''
	Write-Host '# PS2EXE was not found locally, so its rows are blank. This script never downloads it.'
	Write-Host '# To fill them, install PS2EXE and run again:'
	Write-Host '#   Install-Module PS2EXE'
}

if (-not $KeepTemp) { Remove-Item -LiteralPath $tempDir -Recurse -Force -ErrorAction Ignore }
