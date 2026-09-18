# PS2EXE2ps12exe 兼容层测试：参数映射、conHost / embedFiles 转写、$ScriptRoot 兼容。失败时输出 GitHub 友好 ::error/::group。
$ErrorActionPreference = 'Stop'
$error.Clear()
$repoRoot = $env:REPO_ROOT
if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }
$buildDir = Join-Path $repoRoot 'build/ps2exe2ps12exe'
$ciDir = Join-Path $repoRoot '.github/workflows/CI'

. (Join-Path $ciDir 'test-helpers.ps1')
New-Item -ItemType Directory -Path $buildDir -Force | Out-Null

# ps12exe 模块必须能被 shim 以模块名发现；用一个临时模块目录 + junction 指向仓库根，避免依赖仓库文件夹名。
$modulePath = Join-Path $env:TEMP ('ps12exe-module-' + [Guid]::NewGuid().ToString('N'))
New-Item -ItemType Directory -Path $modulePath -Force | Out-Null
New-Item -ItemType Junction -Path (Join-Path $modulePath 'ps12exe') -Target $repoRoot | Out-Null
$env:PSModulePath = "$modulePath;$env:PSModulePath"
Import-Module (Join-Path $repoRoot 'src/.subrepo/PS2EXE2ps12exe/PS2EXE2ps12exe.psd1') -Force

function Get-PEMachine([string]$Path) {
	$bytes = [System.IO.File]::ReadAllBytes($Path)
	$peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
	$machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
	switch ($machine) {
		0x14c { 'x86' }
		0x8664 { 'x64' }
		default { '0x{0:x}' -f $machine }
	}
}

