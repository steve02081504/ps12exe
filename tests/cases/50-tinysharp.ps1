# TinySharp 运行测试：控制台输出与退出码、压缩负载、动态上限。
$script:TsDeps = $script:CoreCompileDeps

$script:BigOutput = 'TinySharp-Compressed-OK 0123456789 abcdefghijklmnopqrstuvwxyz. ' * 60
$script:HugeOutput = 'TinySharp-Dynamic-Limit-OK line abcdefghijklmnopqrstuvwxyz 0123456789. ' * 400
$script:BigGui = 'TinySharp-GUI-Compressed-OK 0123456789 abcdefghijklmnopqrstuvwxyz. ' * 60

Add-Test @{
	Name  = 'tinysharp.console'
	Group = 'tinysharp'
	Deps  = $script:TsDeps
	Build = @{ Name = 'console'; InputText = "'TinySharp-Console-OK'"; Output = 'ts_console.exe' }
	Run   = {
		param($ctx)
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['console']
		Assert-Match $r.Output 'TinySharp-Console-OK' 'TinySharp 控制台输出'
		Assert-Equal 0 $r.ExitCode 'TinySharp 控制台退出码'
	}
}

Add-Test @{
	Name  = 'tinysharp.compressed'
	Group = 'tinysharp'
	Deps  = $script:TsDeps
	Build = @{ Name = 'compressed'; InputText = "'$($script:BigOutput)'"; Output = 'ts_compressed.exe' }
	Run   = {
		param($ctx)
		$rawSize = [Text.Encoding]::UTF8.GetByteCount($script:BigOutput)
		$compressedSize = (Get-Item -LiteralPath $ctx.Builds['compressed']).Length
		Assert-True ($compressedSize -lt $rawSize) "TinySharp 压缩壳应小于原文（$rawSize），实际 $compressedSize"
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['compressed']
		Assert-Equal $script:BigOutput ($r.Output.TrimEnd("`r", "`n")) 'TinySharp 压缩输出不符'
		Assert-Equal 0 $r.ExitCode 'TinySharp 压缩退出码'
	}
}

Add-Test @{
	Name  = 'tinysharp.dynamic-limit'
	Group = 'tinysharp'
	Deps  = $script:TsDeps
	Build = @{ Name = 'dynamic'; InputText = "'$($script:HugeOutput)'"; Output = 'ts_dynamic.exe' }
	Run   = {
		param($ctx)
		$size = (Get-Item -LiteralPath $ctx.Builds['dynamic']).Length
		Assert-True ($size -lt 14kb) "超过 12.5KB 但可压缩的常量仍应走 TinySharp 壳（~14.5KB），实际 $size"
		$r = Invoke-ExeCaptureMergedOutput -ExePath $ctx.Builds['dynamic']
		Assert-Equal $script:HugeOutput ($r.Output.TrimEnd("`r", "`n")) 'TinySharp 动态上限输出不符'
	}
}

Add-Test @{
	Name   = 'ps12exe.constexpr.gui'
	Group  = 'ps12exe'
	Deps   = $script:TsDeps
	Builds = @(
		@{ Name = 'gui'; InputText = "'TinySharp-GUI-OK'"; Params = @{ App = @{ Windowed = $true; DarkMode = 'Off' }; Resources = @{ Title = 'CITitle' } }; Output = 'ts_gui.exe' }
		@{ Name = 'guicompressed'; InputText = "'$($script:BigGui)'"; Params = @{ App = @{ Windowed = $true; DarkMode = 'Off' } }; Output = 'ts_gui_compressed.exe' }
	)
	Run    = {
		param($ctx)
		$exitCode = Invoke-ExeAndSendEnterToWindow -ExePath $ctx.Builds['gui'] -TimeoutSeconds 20
		Assert-Equal 0 $exitCode 'constexpr GUI 退出码'

		$exitCompressed = Invoke-ExeAndSendEnterToWindow -ExePath $ctx.Builds['guicompressed'] -TimeoutSeconds 20
		Assert-Equal 0 $exitCompressed 'constexpr GUI 长文本退出码'
	}
}

Add-Test @{
	Name  = 'tinysharp.unicode-redirect'
	Group = 'tinysharp'
	Deps  = $script:TsDeps
	Build = @{ Name = 'unicode'; InputText = "'A世界B'"; Output = 'ts_unicode.exe' }
	Run   = {
		param($ctx)
		$exe = $ctx.Builds['unicode']
		$size = (Get-Item -LiteralPath $exe).Length
		Assert-True ($size -lt 4096) "非 ASCII 常量仍应走 TinySharp 常量壳（<4KB），实际 $size"
		$r = Invoke-ExeCaptureMergedOutput -ExePath $exe
		Assert-Match $r.Output 'A世界B' "非 ASCII 常量在 stdout 被重定向时丢失输出：[$($r.Output)]"

		# 真实控制台（非重定向）下走 WriteConsoleW 分支，不应崩溃。
		Assert-Equal 0 (Invoke-ExeWithPrivateConsole -ExePath $exe) '非 ASCII 常量在真实控制台下的退出码'

		$content = Get-Exe21spContent -ExePath $exe
		Assert-Match $content 'A世界B' "exe21sp 未能还原非 ASCII 常量：$content"
	}
}
