# 进程/EXE 运行辅助：合并输出捕获、独立 console、向进程窗口发送回车并关闭对话框。
$ErrorActionPreference = 'Stop'

# 经 cmd 把 stdout/stderr 接到同一文件，保留进程内写入顺序，规避 Windows PowerShell native stderr 抛 NativeCommandError。
function Invoke-ExeCaptureMergedOutput {
	param(
		[string]$ExePath,
		[string[]]$Arguments = @(),
		[int]$TimeoutSeconds = 60
	)
	$exePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ExePath)
	if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) { throw "Exe not found: $exePath" }
	$outFile = Join-Path ([System.IO.Path]::GetDirectoryName($exePath)) ('merged-{0}.txt' -f [guid]::NewGuid().ToString('N'))
	$argLine = if ($Arguments.Count) { ($Arguments -join ' ') + ' ' } else { '' }
	$cmdLine = '"{0}" {1}1>"{2}" 2>&1' -f $exePath, $argLine, $outFile
	$psi = [System.Diagnostics.ProcessStartInfo]@{
		FileName         = $env:ComSpec
		Arguments        = "/s /c `"$cmdLine`""
		UseShellExecute  = $false
		CreateNoWindow   = $true
		WorkingDirectory = [System.IO.Path]::GetDirectoryName($exePath)
	}
	$p = [System.Diagnostics.Process]::Start($psi)
	try {
		if (-not $p.WaitForExit($TimeoutSeconds * 1000)) { throw "Merged-output exe timed out: $exePath" }
		return [pscustomobject]@{
			ExitCode = $p.ExitCode
			Output   = (Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue)
		}
	}
	finally {
		if (-not $p.HasExited) { Stop-ProcessTree -ProcessId $p.Id }
		$p.Dispose()
		Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
	}
}

# 给控制台 EXE 单独开 hidden console，避免当前进程 stdout 已重定向时子进程继承管道（TTY/isatty 类测试）。
function Invoke-ExeWithPrivateConsole {
	param(
		[string]$ExePath,
		[int]$TimeoutSeconds = 60,
		[string]$WorkingDirectory
	)
	$exePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ExePath)
	if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) { throw "Exe not found: $exePath" }
	if (-not $WorkingDirectory) { $WorkingDirectory = [System.IO.Path]::GetDirectoryName($exePath) }
	$p = Start-Process -FilePath $exePath -WorkingDirectory $WorkingDirectory -PassThru -WindowStyle Hidden
	try {
		if (-not $p.WaitForExit($TimeoutSeconds * 1000)) { throw "Private console exe timed out: $exePath" }
		return $p.ExitCode
	}
	finally {
		if (-not $p.HasExited) { Stop-ProcessTree -ProcessId $p.Id }
	}
}

if (-not ('CIWindowHelper' -as [type])) {
	Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class CIWindowHelper {
	[DllImport("user32.dll", SetLastError = true)]
	private static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
	[DllImport("user32.dll")]
	private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
	[DllImport("user32.dll")]
	private static extern bool IsWindowVisible(IntPtr hWnd);
	[DllImport("user32.dll")]
	private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
	private const uint WM_KEYDOWN = 0x0100;
	private const uint WM_KEYUP   = 0x0101;
	private const uint WM_COMMAND = 0x0111;
	private const uint WM_CLOSE   = 0x0010;
	private const int  VK_RETURN  = 0x0D;
	private const int  IDOK       = 1;
	public static bool SendEnterToProcessMainWindow(int processId) {
		IntPtr target = IntPtr.Zero;
		FindWindowByProcessId((uint)processId, ref target);
		if (target == IntPtr.Zero) return false;
		// 消息要经对话框管理器 IsDialogMessage 才生效，而它只处理活动窗口；后台桌面上回车会被丢弃。
		// 同时投递 WM_COMMAND(IDOK) 与 WM_CLOSE，以兼容原生消息框和自绘 WinForms 对话框。
		PostMessage(target, WM_KEYDOWN, (IntPtr)VK_RETURN, IntPtr.Zero);
		PostMessage(target, WM_KEYUP,   (IntPtr)VK_RETURN, IntPtr.Zero);
		PostMessage(target, WM_COMMAND, (IntPtr)IDOK, IntPtr.Zero);
		PostMessage(target, WM_CLOSE,   IntPtr.Zero, IntPtr.Zero);
		return true;
	}
	public static bool ClickFirstButtonInProcessMainWindow(int processId) {
		IntPtr target = IntPtr.Zero;
		FindWindowByProcessId((uint)processId, ref target);
		if (target == IntPtr.Zero) return false;
		bool clicked = false;
		EnumChildWindows(target, (hWnd, lp) => {
			if (IsWindowVisible(hWnd)) {
				StringBuilder className = new StringBuilder(256);
				if (GetClassName(hWnd, className, className.Capacity) > 0 && className.ToString().StartsWith("WindowsForms10.BUTTON", StringComparison.Ordinal)) {
					clicked = PostMessage(hWnd, 0x00F5, IntPtr.Zero, IntPtr.Zero);
					return false;
				}
			}
			return true;
		}, IntPtr.Zero);
		return clicked;
	}
	private static void FindWindowByProcessId(uint targetPid, ref IntPtr result) {
		IntPtr[] found = new IntPtr[1];
		EnumWindows((hWnd, lp) => {
			uint pid;
			GetWindowThreadProcessId(hWnd, out pid);
			if (pid == targetPid && IsWindowVisible(hWnd)) {
				StringBuilder sb = new StringBuilder(256);
				if (GetClassName(hWnd, sb, sb.Capacity) > 0 && (sb.ToString() == "#32770" || sb.ToString().StartsWith("WindowsForms10.Window", StringComparison.Ordinal))) {
					found[0] = hWnd;
					return false;
				}
			}
			return true;
		}, IntPtr.Zero);
		result = found[0];
	}
	private delegate bool EnumWindowsProc(IntPtr hWnd, IntPtr lParam);
	[DllImport("user32.dll")]
	private static extern bool EnumWindows(EnumWindowsProc lpEnumFunc, IntPtr lParam);
	[DllImport("user32.dll")]
	private static extern bool EnumChildWindows(IntPtr hWndParent, EnumWindowsProc lpEnumFunc, IntPtr lParam);
}
'@ -ReferencedAssemblies System
}

# 启动 exe，持续向其主消息框发送回车/WM_COMMAND，直到退出或超时。返回退出码。
function Invoke-ExeAndSendEnterToWindow {
	param(
		[string]$ExePath,
		[int]$TimeoutSeconds = 25,
		[string]$WorkingDirectory
	)
	$exePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ExePath)
	if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) { throw "Exe not found: $exePath" }
	if (-not $WorkingDirectory) { $WorkingDirectory = [System.IO.Path]::GetDirectoryName($exePath) }
	$psi = [System.Diagnostics.ProcessStartInfo]@{
		FileName         = $exePath
		UseShellExecute  = $true
		CreateNoWindow   = $false
		WorkingDirectory = $WorkingDirectory
	}
	$p = [System.Diagnostics.Process]::Start($psi)
	$sawWindow = $false
	try {
		$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
		while ([DateTime]::UtcNow -lt $deadline -and -not $p.HasExited) {
			if ([CIWindowHelper]::SendEnterToProcessMainWindow($p.Id)) { $sawWindow = $true }
			Start-Sleep -Milliseconds 200
		}
		if (-not $p.HasExited) { [void]$p.WaitForExit(2000) }
	}
	finally {
		if (-not $p.HasExited) {
			Write-Warning ("Invoke-ExeAndSendEnterToWindow: killed {0} after {1}s (window seen: {2})" -f $ExePath, $TimeoutSeconds, $sawWindow)
			Stop-ProcessTree -ProcessId $p.Id
		}
	}
	return $p.ExitCode
}

# 把缓存的构建产物复制到用例私有目录，避免并行用例互相踩文件。
function Copy-BuildAs {
	param(
		[string]$BuildPath,
		[string]$WorkDir,
		[string]$Name
	)
	if (-not $Name) { $Name = [System.IO.Path]::GetFileName($BuildPath) }
	$dest = Join-Path $WorkDir $Name
	New-Item -ItemType Directory -Path $WorkDir -Force | Out-Null
	Copy-Item -LiteralPath $BuildPath -Destination $dest -Force
	return $dest
}

function Wait-ForPath {
	param([string]$Path, [int]$TimeoutSeconds = 20)
	$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
	while (-not (Test-Path -LiteralPath $Path) -and [DateTime]::UtcNow -lt $deadline) { Start-Sleep -Milliseconds 250 }
	return (Test-Path -LiteralPath $Path)
}

# exe21sp 在 stdout 被重定向时把还原出的脚本写到 stdout；worker 的 stdout 始终重定向，故可直接捕获。
function Get-Exe21spContent {
	param([string]$ExePath)
	return (exe21sp -inputFile $ExePath | Out-String)
}

# 让 PS2EXE2ps12exe 兼容层能按模块名发现 ps12exe：把仓库父目录挂到 PSModulePath（仓库文件夹名即 ps12exe），再导入 shim。
function Initialize-Ps2exeShim {
	param([string]$RepoRoot)
	$parent = Split-Path -Path $RepoRoot -Parent
	if ((Split-Path -Path $RepoRoot -Leaf) -eq 'ps12exe') {
		if (($env:PSModulePath -split ';') -notcontains $parent) { $env:PSModulePath = "$parent;$env:PSModulePath" }
	}
	else {
		throw "仓库文件夹名不是 ps12exe（$RepoRoot），无法按模块名发现；请重命名或改用 junction 版本。"
	}
	Import-Module (Join-Path $RepoRoot 'src/.subrepo/PS2EXE2ps12exe/PS2EXE2ps12exe.psd1') -Force
}

# 在独立（非重定向）console 中运行 root exe21sp.ps1，用于验证“未重定向时写 <exe>.ps1”的分支。
function Invoke-Exe21spInPrivateConsole {
	param([string]$RepoRoot, [string]$ExePath, [int]$TimeoutSeconds = 60)
	$exe21sp = Join-Path $RepoRoot 'exe21sp.ps1'
	$pwsh = (Get-Process -Id $PID).Path
	$p = Start-Process -FilePath $pwsh -ArgumentList @('-NoProfile', '-NonInteractive', '-File', $exe21sp, '-inputFile', $ExePath) -PassThru -WindowStyle Hidden
	try {
		if (-not $p.WaitForExit($TimeoutSeconds * 1000)) { throw "private-console exe21sp timed out: $ExePath" }
		return $p.ExitCode
	}
	finally { if (-not $p.HasExited) { Stop-ProcessTree -ProcessId $p.Id } }
}
