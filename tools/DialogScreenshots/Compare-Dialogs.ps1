<#
.SYNOPSIS
	截图对比 ps12exe 窗口化产物的内置对话框与系统原生对话框，生成 HTML 报告并自动打开。
.DESCRIPTION
	对每个对话框场景，分别捕获三张图：
	  - 原生亮色：系统切到亮色时运行原生参照程序（tools/DialogScreenshots/native/NativeDialogs.cs）；
	  - 我们的亮色：ps12exe 产物 DarkMode=Off 时的弹窗；
	  - 我们的暗色：ps12exe 产物 DarkMode=On 时的弹窗。
	计算每张图两两之间的像素差异百分比并生成 diff 图，输出到临时目录下的 HTML，运行结束自动用默认浏览器打开。
	切换系统主题时会在 finally 中还原原始设置。要求：Windows、pwsh 7+。
.PARAMETER Scenario
	只处理指定场景，可传逗号分隔名称或多次指定。默认全部：msgbox,input,choice,readkey,constexpr,progress。
.EXAMPLE
	./Compare-Dialogs.ps1
.EXAMPLE
	./Compare-Dialogs.ps1 -Scenario msgbox,choice
#>
[CmdletBinding()]
param(
	[string[]]$Scenario = @('msgbox', 'input', 'choice', 'readkey', 'constexpr', 'progress')
)

$ErrorActionPreference = 'Stop'
$Scenario = @($Scenario | ForEach-Object { $_ -split ',' } | ForEach-Object { $_.Trim() } | Where-Object { $_ })
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '..\..')).Path
$tempRoot = Join-Path ([System.IO.Path]::GetTempPath()) ("ps12exe-dialogs-" + [Guid]::NewGuid().ToString('N').Substring(0, 8))
New-Item -ItemType Directory -Path $tempRoot -Force | Out-Null
Write-Host "Working directory: $tempRoot"

# ---------------------------------------------------------------------------
# 场景定义
# ---------------------------------------------------------------------------
# Source          -> ps12exe 编译的脚本（触发对应内置对话框）
# Title           -> 我们的产物窗口标题（= exe 名）
# NativeDialog    -> 原生参照程序的场景名
# NativeTitle     -> 原生参照窗口标题
$scenarios = [ordered]@{
	msgbox    = @{ Source = "Write-Warning 'This is a warning message'"; Title = 'dialog-msgbox'; NativeDialog = 'msgbox'; NativeTitle = 'dialog-msgbox' }
	input     = @{ Source = "`$name = Read-Host 'Input:'`r`nWrite-Host `"Hello `$name`""; Title = 'dialog-input'; NativeDialog = 'input'; NativeTitle = 'dialog-input' }
	choice    = @{ Source = "`$c = [System.Management.Automation.Host.ChoiceDescription[]]@('&One','&Two','&Three')`r`n`$null = `$Host.UI.PromptForChoice('dialog-choice','Pick one please',`$c,0)"; Title = 'dialog-choice'; NativeDialog = 'choice'; NativeTitle = 'dialog-choice' }
	readkey   = @{ Source = "`$null = `$Host.UI.RawUI.ReadKey('NoEcho, IncludeKeyDown')"; Title = 'dialog-readkey'; NativeDialog = 'readkey'; NativeTitle = 'dialog-readkey'; CloseKey = 'Escape' }
	constexpr = @{ Source = "'const-hello from ps12exe'"; Title = 'dialog-constexpr'; NativeDialog = 'constexpr'; NativeTitle = 'dialog-constexpr' }
	progress  = @{ Source = "Write-Progress -Activity 'Working' -Status 'Step 1' -PercentComplete 37; Start-Sleep -Seconds 30"; Title = 'dialog-progress'; NativeDialog = 'progress'; NativeTitle = 'dialog-progress' }
}

