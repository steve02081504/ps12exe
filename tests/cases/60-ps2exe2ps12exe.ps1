# PS2EXE2ps12exe 兼容层：参数映射、架构、embedFiles、$ScriptRoot、conHost、冲突校验、runtime 映射。
$script:PS2EXEDeps = @('src/.subrepo/PS2EXE2ps12exe/') + $script:CoreCompileDeps
$script:PS2EXEFixtures = Join-Path (Get-TestRepoRoot) 'tests/.cache/fixtures'

function New-PS2EXEFixture {
	param([string]$Name, [string]$Content)
	$path = Join-Path $script:PS2EXEFixtures $Name
	if (-not (Test-Path -LiteralPath $path)) {
		New-Item -ItemType Directory -Path $script:PS2EXEFixtures -Force | Out-Null
		[System.IO.File]::WriteAllText($path, $Content, [System.Text.UTF8Encoding]::new($true))
	}
	return $path
}
$helloFixture = New-PS2EXEFixture 'ps2exe-hello.ps1' "'hello-compat'"
$archFixture = New-PS2EXEFixture 'ps2exe-arch.ps1' "#_pragma Build.ConstEval.Enabled 0`n'arch-ok'"
$embedFixture = New-PS2EXEFixture 'ps2exe-embed.ps1' "'embed-script'"
$srootFixture = New-PS2EXEFixture 'ps2exe-sroot.ps1' "'ScriptRoot=[' + `$ScriptRoot + ']'"
$runtimeFixture = New-PS2EXEFixture 'ps2exe-runtime.ps1' "'rt-ok'"
$payloadFixture = New-PS2EXEFixture 'ps2exe-payload.bin' 'embed-payload-42'
$conhostFixture = New-PS2EXEFixture 'ps2exe-conhost.ps1' @'
param([string]$Name = 'default')
[System.IO.File]::AppendAllText((Join-Path $PSScriptRoot 'conhost_marker.txt'), 'name=' + $Name)
'@

Add-Test @{
	Name  = 'ps2exe.basic-mapping'
	Group = 'ps2exe2ps12exe'
	Deps  = $script:PS2EXEDeps
	Build = @{ Name = 'hello'; Compiler = 'ps2exe'; InputFile = $helloFixture; Params = @{ title = 'CompatTitle'; version = '9.9.9.9' }; Output = 'hello.exe' }
	Run   = {
		param($ctx)
		Initialize-Ps2exeShim -RepoRoot $ctx.RepoRoot
		$exe = $ctx.Builds['hello']
		Assert-FileExists $exe 'shim 编译未产出 exe'
		$out = & $exe
		Assert-Match "$out" 'hello-compat' "shim 基础 exe 输出不符：$out"
		$info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($exe)
		Assert-Equal 'CompatTitle' $info.FileDescription 'shim title 未生效'
		Assert-Equal '9.9.9.9' $info.FileVersion 'shim version 未生效'
	}
}

Add-Test @{
	Name   = 'ps2exe.arch-mapping'
	Group  = 'ps2exe2ps12exe'
	Deps   = $script:PS2EXEDeps
	Builds = @(
		@{ Name = 'x64'; Compiler = 'ps2exe'; InputFile = $archFixture; Params = @{ x64 = $true }; Output = 'arch_x64.exe' }
		@{ Name = 'x86'; Compiler = 'ps2exe'; InputFile = $archFixture; Params = @{ x86 = $true }; Output = 'arch_x86.exe' }
	)
	Run    = {
		param($ctx)
		function Get-PEMachine([string]$Path) {
			$bytes = [System.IO.File]::ReadAllBytes($Path)
			$peOffset = [BitConverter]::ToInt32($bytes, 0x3C)
			$machine = [BitConverter]::ToUInt16($bytes, $peOffset + 4)
			switch ($machine) { 0x14c { 'x86' } 0x8664 { 'x64' } default { '0x{0:x}' -f $machine } }
		}
		Assert-Equal 'x64' (Get-PEMachine $ctx.Builds['x64']) 'shim -x64 未产出 x64 exe'
		Assert-Equal 'x86' (Get-PEMachine $ctx.Builds['x86']) 'shim -x86 未产出 x86 exe'
	}
}

