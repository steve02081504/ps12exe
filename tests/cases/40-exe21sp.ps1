# exe21sp 提取：普通/TinySharp/压缩/Core 产物还原、资源参数与图标往返、保存到文件分支。
$deps = @('exe21sp.ps1', 'src/Interact/exe21sp.ps1', 'src/TaskbarProgress.ps1') + $script:CoreCompileDeps

# 生成确定性的 1x1 32bpp ICO 测试夹具（源码里没有该图标，用于验证资源往返）。
$script:IconFixture = Join-Path (Get-TestRepoRoot) 'tests/.cache/fixtures/resource.ico'
if (-not (Test-Path -LiteralPath $script:IconFixture)) {
	New-Item -ItemType Directory -Path (Split-Path $script:IconFixture -Parent) -Force | Out-Null
	$ico = [System.Collections.Generic.List[byte]]::new()
	$ico.AddRange([byte[]](0, 0, 1, 0, 1, 0, 1, 1, 0, 0, 1, 0, 32, 0))
	$img = [System.Collections.Generic.List[byte]]::new()
	$img.AddRange([byte[]](40, 0, 0, 0, 1, 0, 0, 0, 2, 0, 0, 0, 1, 0, 32, 0, 0, 0, 0, 0, 0, 0, 0, 0))
	1..4 | ForEach-Object { $img.AddRange([byte[]](0, 0, 0, 0)) }
	$img.AddRange([byte[]](0, 0, 255, 255, 0, 0, 0, 0))
	$ico.AddRange([BitConverter]::GetBytes([uint32]$img.Count))
	$ico.AddRange([BitConverter]::GetBytes([uint32]22))
	$ico.AddRange($img)
	[System.IO.File]::WriteAllBytes($script:IconFixture, $ico.ToArray())
}

Add-Test @{
	Name  = 'exe21sp.normal'
	Group = 'exe21sp'
	Deps  = $deps
	Build = @{ Name = 'normal'; InputText = "Get-Date | Out-Null; Write-Output 'normal-embed'"; Output = 'normal.exe' }
	Run   = {
		param($ctx)
		$exe = $ctx.Builds['normal']
		$content = Get-Exe21spContent -ExePath $exe
		Assert-Match $content 'normal-embed' "exe21sp 未还原 normal 脚本：$content"
		$fromPipe = ($exe | exe21sp | Out-String)
		Assert-Match $fromPipe 'normal-embed' "exe21sp 管道输入未还原脚本：$fromPipe"
		$r = Invoke-ExeCaptureMergedOutput -ExePath $exe
		Assert-Match $r.Output 'normal-embed' 'normal exe 运行输出'
	}
}

Add-Test @{
	Name  = 'exe21sp.tinysharp'
	Group = 'exe21sp'
	Deps  = $deps
	Builds = @(
		@{ Name = 'c0'; InputText = "'tinysharp-console-zero'"; Output = 'ts_console_0.exe' }
		@{ Name = 'c42'; InputText = "'tinysharp-console-42'; exit 42"; Output = 'ts_console_42.exe' }
		@{ Name = 'g0'; InputText = "'tinysharp-gui-zero'"; Params = @{ App = @{ Windowed = $true }; Resources = @{ Title = 'CI' } }; Output = 'ts_gui_0.exe' }
		@{ Name = 'g42'; InputText = "'tinysharp-gui-42'; exit 42"; Params = @{ App = @{ Windowed = $true }; Resources = @{ Title = 'CI' } }; Output = 'ts_gui_42.exe' }
	)
	Run   = {
		param($ctx)
		$c0 = Get-Exe21spContent -ExePath $ctx.Builds['c0']
		Assert-Match $c0 'tinysharp-console-zero' "exe21sp TinySharp console 0 内容：$c0"
		& $ctx.Builds['c0'] | Out-Null
		Assert-Equal 0 $LASTEXITCODE 'ts_console_0 退出码'

		$c42 = Get-Exe21spContent -ExePath $ctx.Builds['c42']
		Assert-Match $c42 'tinysharp-console-42' "exe21sp TinySharp console 42 内容：$c42"
		Assert-Match $c42 'exit 42' "exe21sp TinySharp console 42 未保留 exit：$c42"
		& $ctx.Builds['c42'] | Out-Null
		Assert-Equal 42 $LASTEXITCODE 'ts_console_42 退出码'

		$g0 = Get-Exe21spContent -ExePath $ctx.Builds['g0']
		Assert-Match $g0 'tinysharp-gui-zero' "exe21sp TinySharp GUI 0 内容：$g0"
		$g42 = Get-Exe21spContent -ExePath $ctx.Builds['g42']
		Assert-Match $g42 'tinysharp-gui-42' "exe21sp TinySharp GUI 42 内容：$g42"
		Assert-Match $g42 'exit 42' "exe21sp TinySharp GUI 42 未保留 exit：$g42"
	}
}