# ---------------------------------------------------------------------------
# 通用 P/Invoke 与截图
# ---------------------------------------------------------------------------
if (-not ('DialogShotsNative' -as [type])) {
	Add-Type -TypeDefinition @'
using System;
using System.Collections.Generic;
using System.Runtime.InteropServices;
using System.Text;
public static class DialogShotsNative {
	[StructLayout(LayoutKind.Sequential)] public struct RECT { public int Left, Top, Right, Bottom; }
	public sealed class WindowInfo { public long Handle; public string ClassName; public string Text; public RECT Rect; public bool Visible; }
	[DllImport("user32.dll")] public static extern bool SetProcessDPIAware();
	[DllImport("user32.dll")] public static extern bool EnumWindows(EnumWindowsProc callback, IntPtr lParam);
	[DllImport("user32.dll")] public static extern uint GetWindowThreadProcessId(IntPtr hwnd, out uint processId);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetClassNameW(IntPtr hwnd, StringBuilder text, int maxCount);
	[DllImport("user32.dll", CharSet=CharSet.Unicode)] public static extern int GetWindowTextW(IntPtr hwnd, StringBuilder text, int maxCount);
	[DllImport("user32.dll")] public static extern bool GetWindowRect(IntPtr hwnd, out RECT rect);
	[DllImport("user32.dll")] public static extern bool SetForegroundWindow(IntPtr hwnd);
	[DllImport("user32.dll")] public static extern bool IsWindowVisible(IntPtr hwnd);
	[DllImport("user32.dll", CharSet=CharSet.Unicode, SetLastError=true)] public static extern IntPtr SendMessageTimeout(IntPtr hWnd, uint Msg, IntPtr wParam, string lParam, uint flags, uint timeout, out IntPtr result);
	[DllImport("user32.dll")] public static extern bool PostMessage(IntPtr hWnd, uint Msg, IntPtr wParam, IntPtr lParam);
	public delegate bool EnumWindowsProc(IntPtr hwnd, IntPtr lParam);
	public static RECT GetWindowBounds(IntPtr hwnd) {
		RECT rect;
		GetWindowRect(hwnd, out rect);
		return rect;
	}
	public static List<WindowInfo> FindWindows(uint pid) {
		var result = new List<WindowInfo>();
		EnumWindowsProc callback = delegate(IntPtr hwnd, IntPtr ignored) {
			uint windowPid; GetWindowThreadProcessId(hwnd, out windowPid);
			if (windowPid == pid) {
				var name = new StringBuilder(256); GetClassNameW(hwnd, name, name.Capacity);
				var text = new StringBuilder(1024); GetWindowTextW(hwnd, text, text.Capacity);
				RECT rect = GetWindowBounds(hwnd);
				result.Add(new WindowInfo { Handle = hwnd.ToInt64(), ClassName = name.ToString(), Text = text.ToString(), Rect = rect, Visible = IsWindowVisible(hwnd) });
			}
			return true;
		};
		EnumWindows(callback, IntPtr.Zero);
		return result;
	}
}
'@
}

Add-Type -AssemblyName System.Drawing

