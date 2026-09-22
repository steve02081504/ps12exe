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
	Name   = 'exe21sp.tinysharp'
	Group  = 'exe21sp'
	Deps   = $deps
	Builds = @(
		@{ Name = 'c0'; InputText = "'tinysharp-console-zero'"; Output = 'ts_console_0.exe' }
		@{ Name = 'c42'; InputText = "'tinysharp-console-42'; exit 42"; Output = 'ts_console_42.exe' }
		@{ Name = 'g0'; InputText = "'tinysharp-gui-zero'"; Params = @{ App = @{ Windowed = $true }; Resources = @{ Title = 'CI' } }; Output = 'ts_gui_0.exe' }
		@{ Name = 'g42'; InputText = "'tinysharp-gui-42'; exit 42"; Params = @{ App = @{ Windowed = $true }; Resources = @{ Title = 'CI' } }; Output = 'ts_gui_42.exe' }
	)
	Run    = {
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
		Assert-Match $content "(?m)^#_pragma\s+Build\.Target\s+'Core'$" "exe21sp Core 未补 Build.Target：$content"

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
		Name      = 'resource'
		Output    = 'resource.exe'
		InputText = "Get-Date | Out-Null; Write-Output 'resource-roundtrip'"
		Params    = @{ Resources = @{ Title = 'RT Title'; Description = 'RT Desc'; Company = 'RT Co'; Product = 'resource'; Version = '2.3.4.5'; Icon = $script:IconFixture } }
	}
	Run   = {
		param($ctx)
		$exe = Copy-BuildAs -BuildPath $ctx.Builds['resource'] -WorkDir $ctx.WorkDir -Name 'resource.exe'
		$extractOut = Join-Path $ctx.WorkDir 'resource.extracted.ps1'
		exe21sp -inputFile $exe -outputFile $extractOut | Out-Null
		$text = Get-Content -LiteralPath $extractOut -Raw -Encoding UTF8
		foreach ($expected in @("#_pragma Resources.Title 'RT Title'", "#_pragma Resources.Description 'RT Desc'", "#_pragma Resources.Company 'RT Co'", "#_pragma Resources.Product 'resource'", "#_pragma Resources.Version '2.3.4.5'", '#_pragma Resources.Icon')) {
			Assert-True ($text -like "*$expected*") "exe21sp 资源往返缺少 [$expected]：$text"
		}
		$releasedIcon = Join-Path $ctx.WorkDir 'resource.extracted.ico'
		Assert-FileExists $releasedIcon 'exe21sp 未释放图标到输出目录'

		$recompiled = Join-Path $ctx.WorkDir 'resource.recompiled.exe'
		ps12exe -inputFile $extractOut -outputFile $recompiled -NoUpdateCheck | Out-Null
		$info = [System.Diagnostics.FileVersionInfo]::GetVersionInfo($recompiled)
		Assert-Equal 'RT Title' $info.FileDescription 'exe21sp 重编译标题丢失'
		Assert-Equal 'RT Co' $info.CompanyName 'exe21sp 重编译公司丢失'
		Assert-Equal 'resource' $info.ProductName 'exe21sp 重编译产品名丢失'
		Assert-Equal '2.3.4.5' $info.FileVersion 'exe21sp 重编译版本丢失'
		Assert-Match ((& $recompiled | Out-String)) 'resource-roundtrip' 'exe21sp 重编译运行输出不符'

		$extractOut2 = Join-Path $ctx.WorkDir 'resource.recompiled.ps1'
		exe21sp -inputFile $recompiled -outputFile $extractOut2 | Out-Null
		$text2 = Get-Content -LiteralPath $extractOut2 -Raw -Encoding UTF8
		Assert-Equal 1 ([regex]::Matches($text2, '(?m)^\s*#_pragma\s+Resources\.Title\b')).Count 'exe21sp 幂等性：Title pragma 重复'
		Assert-Equal 1 ([regex]::Matches($text2, '(?m)^\s*#_pragma\s+Resources\.Product\b')).Count 'exe21sp 幂等性：Product pragma 重复'
		Assert-Equal 1 ([regex]::Matches($text2, '(?m)^\s*#_pragma\s+Resources\.Icon\b')).Count 'exe21sp 幂等性：Icon pragma 重复'
		Assert-NotMatch $text2 '(?m)#_!!#_pragma\s+Resources' "exe21sp 幂等性：资源 pragma 被转义累积：$text2"
	}
}