Add-Test @{
	Name  = 'exe21sp.packed'
	Group = 'exe21sp'
	Deps  = $deps
	Build = @{ Name = 'packed'; InputText = "Get-Date | Out-Null; Write-Output 'packed-embed'"; Output = 'packed.exe' }
	Run   = {
		param($ctx)
		$content = Get-Exe21spContent -ExePath $ctx.Builds['packed']
		Assert-Match $content 'packed-embed' "exe21sp 未解包 packed 负载：$content"
	}
}

Add-Test @{
	Name  = 'exe21sp.core'
	Group = 'exe21sp'
	Deps  = $deps
	Build = @{ Name = 'core'; InputText = "Get-Date | Out-Null; Write-Output 'core-packed-embed'"; Params = @{ Build = @{ Target = 'Core' } }; Output = 'core_packed.exe' }
	Run   = {
		param($ctx)
		if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core 目标需要 .NET SDK（dotnet）' }
		$exe = $ctx.Builds['core']
		$content = Get-Exe21spContent -ExePath $exe
		Assert-Match $content 'core-packed-embed' "exe21sp Core 未还原：$content"

		# Windows PowerShell（.NET Framework 无 BrotliStream）下转交 pwsh 解压后同样能还原。
		$repoEsc = $ctx.RepoRoot -replace "'", "''"
		$exeEsc = $exe -replace "'", "''"
		$winPs = (& powershell -NoProfile -Command "Import-Module '$repoEsc' -Force; exe21sp -inputFile '$exeEsc'" 2>$null | Out-String)
		Assert-Match $winPs 'core-packed-embed' "exe21sp Core 在 Windows PowerShell 下未还原：$winPs"
	}
}

Add-Test @{
	Name  = 'exe21sp.save-file'
	Group = 'exe21sp'
	Deps  = $deps
	Build = @{ Name = 'normal'; InputText = "Get-Date | Out-Null; Write-Output 'normal-embed'"; Output = 'normal.exe' }
	Run   = {
		param($ctx)
		$exe = Copy-BuildAs -BuildPath $ctx.Builds['normal'] -WorkDir $ctx.WorkDir -Name 'savefile.exe'
		$expected = [System.IO.Path]::ChangeExtension($exe, '.ps1')
		if (Test-Path -LiteralPath $expected) { Remove-Item -LiteralPath $expected -Force }
		$exit = Invoke-Exe21spInPrivateConsole -RepoRoot $ctx.RepoRoot -ExePath $exe
		Assert-Equal 0 $exit 'exe21sp 私有 console 退出码'
		Assert-FileExists $expected 'exe21sp 未重定向时应写出 <exe>.ps1'
		Assert-Match (Get-Content -LiteralPath $expected -Raw -Encoding UTF8) 'normal-embed' '保存的 ps1 内容不符'
	}
}

Add-Test @{
	Name  = 'exe21sp.resources'
	Group = 'exe21sp'
	Deps  = $deps
	Build = @{
		Name    = 'resource'
		Output  = 'resource.exe'
		InputText = "Get-Date | Out-Null; Write-Output 'resource-roundtrip'"
		Params  = @{ Resources = @{ Title = 'RT Title'; Description = 'RT Desc'; Company = 'RT Co'; Version = '2.3.4.5'; Icon = $script:IconFixture } }
	}
	Run   = {
		param($ctx)
		$exe = Copy-BuildAs -BuildPath $ctx.Builds['resource'] -WorkDir $ctx.WorkDir -Name 'resource.exe'
		$extractOut = Join-Path $ctx.WorkDir 'resource.extracted.ps1'
		exe21sp -inputFile $exe -outputFile $extractOut | Out-Null
		$text = Get-Content -LiteralPath $extractOut -Raw -Encoding UTF8
		foreach ($expected in @("#_pragma Resources.Title 'RT Title'", "#_pragma Resources.Description 'RT Desc'", "#_pragma Resources.Company 'RT Co'", "#_pragma Resources.Version '2.3.4.5'", '#_pragma Resources.Icon')) {
			Assert-True ($text -like "*$expected*") "exe21sp 资源往返缺少 [$expected]：$text"
		}
		$releasedIcon = Join-Path $ctx.WorkDir 'resource.extracted.ico'
		Assert-FileExists $releasedIcon 'exe21sp 未释放图标到输出目录'

		$recompiled = Join-Path $ctx.WorkDir 'resource.recompiled.exe'
		ps12exe -inputFile $extractOut -outputFile $recompiled -NoUpdateCheck | Out-Null
		$info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($recompiled)
		Assert-Equal 'RT Title' $info.FileDescription 'exe21sp 重编译标题丢失'
		Assert-Equal 'RT Co' $info.CompanyName 'exe21sp 重编译公司丢失'
		Assert-Equal '2.3.4.5' $info.FileVersion 'exe21sp 重编译版本丢失'
		Assert-Match ((& $recompiled | Out-String)) 'resource-roundtrip' 'exe21sp 重编译运行输出不符'

		$extractOut2 = Join-Path $ctx.WorkDir 'resource.recompiled.ps1'
		exe21sp -inputFile $recompiled -outputFile $extractOut2 | Out-Null
		$text2 = Get-Content -LiteralPath $extractOut2 -Raw -Encoding UTF8
		Assert-Equal 1 ([regex]::Matches($text2, '(?m)^\s*#_pragma\s+Resources\.Title\b')).Count 'exe21sp 幂等性：Title pragma 重复'
		Assert-Equal 1 ([regex]::Matches($text2, '(?m)^\s*#_pragma\s+Resources\.Icon\b')).Count 'exe21sp 幂等性：Icon pragma 重复'
	}
}