function Invoke-Capture {
	param(
		[Parameter(Mandatory)] [string] $Exe,
		[string] $Title,
		[Parameter(Mandatory)] [string] $OutPng,
		[string[]] $Arguments = @(),
		[int] $WaitMs = 1500,
		[int] $TimeoutMs = 15000,
		[string] $CloseKey
	)
	[void][DialogShotsNative]::SetProcessDPIAware()
	$argList = @($Arguments | Where-Object { $_ -ne $null -and $_ -ne '' })
	if ($argList.Count -gt 0) { $process = Start-Process -FilePath $Exe -ArgumentList $argList -PassThru }
	else { $process = Start-Process -FilePath $Exe -PassThru }
	$deadline = [DateTime]::UtcNow.AddMilliseconds($TimeoutMs)
	$window = $null
	while ([DateTime]::UtcNow -lt $deadline) {
		$window = [DialogShotsNative]::FindWindows([uint32]$process.Id) | Where-Object { $_.Text -eq $Title -and $_.Visible } | Sort-Object { ($_.Rect.Right - $_.Rect.Left) * ($_.Rect.Bottom - $_.Rect.Top) } -Descending | Select-Object -First 1
		if ($null -ne $window) { break }
		if ($process.HasExited) { throw "进程在出现窗口前退出（退出码 $($process.ExitCode)）。" }
		Start-Sleep -Milliseconds 100
	}
	if ($null -eq $window) {
		if (!$process.HasExited) { $process.Kill() }
		throw "等待窗口超时（$Exe）。"
	}
	Start-Sleep -Milliseconds $WaitMs
	$handle = [IntPtr]::new([long]$window.Handle)
	[void][DialogShotsNative]::SetForegroundWindow($handle)
	Start-Sleep -Milliseconds 250
	$visibleWindow = [DialogShotsNative]::FindWindows([uint32]$process.Id) | Where-Object { $_.Text -eq $Title -and $_.Visible } | Sort-Object { ($_.Rect.Right - $_.Rect.Left) * ($_.Rect.Bottom - $_.Rect.Top) } -Descending | Select-Object -First 1
	if ($null -ne $visibleWindow) { $window = $visibleWindow }
	$width = $window.Rect.Right - $window.Rect.Left
	$height = $window.Rect.Bottom - $window.Rect.Top
	if ($width -lt 1 -or $height -lt 1) { throw "窗口矩形无效：$($window.Rect | ConvertTo-Json -Compress)" }
	$bitmap = [System.Drawing.Bitmap]::new($width, $height)
	$graphics = [System.Drawing.Graphics]::FromImage($bitmap)
	$graphics.CopyFromScreen($window.Rect.Left, $window.Rect.Top, 0, 0, [System.Drawing.Size]::new($width, $height))
	$graphics.Dispose()
	$bitmap.Save($OutPng, [System.Drawing.Imaging.ImageFormat]::Png)
	$bitmap.Dispose()
	if ($CloseKey) {
		Add-Type -AssemblyName System.Windows.Forms
		$key = [int][System.Windows.Forms.Keys]::$CloseKey
		[void][DialogShotsNative]::PostMessage($handle, 0x0100, [IntPtr]$key, [IntPtr]::Zero)
		[void][DialogShotsNative]::PostMessage($handle, 0x0101, [IntPtr]$key, [IntPtr]::Zero)
	}
	Start-Sleep -Milliseconds 200
	if (!$process.HasExited) { $process.Kill() }
	return @{ Width = $width; Height = $height }
}

# ---------------------------------------------------------------------------
# 像素差异：百分比 + diff 图（差异像素标红）
# ---------------------------------------------------------------------------
function Get-ImageDifference {
	param([string] $PathA, [string] $PathB, [string] $DiffOutPath, [int] $Threshold = 24)
	$imageA = [System.Drawing.Bitmap]::new($PathA)
	$imageB = [System.Drawing.Bitmap]::new($PathB)
	$width = [Math]::Max($imageA.Width, $imageB.Width)
	$height = [Math]::Max($imageA.Height, $imageB.Height)
	$diff = [System.Drawing.Bitmap]::new($width, $height, [System.Drawing.Imaging.PixelFormat]::Format32bppArgb)
	try {
		$format = [System.Drawing.Imaging.PixelFormat]::Format32bppArgb
		$rectA = [System.Drawing.Rectangle]::new(0, 0, $imageA.Width, $imageA.Height)
		$rectB = [System.Drawing.Rectangle]::new(0, 0, $imageB.Width, $imageB.Height)
		$rectD = [System.Drawing.Rectangle]::new(0, 0, $width, $height)
		$dataA = $imageA.LockBits($rectA, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $format)
		$dataB = $imageB.LockBits($rectB, [System.Drawing.Imaging.ImageLockMode]::ReadOnly, $format)
		$dataD = $diff.LockBits($rectD, [System.Drawing.Imaging.ImageLockMode]::WriteOnly, $format)
		try {
			$bufferA = [byte[]]::new($dataA.Stride * $imageA.Height)
			$bufferB = [byte[]]::new($dataB.Stride * $imageB.Height)
			$bufferD = [byte[]]::new($dataD.Stride * $height)
			[System.Runtime.InteropServices.Marshal]::Copy($dataA.Scan0, $bufferA, 0, $bufferA.Length)
			[System.Runtime.InteropServices.Marshal]::Copy($dataB.Scan0, $bufferB, 0, $bufferB.Length)
			$different = 0
			$total = $width * $height
			$strideA = $dataA.Stride; $strideB = $dataB.Stride; $strideD = $dataD.Stride
			for ($y = 0; $y -lt $height; $y++) {
				$rowA = $y * $strideA; $rowB = $y * $strideB; $rowD = $y * $strideD
				for ($x = 0; $x -lt $width; $x++) {
					$offsetA = $rowA + $x * 4; $offsetB = $rowB + $x * 4; $offsetD = $rowD + $x * 4
					$inA = $x -lt $imageA.Width -and $y -lt $imageA.Height
					$inB = $x -lt $imageB.Width -and $y -lt $imageB.Height
					$isDifferent = $true
					if ($inA -and $inB) {
						$delta = [Math]::Abs($bufferA[$offsetA + 2] - $bufferB[$offsetB + 2]) +
							[Math]::Abs($bufferA[$offsetA + 1] - $bufferB[$offsetB + 1]) +
							[Math]::Abs($bufferA[$offsetA] - $bufferB[$offsetB])
						$isDifferent = $delta -gt $Threshold * 3
					}
					if ($isDifferent) {
						$different++
						$bufferD[$offsetD + 3] = 255; $bufferD[$offsetD + 2] = 255; $bufferD[$offsetD + 1] = 0; $bufferD[$offsetD] = 0
						continue
					}
					$sourceOffset = $rowA + $x * 4
					$gray = [int](($bufferA[$sourceOffset + 2] + $bufferA[$sourceOffset + 1] + $bufferA[$sourceOffset]) / 3)
					$bufferD[$offsetD + 3] = 255; $bufferD[$offsetD + 2] = $gray; $bufferD[$offsetD + 1] = $gray; $bufferD[$offsetD] = $gray
				}
			}
			[System.Runtime.InteropServices.Marshal]::Copy($bufferD, 0, $dataD.Scan0, $bufferD.Length)
		} finally {
			$imageA.UnlockBits($dataA); $imageB.UnlockBits($dataB); $diff.UnlockBits($dataD)
		}
		$diff.Save($DiffOutPath, [System.Drawing.Imaging.ImageFormat]::Png)
		return [Math]::Round(100.0 * $different / $total, 2)
	} finally {
		$diff.Dispose(); $imageA.Dispose(); $imageB.Dispose()
	}
}