Add-Test @{
	Name  = 'ps2exe.embed-files'
	Group = 'ps2exe2ps12exe'
	Deps  = $script:PS2EXEDeps
	Build = @{ Name = 'embed'; Compiler = 'ps2exe'; InputFile = $embedFixture; Params = @{ embedFiles = @{ '.\released.bin' = $payloadFixture } }; Output = 'embed.exe' }
	Run   = {
		param($ctx)
		$exe = Copy-BuildAs -BuildPath $ctx.Builds['embed'] -WorkDir $ctx.WorkDir -Name 'embed.exe'
		$released = Join-Path $ctx.WorkDir 'released.bin'
		Remove-Item -LiteralPath $released -Force -ErrorAction Ignore
		& $exe | Out-Null
		Assert-FileExists $released 'shim embedFiles 未在运行时释放文件'
		$payload = Join-Path $ctx.RepoRoot 'tests/.cache/fixtures/ps2exe-payload.bin'
		Assert-Equal (Get-Content -LiteralPath $payload -Raw) (Get-Content -LiteralPath $released -Raw) 'shim embedFiles 释放内容不符'
	}
}

Add-Test @{
	Name  = 'ps2exe.script-root'
	Group = 'ps2exe2ps12exe'
	Deps  = $script:PS2EXEDeps
	Build = @{ Name = 'sroot'; Compiler = 'ps2exe'; InputFile = $srootFixture; Output = 'sroot.exe' }
	Run   = {
		param($ctx)
		$exe = Copy-BuildAs -BuildPath $ctx.Builds['sroot'] -WorkDir $ctx.WorkDir -Name 'sroot.exe'
		$out = (& $exe | Out-String).Trim()
		Assert-Equal "ScriptRoot=[$($ctx.WorkDir)]" $out 'shim $ScriptRoot 语义不符（应为 exe 所在目录）'
	}
}

Add-Test @{
	Name  = 'ps2exe.conhost'
	Group = 'ps2exe2ps12exe'
	Deps  = $script:PS2EXEDeps
	Build = @{ Name = 'conhost'; Compiler = 'ps2exe'; InputFile = $conhostFixture; Params = @{ conHost = $true }; Output = 'conhost.exe' }
	Run   = {
		param($ctx)
		$exe = Copy-BuildAs -BuildPath $ctx.Builds['conhost'] -WorkDir $ctx.WorkDir -Name 'conhost.exe'
		$marker = Join-Path $ctx.WorkDir 'conhost_marker.txt'
		Remove-Item -LiteralPath $marker -Force -ErrorAction Ignore
		& $exe -Name 'CI Bob' | Out-Null
		Assert-True (Wait-ForPath -Path $marker -TimeoutSeconds 25) 'shim conHost 未二次启动 exe'
		Assert-Match (Get-Content -LiteralPath $marker -Raw) 'name=CI Bob' 'shim conHost 丢失参数'
	}
}

Add-Test @{
	Name  = 'ps2exe.conflicts'
	Group = 'ps2exe2ps12exe'
	Deps  = $script:PS2EXEDeps
	Run   = {
		param($ctx)
		Initialize-Ps2exeShim -RepoRoot $ctx.RepoRoot
		$hello = Join-Path $ctx.WorkDir 'hello.ps1'
		[System.IO.File]::WriteAllText($hello, "'hello-compat'", [System.Text.UTF8Encoding]::new($true))
		$out = Join-Path $ctx.WorkDir 'conflict.exe'
		$cases = @(
			@{ Name = 'x86+x64'; Args = @{ x86 = $true; x64 = $true } },
			@{ Name = 'STA+MTA'; Args = @{ STA = $true; MTA = $true } },
			@{ Name = 'noConsole+conHost'; Args = @{ noConsole = $true; conHost = $true } },
			@{ Name = 'configFile+noConfigFile'; Args = @{ configFile = $true; noConfigFile = $true } },
			@{ Name = 'runtime20+runtime40'; Args = @{ runtime20 = $true; runtime40 = $true } }
		)
		foreach ($c in $cases) {
			$rejected = $false
			$conflictArgs = $c.Args
			try { ps2exe -inputFile $hello -outputFile $out @conflictArgs *> $null } catch { $rejected = $true; $Error.Clear() }
			Assert-True $rejected "shim 应拒绝冲突参数组合 $($c.Name)"
		}
	}
}

Add-Test @{
	Name   = 'ps2exe.runtime-mapping'
	Group  = 'ps2exe2ps12exe'
	Deps   = $script:PS2EXEDeps
	Builds = @(
		@{ Name = 'rt20'; Compiler = 'ps2exe'; InputFile = $runtimeFixture; Params = @{ runtime20 = $true }; Output = 'rt20.exe' }
		@{ Name = 'rt40'; Compiler = 'ps2exe'; InputFile = $runtimeFixture; Params = @{ runtime40 = $true }; Output = 'rt40.exe' }
	)
	Run    = {
		param($ctx)
		Assert-FileExists $ctx.Builds['rt20'] 'shim -runtime20 未产出 exe'
		Assert-FileExists $ctx.Builds['rt40'] 'shim -runtime40 未产出 exe'
	}
}