Add-Test @{
	Name  = 'exe21sp.roundtrip-stable'
	Group = 'exe21sp'
	Deps  = $deps
	Run   = {
		param($ctx)
		# 产物重新推导的 pragma（App.Windowed / Resources.*）不得随往返次数累积膨胀：
		# exe21sp 会先删掉同名旧行，再只补一份规范行。
		$work = $ctx.WorkDir
		$ps1 = Join-Path $work 'cycle.ps1'
		[System.IO.File]::WriteAllText($ps1, "#_pragma App.Windowed`n#_pragma Resources.Title 'Stable Title'`nGet-Date | Out-Null`nWrite-Output 'cycle'", [System.Text.UTF8Encoding]::new($true))
		$sizes = [System.Collections.Generic.List[int64]]::new()
		foreach ($i in 1..3) {
			$exe = Join-Path $work 'cycle.exe'
			ps12exe -inputFile $ps1 -outputFile $exe -NoUpdateCheck | Out-Null
			exe21sp -inputFile $exe -outputFile $ps1 | Out-Null
			$sizes.Add((Get-Item -LiteralPath $ps1).Length)
		}
		$text = Get-Content -LiteralPath $ps1 -Raw -Encoding UTF8
		Assert-Equal $sizes[0] $sizes[1] "往返一次后字节数变化（膨胀）：$($sizes -join ',')"
		Assert-Equal $sizes[1] $sizes[2] "往返两次后字节数变化（膨胀）：$($sizes -join ',')"
		Assert-NotMatch $text '(?m)#_!!#_pragma' "往返累积了被转义的 pragma：$text"
		Assert-Equal 1 ([regex]::Matches($text, '(?m)^\s*#_pragma\s+App\.Windowed\b')).Count "App.Windowed 行不唯一：$text"
		Assert-Equal 1 ([regex]::Matches($text, '(?m)^\s*#_pragma\s+Resources\.Title\b')).Count "Resources.Title 行不唯一：$text"
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

Add-Test @{
	Name   = 'exe21sp.require'
	Group  = 'exe21sp'
	Deps   = $deps
	Builds = @(
		@{ Name = 'single'; InputText = "#_require ps12exe`nWrite-Output 'require-single'"; Output = 'require_single.exe' }
		@{ Name = 'multi'; InputText = "#_require ps12exe`n#_require foo-bar`nWrite-Output 'require-multi'"; Output = 'require_multi.exe' }
		# 非完全匹配（把 -ea Stop 改成 -ea Continue）应原样保留，不误还原。
		@{ Name = 'fake'; InputText = "if(!(gmo ps12exe -ListAvailable -ea SilentlyContinue)){try{Import-PackageProvider NuGet}catch{Install-PackageProvider NuGet -Scope CurrentUser -Force -ea Ignore;Import-PackageProvider NuGet -ea Ignore};Install-Module ps12exe -Scope CurrentUser -Force -ea Continue}`nWrite-Output 'require-fake'"; Output = 'require_fake.exe' }
	)
	Run    = {
		param($ctx)
		$single = Get-Exe21spContent -ExePath $ctx.Builds['single']
		Assert-Match $single '(?m)^#_require ps12exe\s*$' "单模块 #_require 未还原：$single"
		Assert-NotMatch $single 'Install-Module' "单模块头代码未被替换：$single"

		$multi = Get-Exe21spContent -ExePath $ctx.Builds['multi']
		Assert-Match $multi '(?m)^#_require ps12exe\s*$' "多模块第一行未还原：$multi"
		Assert-Match $multi '(?m)^#_require foo-bar\s*$' "多模块第二行未还原：$multi"
		Assert-NotMatch $multi 'Install-Module' "多模块头代码未被替换：$multi"

		$fake = Get-Exe21spContent -ExePath $ctx.Builds['fake']
		Assert-NotMatch $fake '(?m)^#_require' "非完全匹配不应还原：$fake"
		Assert-Match $fake 'Install-Module ps12exe' "非完全匹配应保留原头代码：$fake"

		# 往返：还原出的 #_require 重新编译后应再次还原为同样的 #_require。
		$rtInput = Join-Path $ctx.WorkDir 'require_rt.ps1'
		[System.IO.File]::WriteAllText($rtInput, $single, [System.Text.UTF8Encoding]::new($false))
		$rtExe = Join-Path $ctx.WorkDir 'require_rt.exe'
		ps12exe -inputFile $rtInput -outputFile $rtExe -NoUpdateCheck | Out-Null
		$rt = Get-Exe21spContent -ExePath $rtExe
		Assert-Match $rt '(?m)^#_require ps12exe\s*$' "往返后 #_require 丢失：$rt"
	}
}

Add-Test @{
	Name  = 'exe21sp.escape-preprocessor-directives'
	Group = 'exe21sp'
	Deps  = $deps
	Run   = {
		param($ctx)
		# 目标：任意 exe 往返一次（反编译 → 重编译）后有效内容不变，攻击者无法通过脚本里的指令改变它；
		# 指令行只会作为注释留存。exe21sp 给所有残留 #_ 指令补回 #_!!，有效的也一并转义（变成注释）。
		$work = $ctx.WorkDir
		$attackerOut = Join-Path $work 'attacker-chosen.exe'
		$marker = Join-Path $work 'minify-ran.txt'
		$content = @(
			"#_!!#_pragma outputFile `"$attackerOut`""
			"#_!!#_pragma Build.Minify 'Set-Content -LiteralPath `"$marker`" -Value ran'"
			'#_pragma Build.ConstEval.Enabled 0'
			'#_!!#_if PSScript'
			"#_!!Write-Output 'psscript-branch'"
			'#_!!#_endif'
			'#_!!#_require ps12exe'
			'Get-Date | Out-Null'
			"Write-Output 'escape-roundtrip'"
		) -join "`n"
		$src = Join-Path $work 'danger.ps1'
		[System.IO.File]::WriteAllText($src, $content, [System.Text.UTF8Encoding]::new($true))
		$exe = Join-Path $work 'danger.exe'
		ps12exe -inputFile $src -outputFile $exe -NoUpdateCheck | Out-Null
		Assert-False (Test-Path -LiteralPath $attackerOut) '原始编译时被转义的 outputFile 不应生效'
		Assert-False (Test-Path -LiteralPath $marker) '原始编译时被转义的 Build.Minify 不应执行'

		$extracted = Join-Path $work 'danger.extracted.ps1'
		exe21sp -inputFile $exe -outputFile $extracted | Out-Null
		$text = Get-Content -LiteralPath $extracted -Raw -Encoding UTF8
		Assert-Match $text '(?m)^#_!!#_pragma outputFile\b' "exe21sp 未给 outputFile 补回 #_!!：$text"
		Assert-Match $text '(?m)^#_!!#_pragma Build\.Minify\b' "exe21sp 未给 Build.Minify 补回 #_!!：$text"
		Assert-Match $text '(?m)^#_!!#_pragma Build\.ConstEval\.Enabled 0\b' "exe21sp 未给有效 pragma 补回 #_!!（应作为注释留存）：$text"
		Assert-Match $text '(?m)^#_!!#_if PSScript\b' "exe21sp 未给 #_if 补回 #_!!：$text"
		Assert-Match $text '(?m)^#_!!#_require ps12exe\b' "exe21sp 未给 #_require 补回 #_!!：$text"

		# 模拟 VSC 插件写回：重新编译还原出的脚本，残留指令必须全部保持惰性且原行为不变。
		$recompiled = Join-Path $work 'danger.recompiled.exe'
		ps12exe -inputFile $extracted -outputFile $recompiled -NoUpdateCheck | Out-Null
		Assert-FileExists $recompiled '重编译未产出用户指定路径的 exe'
		Assert-False (Test-Path -LiteralPath $attackerOut) '重编译时被转义的 outputFile 被激活'
		Assert-False (Test-Path -LiteralPath $marker) '重编译时被转义的 Build.Minify 被激活'

		# 有效内容不变：原始 exe 与往返后 exe 的运行输出必须一致。
		$before = Invoke-ExeCaptureMergedOutput -ExePath $exe
		$after = Invoke-ExeCaptureMergedOutput -ExePath $recompiled
		Assert-Match $before.Output 'psscript-branch' "原始产物缺少分支代码：$($before.Output)"
		Assert-Equal $before.Output $after.Output '往返后有效输出发生变化'
	}
}

Add-Test @{
	Name   = 'exe21sp.derived-config'
	Group  = 'exe21sp'
	Deps   = $deps
	Builds = @(
		@{ Name = 'anycpu'; InputText = "Get-Date | Out-Null`nWrite-Output 'd-anycpu'"; Output = 'd_anycpu.exe' }
		@{ Name = 'x64'; InputText = "Get-Date | Out-Null`nWrite-Output 'd-x64'"; Params = @{ Build = @{ Platform = 'x64' } }; Output = 'd_x64.exe' }
		@{ Name = 'x86'; InputText = "Get-Date | Out-Null`nWrite-Output 'd-x86'"; Params = @{ Build = @{ Platform = 'x86' } }; Output = 'd_x86.exe' }
		@{ Name = 'admin'; InputText = "Get-Date | Out-Null`nWrite-Output 'd-admin'"; Params = @{ Os = @{ Admin = $true } }; Output = 'd_admin.exe' }
		@{ Name = 'balus'; InputText = "#_balus `$LASTEXITCODE`nGet-Date | Out-Null`nWrite-Output 'd-balus'"; Output = 'd_balus.exe' }
		@{ Name = 'fw20'; InputText = "Get-Date | Out-Null`nWrite-Output 'd-fw20'"; Params = @{ Build = @{ Target = 'Framework2.0' } }; Output = 'd_fw20.exe' }
	)
	Run    = {
		param($ctx)
		# Build.Platform / Os.Admin / Build.Target 从产物 PE 推导；#_balus 从展开出的自删除代码还原。
		$work = $ctx.WorkDir
		$any = Get-Exe21spContent -ExePath $ctx.Builds['anycpu']
		Assert-NotMatch $any '(?m)^#_pragma\s+Build\.Platform\b' "anycpu 不应补 Build.Platform：$any"
		Assert-NotMatch $any '(?m)^#_pragma\s+Build\.Target\b' "Framework4.0 不应补 Build.Target：$any"
		$x64 = Get-Exe21spContent -ExePath $ctx.Builds['x64']
		Assert-Match $x64 "(?m)^#_pragma\s+Build\.Platform\s+'x64'$" "x64 未补 Build.Platform：$x64"
		$x86 = Get-Exe21spContent -ExePath $ctx.Builds['x86']
		Assert-Match $x86 "(?m)^#_pragma\s+Build\.Platform\s+'x86'$" "x86 未补 Build.Platform：$x86"
		$admin = Get-Exe21spContent -ExePath $ctx.Builds['admin']
		Assert-Match $admin '(?m)^#_pragma\s+Os\.Admin$' "admin 未补 Os.Admin：$admin"
		$balus = Get-Exe21spContent -ExePath $ctx.Builds['balus']
		Assert-Match $balus '(?m)^#_balus \$LASTEXITCODE$' "balus 未还原 #_balus：$balus"
		$fw20 = Get-Exe21spContent -ExePath $ctx.Builds['fw20']
		# 只有装了 PowerShell 2.0 引擎时 Framework2.0 才会产出 CLR v2 元数据（v2.0.50727）并可被推导；
		# 否则编译降级为 CLR v4，产物与 Framework4.0 无异，推导不出也无需补行。
		$hasPs2 = $false
		try {
			$ps2Version = & powershell -version 2.0 -NoProfile -Command '[System.Environment]::Version' 2>$null | Select-Object -First 1
			$hasPs2 = $ps2Version -and ([version]$ps2Version).Major -lt 3
		}
		catch {}
		if ($hasPs2) {
			Assert-Match $fw20 "(?m)^#_pragma\s+Build\.Target\s+'Framework2\.0'$" "fw20 未补 Build.Target：$fw20"
		}
		else {
			Assert-NotMatch $fw20 '(?m)^#_pragma\s+Build\.Target\b' "降级的 fw20 不应补 Build.Target：$fw20"
		}

		# 往返稳定：重新编译还原出的脚本再提取，推导出的配置 pragma / #_balus 不重复不膨胀。
		$rtCases = @(
			@{ name = 'x64'; pattern = "(?m)^#_pragma\s+Build\.Platform\s+'x64'$" },
			@{ name = 'admin'; pattern = '(?m)^#_pragma\s+Os\.Admin$' },
			@{ name = 'balus'; pattern = '(?m)^#_balus\b' }
		)
		if ($hasPs2) {
			$rtCases += @{ name = 'fw20'; pattern = "(?m)^#_pragma\s+Build\.Target\s+'Framework2\.0'$" }
		}
		foreach ($case in $rtCases) {
			$ps1 = Join-Path $work "$($case.name).derived.ps1"
			exe21sp -inputFile $ctx.Builds[$case.name] -outputFile $ps1 | Out-Null
			$recompiled = Join-Path $work "$($case.name).derived.exe"
			ps12exe -inputFile $ps1 -outputFile $recompiled -NoUpdateCheck | Out-Null
			$ps1b = Join-Path $work "$($case.name).derived2.ps1"
			exe21sp -inputFile $recompiled -outputFile $ps1b | Out-Null
			$text = Get-Content -LiteralPath $ps1b -Raw -Encoding UTF8
			Assert-Equal 1 ([regex]::Matches($text, $case.pattern)).Count "往返 $($case.name) 后行不唯一：$text"
		}
	}
}
