# TinySharp 运行测试：控制台/GUI 输出与退出码、压缩负载、动态上限。
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
	Name  = 'tinysharp.gui'
	Deps  = $script:TsDeps
	Builds = @(
		@{ Name = 'gui'; InputText = "'TinySharp-GUI-OK'"; Params = @{ App = @{ Windowed = $true }; Resources = @{ Title = 'CITitle' } }; Output = 'ts_gui.exe' }
		@{ Name = 'guicompressed'; InputText = "'$($script:BigGui)'"; Params = @{ App = @{ Windowed = $true } }; Output = 'ts_gui_compressed.exe' }
	)
	Run   = {
		param($ctx)
		$exitCode = Invoke-ExeAndSendEnterToWindow -ExePath $ctx.Builds['gui'] -TimeoutSeconds 20
		Assert-Equal 0 $exitCode 'TinySharp GUI 退出码'

		$guiSize = (Get-Item -LiteralPath $ctx.Builds['guicompressed']).Length
		$rawUtf16 = [Text.Encoding]::Unicode.GetByteCount($script:BigGui)
		Assert-True ($guiSize -lt $rawUtf16) "TinySharp GUI 压缩壳应小于 UTF-16 原文（$rawUtf16），实际 $guiSize"
		$exitCompressed = Invoke-ExeAndSendEnterToWindow -ExePath $ctx.Builds['guicompressed'] -TimeoutSeconds 20
		Assert-Equal 0 $exitCompressed 'TinySharp GUI 压缩退出码'
	}
}


