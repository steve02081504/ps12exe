. "$PSScriptRoot\UITools.ps1"

. "$PSScriptRoot\DialogLoader.ps1"

. "$PSScriptRoot\Functions.ps1"

. "$PSScriptRoot\AutoFixer.ps1"

. "$PSScriptRoot\DarkMode.ps1"

. "$PSScriptRoot\Events.ps1"

#region Other Actions Before ShowDialog

if ($ConfigFile) {
	[string]$Script:ConfigFile = Resolve-Path -LiteralPath $ConfigFile
	# if file not exists or empty
	if (!(Test-Path $ConfigFile) -or (Get-Item $ConfigFile).Length -eq 0) {
		SetCfgFile $ConfigFile
	}
	else {
		LoadCfgFile $ConfigFile
	}
}

if ($PS1File) {
	[string]$PS1File = Resolve-Path -LiteralPath $PS1File
	if (-not $Script:ConfigFile) {
		SetCfgFile "$($PS1File.Substring(0, $PS1File.LastIndexOf('.'))).psccfg"
	}
	# 计算相对于$ConfigFile的相对路径
	$PS1FilePath = Resolve-Path -LiteralPath $PS1File -Relative -RelativeBasePath (Split-Path $ConfigFile)
	if (!$PS1FilePath) { $PS1FilePath = "./$(Split-Path $PS1File -Leaf)" }
	$Script:refs.CompileFileTextBox.Text = $PS1FilePath
}

try {
	Import-Module "$PSScriptRoot/../../ps12exe.psm1" -Force -ErrorAction Stop
}
catch {
	Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered when importing ps12exe."
}

#endregion Other Actions Before ShowDialog

# Set Console Window Title
try {
	# Hide Console Window
	$consolePtr = [ps12exeGUI.Win32]::GetConsoleWindow()
	[ps12exeGUI.Win32]::ShowWindow($consolePtr, 0) | Out-Null

	$Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot\..\..\img\icon.ico")
	$Script:refs.MainForm.Icon = $Icon

	# load bgm
	$FS = New-Object -ComObject Scripting.FileSystemObject
	$bgmFile = $FS.GetFile("$PSScriptRoot\..\bin\Unravel.mid")
	[ps12exeGUI.Win32]::mciSendString("open `"$($bgmFile.ShortPath)`" alias ps12exeGUIBGM type MPEGVideo", $null, 0, 0) | Out-Null
	# play music as loop
	$IsAlreadyPlayingSomething = [ps12exeGUI.Win32]::IsPlayingSound()
	[ps12exeGUI.Win32]::mciSendString("play ps12exeGUIBGM repeat", $null, 0, 0) | Out-Null
	if ($IsAlreadyPlayingSomething) { PauseMusic }

	# Show the form
	try { [void]$Script:refs.MainForm.ShowDialog() } catch { Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered unexpectedly at ShowDialog." }
}
finally {
	# Dispose all controls
	foreach ($Ctrl in $Script:refs.Values) {
		@('Icon', 'BackGroundImage') | ForEach-Object {
			if ($Ctrl.$_ -is [IDisposable]) { $Ctrl.$_.Dispose() }
		}
		$Ctrl.Dispose()
	}
	foreach ($key in $Script:dialogInfo.Keys) {
		$Dlg = Get-Variable -Name $key -ValueOnly
		$Dlg.Dispose()
	}

	[ps12exeGUI.Win32]::ShowWindow($consolePtr, 1) | Out-Null

	[ps12exeGUI.Win32]::mciSendString("close ps12exeGUIBGM", $null, 0, 0) | Out-Null

	# Remove all variables in the script scope
	Get-Variable -Scope Script | Remove-Variable -Scope Script -Force -ErrorAction Ignore
}
