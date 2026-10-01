# 原生 DLL 导出（issue #3）：#_DllExport 应产出可被 native P/Invoke 调用的 .dll，
# 导出函数在首次调用时初始化 PowerShell 宿主、运行脚本，并调用其中的同名函数。
$deps = $script:CoreCompileDeps

# 大脚本：payload 会被 gzip 进 launcher，产物应远小于脚本本身。
$script:BigDllScript = @'
#_DllExport int Add(int a, int b)

function Add($a, $b) { return $a + $b }
'@ + "`n# " + ('DllExport-Compressed-OK 0123456789 abcdefghijklmnopqrstuvwxyz. ' * 2000) + "`n"

# 用 64 位 Windows PowerShell（.NET Framework）加载 DLL、P/Invoke 导出并回传输出。
# $Source 为含 @dll@ 占位符的 C# P/Invoke 定义，$Calls 为调用这些导出的 PowerShell 脚本。
# 存成 $script: 脚本块（用例文件里的普通函数在 Run 执行时已随 dot-source 作用域消失）。
$script:InvokeNativeExport = {
	param([string]$WorkDir, [string]$Name, [string]$DllPath, [string]$Source, [string]$Calls)
	$dllFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($DllPath)
	$childBody = @"
`$src = @'
$($Source.Replace('@dll@', $dllFull))
'@
`$t = (Add-Type -TypeDefinition `$src -PassThru)[0]
$Calls
"@
	$child = Join-Path $WorkDir $Name
	[System.IO.File]::WriteAllText($child, $childBody, [System.Text.UTF8Encoding]::new($true))
	$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
	Assert-True (Test-Path -LiteralPath $powershell) '缺少 Windows PowerShell'
	return & $powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $child 2>&1 | Out-String
}

Add-Test @{
	Name  = 'dllexport.native-x64'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'dll'
		InputText = @'
#_DllExport int Add(int a, int b)
#_DllExport void Store(int v)
#_DllExport int GetStored()
#_DllExport string Greet(string name)

param([string]$Unused)
$global:Stored = 0
function Add($a, $b) { return $a + $b }
function Store($v) { $global:Stored = $v }
function GetStored() { return $global:Stored }
function Greet($name) { return "hi $name" }
'@
		Params    = @{ Build = @{ Platform = 'x64' } }
		Output    = 'dllexport.dll'
	}
	Run   = {
		param($ctx)
		$dll = $ctx.Builds['dll']
		Assert-FileExists $dll 'DLL 未产出'
		$out = & $script:InvokeNativeExport -WorkDir $ctx.WorkDir -Name 'call-native.ps1' -DllPath $dll -Source @'
using System;
using System.Runtime.InteropServices;
public static class NativeExports {
  [DllImport(@"@dll@", CallingConvention=CallingConvention.Cdecl, EntryPoint="Add")]
  public static extern int Add(int a, int b);
  [DllImport(@"@dll@", CallingConvention=CallingConvention.Cdecl, EntryPoint="Store")]
  public static extern void Store(int v);
  [DllImport(@"@dll@", CallingConvention=CallingConvention.Cdecl, EntryPoint="GetStored")]
  public static extern int GetStored();
  [DllImport(@"@dll@", CallingConvention=CallingConvention.Cdecl, EntryPoint="Greet")]
  public static extern IntPtr Greet(string name);
}
'@ -Calls @'
Write-Output ("ADD=" + $t::Add(20, 22))
$t::Store(77)
Write-Output ("STORED=" + $t::GetStored())
Write-Output ("GREET=" + [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi($t::Greet('world')))
'@
		Assert-Match $out 'ADD=42' "Add 导出返回值（实际输出：$out）"
		Assert-Match $out 'STORED=77' "void 导出与脚本状态（实际输出：$out）"
		Assert-Match $out 'GREET=hi world' "string 导出返回值（实际输出：$out）"
	}
}

Add-Test @{
	Name  = 'dllexport.compressed'
	Group = 'ps12exe'
	Deps  = $deps
	Build = @{
		Name      = 'big'
		InputText = $script:BigDllScript
		Params    = @{ Build = @{ Platform = 'x64' } }
		Output    = 'dllexport_big.dll'
	}
	Run   = {
		param($ctx)
		$dll = $ctx.Builds['big']
		Assert-FileExists $dll 'DLL 未产出'
		$size = (Get-Item -LiteralPath $dll).Length
		# 未压缩时产物 ≈ 帧 + 脚本（约 200 KB）；gzip 进 launcher 后应远小于脚本长度。
		Assert-True ($size -lt ($script:BigDllScript.Length / 4)) "DllExport 压缩产物应远小于脚本（脚本 $($script:BigDllScript.Length)，产物 $size）"
		$out = & $script:InvokeNativeExport -WorkDir $ctx.WorkDir -Name 'call-native-big.ps1' -DllPath $dll -Source @'
using System;
using System.Runtime.InteropServices;
public static class NativeExports {
  [DllImport(@"@dll@", CallingConvention=CallingConvention.Cdecl, EntryPoint="Add")]
  public static extern int Add(int a, int b);
}
'@ -Calls 'Write-Output ("ADD=" + $t::Add(40, 2))'
		Assert-Match $out 'ADD=42' "压缩产物 Add 导出返回值（实际输出：$out）"
	}
}
