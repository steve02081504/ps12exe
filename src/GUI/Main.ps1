[CmdletBinding()]
param (
	[string]$ConfingFile,
	#本地化信息
	[string]$Localize,
	[ValidateSet('Light', 'Dark', 'Auto')]
	[string]$UIMode = 'Auto'
)

. "$PSScriptRoot\UITools.ps1"

. "$PSScriptRoot\DialogLoader.ps1"

. "$PSScriptRoot\Functions.ps1"

. "$PSScriptRoot\AutoFixer.ps1"

. "$PSScriptRoot\Events.ps1"

. "$PSScriptRoot\DarkMode.ps1"

#region Other Actions Before ShowDialog

try {
	Import-Module "$PSScriptRoot/../../ps12exe.psm1" -Force -ErrorAction Stop
}
catch {
	Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered when importing ps12exe."
}

#endregion Other Actions Before ShowDialog

# Hide Console Window
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

$consolePtr = [Console.Window]::GetConsoleWindow()
[Console.Window]::ShowWindow($consolePtr, 0) | Out-Null

$Icon = [System.Drawing.Icon]::ExtractAssociatedIcon("$PSScriptRoot\..\..\img\icon.ico")
$Script:refs.MainForm.Icon = $Icon

# Show the form
try { [void]$Script:refs.MainForm.ShowDialog() } catch { Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered unexpectedly at ShowDialog." }

# Dispose all controls
$Script:refs.MainForm.Controls | ForEach-Object { $_.Dispose() }
$Script:refs.MainForm.Dispose()
$Icon.Dispose()

[Console.Window]::ShowWindow($consolePtr, 1) | Out-Null

# Remove all variables in the script scope
Get-Variable -Scope Script | Remove-Variable -Scope Script -Force -ErrorAction Ignore