Add-Test @{
	Name  = 'exe21sp.core-defaults'
	Group = 'exe21sp'
	Deps  = $deps
	Build = @{ Name = 'coreplain'; InputText = "Get-Date | Out-Null; Write-Output 'core-resource'"; Params = @{ Build = @{ Target = 'Core' } }; Output = 'core-resource-plain.exe' }
	Run   = {
		param($ctx)
		if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core 目标需要 .NET SDK（dotnet）' }
		$exe = Copy-BuildAs -BuildPath $ctx.Builds['coreplain'] -WorkDir $ctx.WorkDir -Name 'core-resource-plain.exe'
		$out = Join-Path $ctx.WorkDir 'core-resource-plain.ps1'
		exe21sp -inputFile $exe -outputFile $out | Out-Null
		$text = Get-Content -LiteralPath $out -Raw -Encoding UTF8
		foreach ($unexpected in @('#_pragma Resources.Company', '#_pragma Resources.Product', '#_pragma Resources.Version', '#_pragma Resources.Title')) {
			Assert-True ($text -notlike "*$unexpected*") "exe21sp Core 默认值不应补回 [$unexpected]：$text"
		}
	}
}

Add-Test @{
	Name   = 'exe21sp.windowed'
	Group  = 'exe21sp'
	Deps   = $deps
	Builds = @(
		@{ Name = 'win'; InputText = "Get-Date | Out-Null; Write-Output 'windowed-embed'"; Params = @{ App = @{ Windowed = $true } }; Output = 'windowed_std.exe' }
		@{ Name = 'con'; InputText = "Get-Date | Out-Null; Write-Output 'console-embed'"; Output = 'console_std.exe' }
		@{ Name = 'srcwin'; InputText = "#_pragma App.Windowed`nGet-Date | Out-Null; Write-Output 'srcwin-embed'"; Output = 'src_windowed.exe' }
		@{ Name = 'tsgui'; InputText = "'tinysharp-gui-windowed'"; Params = @{ App = @{ Windowed = $true }; Resources = @{ Title = 'CI' } }; Output = 'ts_windowed.exe' }
	)
	Run    = {
		param($ctx)
		$win = Get-Exe21spContent -ExePath $ctx.Builds['win']
		Assert-Match $win 'windowed-embed' "windowed 脚本内容：$win"
		Assert-Equal 1 ([regex]::Matches($win, '(?m)^\s*#_pragma\s+App\.Windowed\b')).Count "windowed exe 应补回一次 App.Windowed：$win"

		$con = Get-Exe21spContent -ExePath $ctx.Builds['con']
		Assert-Match $con 'console-embed' "console 脚本内容：$con"
		Assert-True ($con -notmatch '(?m)^\s*#_pragma\s+App\.Windowed\b') "console exe 不应补 App.Windowed：$con"

		$srcwin = Get-Exe21spContent -ExePath $ctx.Builds['srcwin']
		Assert-Match $srcwin 'srcwin-embed' "源码含 pragma 的脚本内容：$srcwin"
		Assert-Equal 1 ([regex]::Matches($srcwin, '(?m)^\s*#_pragma\s+App\.Windowed\b')).Count "源码已有 pragma 时不应重复：$srcwin"

		$tsgui = Get-Exe21spContent -ExePath $ctx.Builds['tsgui']
		Assert-Match $tsgui 'tinysharp-gui-windowed' "TinySharp windowed 脚本内容：$tsgui"
		Assert-Equal 1 ([regex]::Matches($tsgui, '(?m)^\s*#_pragma\s+App\.Windowed\b')).Count "TinySharp windowed 应补回 App.Windowed：$tsgui"
	}
}

Add-Test @{
	Name  = 'exe21sp.windowed-core'
	Group = 'exe21sp'
	Deps  = $deps
	Build = @{ Name = 'corewin'; InputText = "Get-Date | Out-Null; Write-Output 'core-windowed-embed'"; Params = @{ Build = @{ Target = 'Core' }; App = @{ Windowed = $true } }; Output = 'core_windowed.exe' }
	Run   = {
		param($ctx)
		if (-not (Get-Command dotnet -ErrorAction Ignore)) { throw 'Core 目标需要 .NET SDK（dotnet）' }
		$text = Get-Exe21spContent -ExePath $ctx.Builds['corewin']
		Assert-Match $text 'core-windowed-embed' "Core windowed 脚本内容：$text"
		Assert-Equal 1 ([regex]::Matches($text, '(?m)^\s*#_pragma\s+App\.Windowed\b')).Count "Core windowed 应补回 App.Windowed：$text"
	}
}
