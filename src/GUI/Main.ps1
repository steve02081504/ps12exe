[CmdletBinding()]
param (
	[ValidatePattern('.(psccfg|xml)$')]
	[string]$ConfingFile,
	#本地化信息
	[string]$Localize,
	[ValidateSet('Light', 'Dark', 'Auto')]
	[string]$UIMode = 'Auto',
	[ValidatePattern('.ps1$')]
	[string]$PS1File
)

. "$PSScriptRoot\UITools.ps1"

. "$PSScriptRoot\DialogLoader.ps1"

. "$PSScriptRoot\Functions.ps1"

. "$PSScriptRoot\AutoFixer.ps1"

. "$PSScriptRoot\Events.ps1"

. "$PSScriptRoot\DarkMode.ps1"

#region Other Actions Before ShowDialog

if ($ConfingFile) {
	# if file not exists or empty
	if (!(Test-Path $ConfingFile) -or (Get-Item $ConfingFile).Length -eq 0) {
		SetCfgFile $ConfingFile
	}
	else {
		LoadCfgFile $ConfingFile
	}
}

if ($PS1File) {
	if (-not $ConfingFile) {
		SetCfgFile "$($PS1File.Substring(0, $PS1File.LastIndexOf('.'))).psccfg"
	}
	$Script:refs.CompileFileTextBox.Text = "./$(Split-Path $PS1File -Leaf)" #以相对路径存储
}

try {
	Import-Module "$PSScriptRoot/../../ps12exe.psm1" -Force -ErrorAction Stop
}
catch {
	Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered when importing ps12exe."
}

#endregion Other Actions Before ShowDialog

# Set Console Window Title
$BackUpTitle = $Host.UI.RawUI.WindowTitle
$Host.UI.RawUI.WindowTitle = "ps12exe GUI Console Host"

# Set Console Icon
$consolePtr = [ps12exeGUI.Win32]::GetConsoleWindow()

[ps12exeGUI.Win32]::ShowWindow($consolePtr, 0) | Out-Null

$Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot\..\..\img\icon.ico")
$Script:refs.MainForm.Icon = $Icon

# Show the form
try { [void]$Script:refs.MainForm.ShowDialog() } catch { Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered unexpectedly at ShowDialog." }

# Dispose all controls
$Script:refs.MainForm.Controls | ForEach-Object { $_.Dispose() }
$Script:refs.MainForm.Dispose()
$Icon.Dispose()

[ps12exeGUI.Win32]::ShowWindow($consolePtr, 1) | Out-Null

# Restore Console Window Title
$Host.UI.RawUI.WindowTitle = $BackUpTitle

# Remove all variables in the script scope
Get-Variable -Scope Script | Remove-Variable -Scope Script -Force -ErrorAction Ignore
