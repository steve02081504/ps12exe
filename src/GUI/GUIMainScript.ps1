. "$PSScriptRoot\UItools.ps1"

#region Locale Data

$Script:LocalizeData = ."$PSScriptRoot/../LocaleLoader.ps1" -Locale $Locale -LoadLocaleData {
	param (
		[string]$Locale
	)
	$Script:LocalizeData = &"$LocalizeDir\$Locale.ps1"
} -CheckLocaleData {
	$null -ne $Script:LocalizeData -and $null -ne $Script:LocalizeData.GUI
} -FailedLoadLocaleData {
	param (
		[string]$Locale
	)
	[System.Windows.Forms.MessageBox]::Show("Failed to load locale data $Locale`nSee $LocalizeDir/README.md for how to add custom locale.", "ps12exe GUI locale Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
}

#endregion Locale Data

. "$PSScriptRoot\Functions.ps1"

. "$PSScriptRoot\Schema.ps1"

. "$PSScriptRoot\Layout.ps1"

. "$PSScriptRoot\Compile.ps1"

. "$PSScriptRoot\DarkMode.ps1"

. "$PSScriptRoot\Events.ps1"

#region Other Actions Before ShowDialog

$Script:GUISchema = Get-GUISchema

$Script:refs = @{}
$Script:FieldControls = @{}
$Script:FieldBrowse = @{}
New-GUIForm | Out-Null
$Script:dialogs = New-GUIDialogs

Update-UIState
Set-DarkMode $Script:DarkMode
Register-GUIEvents

if ($ConfigFile) {
	[string]$Script:ConfigFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($ConfigFile)
	# 如果文件不存在或为空
	if (!(Test-Path -LiteralPath $Script:ConfigFile) -or (Get-Item -LiteralPath $Script:ConfigFile).Length -eq 0) {
		SetCfgFile $Script:ConfigFile
	}
	else {
		LoadCfgFile $Script:ConfigFile
	}
}

if ($PS1File) {
	[string]$PS1File = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($PS1File)
	if (-not $Script:ConfigFile) {
		SetCfgFile "$($PS1File.Substring(0, $PS1File.LastIndexOf('.'))).psccfg"
	}
	# 计算相对于配置文件目录的相对路径（不用 pwsh 7.4+ 的 -RelativeBasePath）
	$ConfigDir = Split-Path -Path $Script:ConfigFile -Parent
	$PS1FilePath = Get-RelativePath $PS1File $ConfigDir
	if (!$PS1FilePath) { $PS1FilePath = "./$(Split-Path $PS1File -Leaf)" }
	$Script:refs.CompileFileTextBox.Text = $PS1FilePath
}

#endregion Other Actions Before ShowDialog

# 设置控制台窗口标题
try {
	# 隐藏控制台窗口
	$consolePtr = [ps12exeGUI.Win32]::GetConsoleWindow()
	[ps12exeGUI.Win32]::ShowWindow($consolePtr, 0) | Out-Null

	$Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot\..\..\img\icon.ico")
	$Script:refs.MainForm.Icon = $Icon
	$Script:refs.MainForm.StartPosition = 'CenterScreen'

	# 加载背景音乐
	$FS = New-Object -ComObject Scripting.FileSystemObject
	$bgmFile = $FS.GetFile("$PSScriptRoot\..\bin\Unravel.mid")
	[ps12exeGUI.Win32]::mciSendString("open `"$($bgmFile.ShortPath)`" alias ps12exeGUIBGM type MPEGVideo", $null, 0, 0) | Out-Null
	# 循环播放音乐
	$IsAlreadyPlayingSomething = [ps12exeGUI.Win32]::IsPlayingSound()
	[ps12exeGUI.Win32]::mciSendString("play ps12exeGUIBGM repeat", $null, 0, 0) | Out-Null
	if ($IsAlreadyPlayingSomething) { PauseMusic }

	# 显示窗体
	try { [void]$Script:refs.MainForm.ShowDialog() } catch { Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered unexpectedly at ShowDialog." }
}
finally {
	# 停掉深色模式跟随定时器
	if ($Script:DarkModeTimer) {
		$Script:DarkModeTimer.Stop()
		$Script:DarkModeTimer.Dispose()
		$Script:DarkModeTimer = $null
	}

	# 释放窗体和文件对话框
	if ($Script:refs.MainForm) { $Script:refs.MainForm.Dispose() }
	if ($Script:dialogs) {
		foreach ($dialog in $Script:dialogs.Values) {
			if ($dialog -is [IDisposable]) { $dialog.Dispose() }
		}
	}

	[ps12exeGUI.Win32]::ShowWindow($consolePtr, 1) | Out-Null

	[ps12exeGUI.Win32]::mciSendString("close ps12exeGUIBGM", $null, 0, 0) | Out-Null

	# 移除脚本作用域中的所有变量
	Get-Variable -Scope Script | Remove-Variable -Scope Script -Force -ErrorAction Ignore
}