function ConvertTo-DataUri {
	param([string] $Path)
	$bytes = [System.IO.File]::ReadAllBytes($Path)
	return 'data:image/png;base64,' + [Convert]::ToBase64String($bytes)
}

# ---------------------------------------------------------------------------
# 系统主题切换
# ---------------------------------------------------------------------------
$personalizeKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
$originalTheme = Get-ItemProperty -Path $personalizeKey -Name AppsUseLightTheme -ErrorAction Ignore
$hadAppsUseLightTheme = $null -ne $originalTheme
$originalLight = $originalTheme.AppsUseLightTheme
if ($null -eq $originalLight) { $originalLight = 1 }

function Set-SystemLightTheme {
	param([int] $AppsUseLight)
	Set-ItemProperty -Path $personalizeKey -Name AppsUseLightTheme -Value $AppsUseLight
	$result = [IntPtr]::Zero
	[void][DialogShotsNative]::SendMessageTimeout([IntPtr]0xFFFF, 0x001A, [IntPtr]::Zero, 'ImmersiveColorSet', 0x0002, 2000, [ref]$result)
	Start-Sleep -Milliseconds 1200
}

# ---------------------------------------------------------------------------
# 准备：编译原生参照程序与各场景产物
# ---------------------------------------------------------------------------
$csc = Join-Path $env:WINDIR 'Microsoft.NET\Framework64\v4.0.30319\csc.exe'
$nativeExe = Join-Path $tempRoot 'NativeDialogs.exe'
Write-Host '编译原生参照程序...'
$nativeManifest = Join-Path $PSScriptRoot 'native\NativeDialogs.manifest'
& $csc /nologo /codepage:65001 /target:winexe "/win32manifest:$nativeManifest" "/out:$nativeExe" /reference:System.Windows.Forms.dll /reference:System.Drawing.dll (Join-Path $PSScriptRoot 'native\NativeDialogs.cs') 2>&1 | Out-Null
if (!(Test-Path -LiteralPath $nativeExe)) { throw '原生参照程序编译失败' }

Import-Module (Join-Path $repoRoot 'ps12exe.psm1') -Force

