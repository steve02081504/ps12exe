# CI 测试辅助：无状态右键菜单保存/恢复、向目标窗口发送回车、GitHub Actions 友好错误输出
$ErrorActionPreference = 'Stop'

$ContextMenuKey = 'Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\ps12exeCompile'

# 与旧版 CI 一致的 GitHub 友好错误格式：::group::PSVersion、::error file=,line=、::group::script stack trace、::group::error details。调用后 exit 1。
function Write-CIGitHubErrorReport {
	if (-not $error -or $error.Count -eq 0) { return }
	Write-Output '::group::PSVersion'
	Write-Output $PSVersionTable
	Write-Output '::endgroup::'
	$error | ForEach-Object {
		Write-Output "::error file=$($_.InvocationInfo.ScriptName),line=$($_.InvocationInfo.ScriptLineNumber),col=$($_.InvocationInfo.OffsetInLine),endColumn=$($_.InvocationInfo.OffsetInLine),tittle=error::$_"
		Write-Output '::group::script stack trace'
		Write-Output $_.ScriptStackTrace
		Write-Output '::endgroup::'
		Write-Output '::group::error details'
		Write-Output $_
		Write-Output '::endgroup::'
	}
	exit 1
}

function Get-ps12exeContextMenuState {
	Test-Path -LiteralPath $ContextMenuKey -ErrorAction SilentlyContinue
}

function Save-ps12exeContextMenuState {
	[bool](Get-ps12exeContextMenuState)
}

function Restore-ps12exeContextMenuState {
	param([bool]$WasEnabled)
	$repoRoot = $env:REPO_ROOT
	if (-not $repoRoot) { $repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }
	Import-Module $repoRoot -Force -ErrorAction Stop
	if ($WasEnabled) {
		Set-ps12exeContextMenu -action enable
	} else {
		Set-ps12exeContextMenu -action disable
	}
}

# 启动 exe，向该进程的主窗口持续发送 VK_RETURN（用于关闭 MessageBox），直到进程退出或超时。
# 返回进程的 ExitCode（等待进程退出后读取）。
# $TimeoutSeconds: 从启动到强制结束的总超时。
function Invoke-ExeAndSendEnterToWindow {
	param(
		[string]$ExePath,
		[int]$TimeoutSeconds = 15
	)
	$exePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ExePath)
	if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
		throw "Exe not found: $exePath"
	}
	Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
