# 原生 DLL 导出（issue #3）：#_DllExport 应产出可被 native P/Invoke 调用的 .dll，
# 导出函数在首次调用时初始化 PowerShell 宿主、运行脚本，并调用其中的同名函数。
$deps = $script:CoreCompileDeps

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
		$dllFull = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($dll)

		$childBody = @"
`$src = @'
using System;
using System.Runtime.InteropServices;
public static class NativeExports {
  [DllImport(@"$dllFull", CallingConvention=CallingConvention.Cdecl, EntryPoint="Add")]
  public static extern int Add(int a, int b);
  [DllImport(@"$dllFull", CallingConvention=CallingConvention.Cdecl, EntryPoint="Store")]
  public static extern void Store(int v);
  [DllImport(@"$dllFull", CallingConvention=CallingConvention.Cdecl, EntryPoint="GetStored")]
  public static extern int GetStored();
  [DllImport(@"$dllFull", CallingConvention=CallingConvention.Cdecl, EntryPoint="Greet")]
  public static extern IntPtr Greet(string name);
}
'@
`$t = (Add-Type -TypeDefinition `$src -PassThru)[0]
Write-Output ("ADD=" + `$t::Add(20, 22))
`$t::Store(77)
Write-Output ("STORED=" + `$t::GetStored())
Write-Output ("GREET=" + [System.Runtime.InteropServices.Marshal]::PtrToStringAnsi(`$t::Greet('world')))
"@
		$child = Join-Path $ctx.WorkDir 'call-native.ps1'
		[System.IO.File]::WriteAllText($child, $childBody, [System.Text.UTF8Encoding]::new($true))

		# 用 64 位 Windows PowerShell（.NET Framework）加载 DLL 并 P/Invoke 导出函数。
		$powershell = Join-Path $env:SystemRoot 'System32\WindowsPowerShell\v1.0\powershell.exe'
		Assert-True (Test-Path -LiteralPath $powershell) '缺少 Windows PowerShell'
		$out = & $powershell -NoProfile -NonInteractive -ExecutionPolicy Bypass -File $child 2>&1 | Out-String
		Assert-Match $out 'ADD=42' "Add 导出返回值（实际输出：$out）"
		Assert-Match $out 'STORED=77' "void 导出与脚本状态（实际输出：$out）"
		Assert-Match $out 'GREET=hi world' "string 导出返回值（实际输出：$out）"
	}
}