try {
	# 1) 基本映射：title/version -> resourceParams
	$helloPs1 = Join-Path $buildDir 'hello.ps1'
	Set-Content -LiteralPath $helloPs1 -Encoding UTF8 -Value "'hello-compat'"
	$helloExe = Join-Path $buildDir 'hello.exe'
	ps2exe -inputFile $helloPs1 -outputFile $helloExe -title 'CompatTitle' -version '9.9.9.9' | Write-Host
	if (-not (Test-Path -LiteralPath $helloExe)) { throw 'shim basic compile produced no exe' }
	$helloOut = & $helloExe
	if ("$helloOut" -notmatch 'hello-compat') { throw "shim basic exe output mismatch: $helloOut" }
	$versionInfo = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($helloExe)
	if ($versionInfo.FileDescription -ne 'CompatTitle') { throw "shim title not applied: $($versionInfo.FileDescription)" }
	if ($versionInfo.FileVersion -ne '9.9.9.9') { throw "shim version not applied: $($versionInfo.FileVersion)" }

	# 2) 架构映射：x64/x86 -> architecture（非常量走 CodeDom，PE 机器码可验证）
	$archPs1 = Join-Path $buildDir 'arch.ps1'
	Set-Content -LiteralPath $archPs1 -Encoding UTF8 -Value "#_pragma noConstEval`n'arch-ok'"
	$archX64 = Join-Path $buildDir 'arch_x64.exe'
	$archX86 = Join-Path $buildDir 'arch_x86.exe'
	ps2exe -inputFile $archPs1 -outputFile $archX64 -x64 | Write-Host
	ps2exe -inputFile $archPs1 -outputFile $archX86 -x86 | Write-Host
	if ((Get-PEMachine $archX64) -ne 'x64') { throw "shim -x64 did not produce x64 exe: $(Get-PEMachine $archX64)" }
	if ((Get-PEMachine $archX86) -ne 'x86') { throw "shim -x86 did not produce x86 exe: $(Get-PEMachine $archX86)" }

	# 3) embedFiles：编译期嵌入、运行时释放到 .\（相对 exe）
	$payload = Join-Path $buildDir 'src.bin'
	Set-Content -LiteralPath $payload -Encoding UTF8 -Value 'embed-payload-42'
	$embedPs1 = Join-Path $buildDir 'embed.ps1'
	Set-Content -LiteralPath $embedPs1 -Encoding UTF8 -Value "'embed-script'"
	$embedExe = Join-Path $buildDir 'embed.exe'
	ps2exe -inputFile $embedPs1 -outputFile $embedExe -embedFiles @{ '.\released.bin' = $payload } | Write-Host
	$released = Join-Path $buildDir 'released.bin'
	Remove-Item -LiteralPath $released -Force -ErrorAction Ignore
	& $embedExe | Out-Null
	if (-not (Test-Path -LiteralPath $released)) { throw 'shim embedFiles did not release the file' }
	if ((Get-Content -LiteralPath $payload -Raw) -ne (Get-Content -LiteralPath $released -Raw)) { throw 'shim embedFiles released wrong content' }

	# 4) $ScriptRoot：脚本用到时按 PS2EXE 语义补上（exe 所在目录）
	$srootPs1 = Join-Path $buildDir 'sroot.ps1'
	Set-Content -LiteralPath $srootPs1 -Encoding UTF8 -Value "'ScriptRoot=[' + `$ScriptRoot + ']'"
	$srootExe = Join-Path $buildDir 'sroot.exe'
	ps2exe -inputFile $srootPs1 -outputFile $srootExe | Write-Host
	$srootOut = & $srootExe
	if ("$srootOut".Trim() -ne "ScriptRoot=[$buildDir]") { throw "shim `$ScriptRoot mismatch: $srootOut" }

	# 5) conHost：脚本级二次启动到 conhost，参数需正确转发
	$conhostPs1 = Join-Path $buildDir 'conhost.ps1'
	$conhostMarker = Join-Path $buildDir 'conhost_marker.txt'
	$conhostMarkerLiteral = $conhostMarker.Replace("'", "''")
	Set-Content -LiteralPath $conhostPs1 -Encoding UTF8 -Value @"
param([string]`$Name = 'default')
[System.IO.File]::AppendAllText('$conhostMarkerLiteral', 'name=' + `$Name)
"@
	$conhostExe = Join-Path $buildDir 'conhost.exe'
	ps2exe -inputFile $conhostPs1 -outputFile $conhostExe -conHost | Write-Host
	Remove-Item -LiteralPath $conhostMarker -Force -ErrorAction Ignore
	& $conhostExe -Name 'CI Bob' | Out-Null
	$conhostDeadline = [DateTime]::UtcNow.AddSeconds(20)
	while (-not (Test-Path -LiteralPath $conhostMarker) -and [DateTime]::UtcNow -lt $conhostDeadline) { Start-Sleep -Milliseconds 300 }
	if (-not (Test-Path -LiteralPath $conhostMarker)) { throw 'shim conHost did not relaunch the executable' }
	if ((Get-Content -LiteralPath $conhostMarker -Raw) -notmatch 'name=CI Bob') { throw "shim conHost lost arguments: $(Get-Content -LiteralPath $conhostMarker -Raw)" }

	# 6) 参数组合校验（复刻 PS2EXE）
	$conflicts = @(
		@{ Name = 'x86+x64'; Args = @('-x86', '-x64') },
		@{ Name = 'STA+MTA'; Args = @('-STA', '-MTA') },
		@{ Name = 'noConsole+conHost'; Args = @('-noConsole', '-conHost') },
		@{ Name = 'configFile+noConfigFile'; Args = @('-configFile', '-noConfigFile') },
		@{ Name = 'runtime20+runtime40'; Args = @('-runtime20', '-runtime40') }
	)
	foreach ($conflict in $conflicts) {
		$rejected = $false
		$conflictArgs = $conflict.Args
		try { ps2exe -inputFile $helloPs1 -outputFile (Join-Path $buildDir 'conflict.exe') @conflictArgs *> $null } catch { $rejected = $true; $Error.Clear() }
		if (-not $rejected) { throw "shim should reject $($conflict.Name)" }
	}

	# 7) 旧版参数保留：runtime20/40 映射到 targetRuntime（能编过即可）
	$rtPs1 = Join-Path $buildDir 'rt.ps1'
	Set-Content -LiteralPath $rtPs1 -Encoding UTF8 -Value "'rt-ok'"
	ps2exe -inputFile $rtPs1 -outputFile (Join-Path $buildDir 'rt20.exe') -runtime20 | Write-Host
	ps2exe -inputFile $rtPs1 -outputFile (Join-Path $buildDir 'rt40.exe') -runtime40 | Write-Host
	if (-not (Test-Path -LiteralPath (Join-Path $buildDir 'rt20.exe'))) { throw 'shim -runtime20 produced no exe' }
	if (-not (Test-Path -LiteralPath (Join-Path $buildDir 'rt40.exe'))) { throw 'shim -runtime40 produced no exe' }
}
catch {}
finally {
	Remove-Item -LiteralPath $buildDir -Recurse -Force -ErrorAction SilentlyContinue
	# 先删 junction 本身（不递归，避免误删仓库），再删临时目录
	Remove-Item -LiteralPath (Join-Path $modulePath 'ps12exe') -Force -ErrorAction SilentlyContinue
	Remove-Item -LiteralPath $modulePath -Recurse -Force -ErrorAction SilentlyContinue
}
if ($error) { Write-CIGitHubErrorReport }
Write-Output 'PS2EXE2ps12exe tests OK'