function New-Product {
	param([string] $Name, [string] $ProductTitle, [string] $Source, [string] $DarkMode)
	$dir = Join-Path $tempRoot "build-$Name"
	[void][System.IO.Directory]::CreateDirectory($dir)
	$scriptPath = Join-Path $dir "$Name.ps1"
	[System.IO.File]::WriteAllText($scriptPath, $Source, [System.Text.UTF8Encoding]::new($true))
	$exeName = $ProductTitle -replace '\.exe$', ''
	$exePath = Join-Path $dir "$exeName.exe"
	ps12exe -InputFile $scriptPath -OutputFile $exePath -App @{ Windowed = $true; DarkMode = $DarkMode } -Resources @{ Title = $ProductTitle } -Quiet | Out-Null
	if (!(Test-Path -LiteralPath $exePath)) { throw "编译失败：$Name" }
	return $exePath
}

$results = @()
try {
	# 亮色阶段：原生亮色 + 我们的亮色
	Write-Host '切换到系统亮色主题...'
	Set-SystemLightTheme 1
	foreach ($name in $Scenario | Select-Object -Unique) {
		$definition = $scenarios[$name]
		if ($null -eq $definition) { throw "未知场景：$name" }
		$dir = Join-Path $tempRoot $name
		[void][System.IO.Directory]::CreateDirectory($dir)
		Write-Host "== $name （亮色）=="
		$nativeOld = $env:NATIVE_DIALOG; $nativeTitleOld = $env:NATIVE_TITLE
		$env:NATIVE_DIALOG = $definition.NativeDialog; $env:NATIVE_TITLE = $definition.NativeTitle
		try { $size = Invoke-Capture -Exe $nativeExe -Title $definition.NativeTitle -OutPng (Join-Path $dir 'native-light.png') }
		finally { $env:NATIVE_DIALOG = $nativeOld; $env:NATIVE_TITLE = $nativeTitleOld }
		$ourLightExe = New-Product -Name "$name-light" -ProductTitle $definition.Title -Source $definition.Source -DarkMode 'Off'
		$closeKey = $definition['CloseKey']
		Invoke-Capture -Exe $ourLightExe -Title $definition.Title -OutPng (Join-Path $dir 'ours-light.png') -CloseKey $closeKey | Out-Null
		$results += [pscustomobject]@{ Name = $name; Dir = $dir; NativeSize = $size }
	}

	# 暗色阶段：我们的暗色
	Write-Host '切换到系统暗色主题...'
	Set-SystemLightTheme 0
	foreach ($entry in $results) {
		$name = $entry.Name
		$definition = $scenarios[$name]
		$dir = $entry.Dir
		Write-Host "== $name （暗色）=="
		$ourDarkExe = New-Product -Name "$name-dark" -ProductTitle $definition.Title -Source $definition.Source -DarkMode 'On'
		$closeKey = $definition['CloseKey']
		Invoke-Capture -Exe $ourDarkExe -Title $definition.Title -OutPng (Join-Path $dir 'ours-dark.png') -CloseKey $closeKey | Out-Null
	}
} finally {
	Write-Host '还原系统主题...'
	if ($hadAppsUseLightTheme) {
		Set-SystemLightTheme $originalLight
	} else {
		Remove-ItemProperty -Path $personalizeKey -Name AppsUseLightTheme -ErrorAction Ignore
		$result = [IntPtr]::Zero
		[void][DialogShotsNative]::SendMessageTimeout([IntPtr]0xFFFF, 0x001A, [IntPtr]::Zero, 'ImmersiveColorSet', 0x0002, 2000, [ref]$result)
	}
}

