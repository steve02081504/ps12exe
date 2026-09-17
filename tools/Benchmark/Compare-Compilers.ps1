<#
.SYNOPSIS
	Benchmarks ps12exe against MScholtes/PS2EXE for the README "Comparative Advantages" section.
.DESCRIPTION
	Compiles constant / non-constant (and optionally Core) hello-world scripts with the ps12exe module
	in this repository and with the latest locally installed PS2EXE, then prints markdown that mirrors
	the README "Size & Speed Benchmark" table (same rows, labels, group separator and size formatting).
	-ProbeRuntime also prints the "Compiled-EXE Runtime Behaviour" table.
	PS2EXE is never downloaded: the latest installed ps2exe module is used. When none is found its rows
	are skipped and an install hint is printed at the end.
	Requirements: Windows, Windows PowerShell 5.1, pwsh 7+, and the .NET SDK when using -IncludeCore.
.PARAMETER Runs
	Number of warm runs per target. Defaults to 20.
.PARAMETER IncludeCore
	Also build the Core (PowerShell 7+) targets. Requires the .NET SDK and is slower.
.PARAMETER ProbeRuntime
	Also probe runtime behaviour (console TTY, raw stdin, special path variables).
.PARAMETER KeepTemp
	Keep the temporary working directory after the run.
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

function Measure-Exe([string]$Id, [string]$Label, [string]$Path) {
	$size = (Get-Item -LiteralPath $Path).Length
	& $Path *> $null
	$sw = [System.Diagnostics.Stopwatch]::StartNew()
	for ($i = 0; $i -lt $Runs; $i++) { & $Path *> $null }
	$sw.Stop()
	$measurements[$Id] = [pscustomobject]@{ Label = $Label; Bytes = [long]$size; Ms = [math]::Round($sw.Elapsed.TotalMilliseconds / $Runs) }
}

function Measure-Script([string]$Id, [string]$Label, [string[]]$Argv) {
	$exe = $Argv[0]
	$rest = @($Argv[1..($Argv.Count - 1)])
	& $exe @rest *> $null
	$sw = [System.Diagnostics.Stopwatch]::StartNew()
	for ($i = 0; $i -lt $Runs; $i++) { & $exe @rest *> $null }
	$sw.Stop()
	$measurements[$Id] = [pscustomobject]@{ Label = $Label; Bytes = [long]0; Ms = [math]::Round($sw.Elapsed.TotalMilliseconds / $Runs) }
}

$constScript = New-Script 'hello_const.ps1' "Write-Output 'Hello World'`n"
$nonConstScript = New-Script 'hello_nonconst.ps1' "#_pragma noConstEval`nWrite-Output `"Hello World `$env:COMPUTERNAME`"`n"
$helloScript = New-Script 'hello.ps1' "Write-Output 'Hello World'`n"

# --- ps12exe (this repository) ---
Import-Module (Join-Path $repoRoot 'ps12exe.psd1') -Force
$exe = Join-Path $tempDir 'const.exe'
ps12exe $constScript $exe -SkipVersionCheck
Measure-Exe 'ps12-const-fw' 'ps12exe · constant · Framework4.0' $exe

$exe = Join-Path $tempDir 'nonconst.exe'
ps12exe $nonConstScript $exe -SkipVersionCheck
Measure-Exe 'ps12-nonconst-fw' 'ps12exe · non-constant · Framework4.0' $exe

if ($IncludeCore) {
	if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw '-IncludeCore requires the .NET SDK.' }
	$exe = Join-Path $tempDir 'const_core.exe'
	ps12exe $constScript $exe -targetRuntime Core -SkipVersionCheck
	Measure-Exe 'ps12-const-core' 'ps12exe · constant · Core' $exe
	$exe = Join-Path $tempDir 'nonconst_core.exe'
	ps12exe $nonConstScript $exe -targetRuntime Core -SkipVersionCheck
	Measure-Exe 'ps12-nonconst-core' 'ps12exe · non-constant · Core' $exe
}

# --- MScholtes/PS2EXE (latest installed module only; this script never downloads) ---
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

# --- baselines ---
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
#_pragma noConstEval
$joined = [Console]::In.ReadToEnd()
Write-Output ("raw=[" + $joined + "]")
Write-Output ("PSCommandPath=[" + $PSCommandPath + "]")
Write-Output ("PSScriptRoot=[" + $PSScriptRoot + "]")
'@
	$probe = [ordered]@{
		'ps12exe' = [pscustomobject]@{ File = (Join-Path $tempDir 'probe_ps12.exe'); Stdin = $null; Path = $null; TTY = $null }
		'ps2exe'  = [pscustomobject]@{ File = (Join-Path $tempDir 'probe_ps2exe.exe'); Stdin = $null; Path = $null; TTY = $null }
	}
	ps12exe $probeScript $probe['ps12exe'].File -SkipVersionCheck
	if ($ps2exeAvailable) { Invoke-ps2exe -inputFile $probeScript -outputFile $probe['ps2exe'].File }
	foreach ($key in $probe.Keys) {
		if (-not (Test-Path -LiteralPath $probe[$key].File)) { continue }
		$lines = @('hello' | & $probe[$key].File)
		$stdin = $lines | Where-Object { $_ -like 'raw=*' } | Select-Object -First 1
		$path = $lines | Where-Object { $_ -like 'PSCommandPath=*' } | Select-Object -First 1
		$probe[$key].Stdin = [bool]($stdin -replace 'raw=\[|\]$', '')
		$probe[$key].Path = [bool]($path -replace 'PSCommandPath=\[|\]$', '')
	}

	# TTY probe: a real console window is needed, so it is skipped when node is missing.
	if (Get-Command node -ErrorAction Ignore) {
		$js = New-Script 'tty.js' "const fs=require('fs');fs.writeFileSync(process.env.OUT,JSON.stringify({nodeOutTTY:!!process.stdout.isTTY}))"
		$ttyScript = New-Script 'tty.ps1' ("& node `"$js`"`n")
		$probe['ps12exe'].TTY = Join-Path $tempDir 'tty_ps12.exe'
		ps12exe $ttyScript $probe['ps12exe'].TTY -SkipVersionCheck
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