using System.Text;
public class CIWindowHelper {
	[DllImport("user32.dll", SetLastError = true)]
	private static extern IntPtr FindWindowEx(IntPtr parent, IntPtr after, string className, string title);
	[DllImport("user32.dll", SetLastError = true)]
	private static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
	[DllImport("user32.dll")]
	private static extern int GetClassName(IntPtr hWnd, StringBuilder lpClassName, int nMaxCount);
	[DllImport("kernel32.dll")]
	private static extern uint GetProcessId(IntPtr process);
	[DllImport("user32.dll")]
	private static extern uint GetWindowThreadProcessId(IntPtr hWnd, out uint processId);
	private const uint WM_KEYDOWN = 0x0100;
	private const uint WM_KEYUP   = 0x0101;
	private const int  VK_RETURN  = 0x0D;
	public static bool SendEnterToProcessMainWindow(int processId) {
		IntPtr target = IntPtr.Zero;
		FindWindowByProcessId((uint)processId, ref target);
		if (target == IntPtr.Zero) return false;
		PostMessage(target, WM_KEYDOWN, (IntPtr)VK_RETURN, IntPtr.Zero);
		PostMessage(target, WM_KEYUP,   (IntPtr)VK_RETURN, IntPtr.Zero);
		return true;
	}
	private static void FindWindowByProcessId(uint targetPid, ref IntPtr result) {
		IntPtr[] found = new IntPtr[1];
		EnumWindows((hWnd, lp) => {
			uint pid;
			GetWindowThreadProcessId(hWnd, out pid);
			if (pid == targetPid) {
				StringBuilder sb = new StringBuilder(256);
				if (GetClassName(hWnd, sb, sb.Capacity) > 0 && sb.ToString() == "#32770") {
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
}
'@ -ReferencedAssemblies System
	$psi = [System.Diagnostics.ProcessStartInfo]@{
		FileName               = $exePath
		UseShellExecute         = $true
		CreateNoWindow          = $false
		WorkingDirectory        = [System.IO.Path]::GetDirectoryName($exePath)
	}
	$p = [System.Diagnostics.Process]::Start($psi)
	$sawWindow = $false
	try {
		# 窗口可能在消息框完成初始化（设置默认按钮）之前就被枚举到，此时发出的回车会被丢弃。
		# 因此找到窗口后不能只发一次就停，必须持续发到进程退出为止。
		$deadline = [DateTime]::UtcNow.AddSeconds($TimeoutSeconds)
		while ([DateTime]::UtcNow -lt $deadline -and -not $p.HasExited) {
			if ([CIWindowHelper]::SendEnterToProcessMainWindow($p.Id)) { $sawWindow = $true }
			Start-Sleep -Milliseconds 200
		}
		# 最后一次回车后的退出宽限，避免刚点掉消息框就被 Kill。
		if (-not $p.HasExited) { $p.WaitForExit(2000) | Out-Null }
	} finally {
		if (-not $p.HasExited) {
			Write-Warning ("Invoke-ExeAndSendEnterToWindow: killed {0} after {1}s (window seen: {2})" -f $ExePath, $TimeoutSeconds, $sawWindow)
			$p.Kill()
		}
	}
	return $p.ExitCode
}

# 强杀进程树（超时时 cmd 的 kill 不会带走子进程，孤儿会继续占用/锁住文件）。
function Stop-ProcessTree {
	param([int]$ProcessId)
	if ($ProcessId -le 0) { return }
	try {
		& "$env:SystemRoot\System32\taskkill.exe" /PID $ProcessId /T /F 2>&1 | Out-Null
	} catch {}
}

# 经 cmd 把 stdout/stderr 接到同一文件，保留进程内写入顺序。
function Invoke-ExeCaptureMergedOutput {
	param(
		[string]$ExePath,
		[int]$TimeoutSeconds = 30
	)
	$exePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ExePath)
	if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
		throw "Exe not found: $exePath"
	}
	$outFile = Join-Path ([System.IO.Path]::GetDirectoryName($exePath)) ('merged-{0}.txt' -f [guid]::NewGuid().ToString('N'))
	$cmdLine = '"{0}" 1>"{1}" 2>&1' -f $exePath, $outFile
	$psi = [System.Diagnostics.ProcessStartInfo]@{
		FileName         = $env:ComSpec
		Arguments        = "/s /c `"$cmdLine`""
		UseShellExecute  = $false
		CreateNoWindow   = $true
		WorkingDirectory = [System.IO.Path]::GetDirectoryName($exePath)
	}
	$p = [System.Diagnostics.Process]::Start($psi)
	try {
		if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
			throw "Merged-output exe timed out: $exePath"
		}
		$output = Get-Content -LiteralPath $outFile -Raw -ErrorAction SilentlyContinue
		return [pscustomobject]@{
			ExitCode = $p.ExitCode
			Output   = $output
		}
	} finally {
		if (-not $p.HasExited) { Stop-ProcessTree -ProcessId $p.Id }
		$p.Dispose()
		Remove-Item -LiteralPath $outFile -Force -ErrorAction SilentlyContinue
	}
}

# 给控制台 EXE 单独开一个 hidden console，避免当前进程 stdout 已重定向时子进程继承管道。
# 用于 TTY / isatty 类测试：结果应写文件，不要靠捕获本函数的 stdout。
function Invoke-ExeWithPrivateConsole {
	param(
		[string]$ExePath,
		[int]$TimeoutSeconds = 30
	)
	$exePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ExePath)
	if (-not (Test-Path -LiteralPath $exePath -PathType Leaf)) {
		throw "Exe not found: $exePath"
	}
	$p = Start-Process -FilePath $exePath -WorkingDirectory ([System.IO.Path]::GetDirectoryName($exePath)) -PassThru -WindowStyle Hidden
	try {
		if (-not $p.WaitForExit($TimeoutSeconds * 1000)) {
			throw "Private console exe timed out: $exePath"
		}
		return $p.ExitCode
	} finally {
		if (-not $p.HasExited) { Stop-ProcessTree -ProcessId $p.Id }
	}
}