# ---------------------------------------------------------------------------
# 计算差异 + 生成 HTML
# ---------------------------------------------------------------------------
$rows = @()
foreach ($entry in $results) {
	$name = $entry.Name
	$dir = $entry.Dir
	$nativeLight = Join-Path $dir 'native-light.png'
	$oursLight = Join-Path $dir 'ours-light.png'
	$oursDark = Join-Path $dir 'ours-dark.png'
	$diffNativeOursLight = Join-Path $dir 'diff-native-vs-ours-light.png'
	$diffNativeOursDark = Join-Path $dir 'diff-native-vs-ours-dark.png'
	$diffOursLightDark = Join-Path $dir 'diff-ours-light-vs-dark.png'

	$pctNativeOursLight = Get-ImageDifference -PathA $nativeLight -PathB $oursLight -DiffOutPath $diffNativeOursLight
	$pctNativeOursDark = Get-ImageDifference -PathA $nativeLight -PathB $oursDark -DiffOutPath $diffNativeOursDark
	$pctOursLightDark = Get-ImageDifference -PathA $oursLight -PathB $oursDark -DiffOutPath $diffOursLightDark

	$rows += [pscustomobject]@{
		Name = $name
		NativeLight = $nativeLight
		OursLight = $oursLight
		OursDark = $oursDark
		DiffNativeOursLight = $diffNativeOursLight
		DiffNativeOursDark = $diffNativeOursDark
		DiffOursLightDark = $diffOursLightDark
		PctNativeOursLight = $pctNativeOursLight
		PctNativeOursDark = $pctNativeOursDark
		PctOursLightDark = $pctOursLightDark
	}
}

$htmlParts = New-Object System.Collections.Generic.List[string]
$htmlParts.Add(@'
<!DOCTYPE html>
<html lang="zh-CN"><head><meta charset="utf-8">
<title>ps12exe 对话框截图对比</title>
<style>
body{background:#1e1e1e;color:#ddd;font-family:Segoe UI,Microsoft YaHei,sans-serif;margin:24px}
h1{font-size:20px}
table{border-collapse:collapse;width:100%;margin-bottom:32px}
th,td{border:1px solid #444;padding:8px;vertical-align:top;text-align:center}
th{background:#2b2b2b;position:sticky;top:0}
img{max-width:320px;image-rendering:pixelated;border:1px solid #555;background:#000}
.pct{font-size:18px;color:#6cf}
.meta{color:#999;font-size:12px}
summary{cursor:pointer;color:#9cf}
</style></head><body>
<h1>ps12exe 内置对话框截图对比</h1>
<p class="meta">原始亮色 = 系统原生对话框；我们的亮色 = App.DarkMode=Off；我们的暗色 = App.DarkMode=On。差异百分比为像素级（阈值 24/通道），diff 图红色为差异像素。</p>
'@)

foreach ($row in $rows) {
	$htmlParts.Add("<details open><summary>$($row.Name) — 原生亮色 vs 我们的亮色 $($row.PctNativeOursLight)% / 原生亮色 vs 我们的暗色 $($row.PctNativeOursDark)% / 亮色 vs 暗色 $($row.PctOursLightDark)%</summary>")
	$htmlParts.Add('<table><tr><th>原生亮色</th><th>我们的亮色</th><th>我们的暗色</th></tr>')
	$htmlParts.Add("<tr><td><img src='$(ConvertTo-DataUri $row.NativeLight)'></td><td><img src='$(ConvertTo-DataUri $row.OursLight)'></td><td><img src='$(ConvertTo-DataUri $row.OursDark)'></td></tr>")
	$htmlParts.Add('<tr><th>diff：原生亮色 vs 我们的亮色</th><th>diff：原生亮色 vs 我们的暗色</th><th>diff：我们的亮色 vs 我们的暗色</th></tr>')
	$htmlParts.Add("<tr><td><img src='$(ConvertTo-DataUri $row.DiffNativeOursLight)'><div class='pct'>$($row.PctNativeOursLight)%</div></td><td><img src='$(ConvertTo-DataUri $row.DiffNativeOursDark)'><div class='pct'>$($row.PctNativeOursDark)%</div></td><td><img src='$(ConvertTo-DataUri $row.DiffOursLightDark)'><div class='pct'>$($row.PctOursLightDark)%</div></td></tr>")
	$htmlParts.Add('</table></details>')
}
$htmlParts.Add('</body></html>')

$htmlPath = Join-Path $tempRoot 'index.html'
[System.IO.File]::WriteAllText($htmlPath, ($htmlParts -join "`n"), [System.Text.UTF8Encoding]::new($false))
Write-Host "HTML 报告：$htmlPath"
Start-Process $htmlPath

Write-Host "临时目录（含所有图片）：$tempRoot"
