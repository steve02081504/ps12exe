[CmdletBinding()]
param (
	[string]$ConfingFile,
	#本地化信息
	[string]$Localize,
	[ValidateSet('Light', 'Dark', 'Auto')]
	[string]$UIMode = 'Auto'
)

# ScriptBlock to Execute in STA Runspace
$sbGUI = {
	param($BaseDir, $ConfingFile, $Localize, $UIMode)
	
	. "$BaseDir\UITools.ps1"

	. "$BaseDir\DialogLoader.ps1"

	. "$BaseDir\Functions.ps1"

	. "$BaseDir\Events.ps1"

	. "$BaseDir\DarkMode.ps1"

	#region Other Actions Before ShowDialog

	try {
		Import-Module "$BaseDir/../../ps12exe.psm1" -Force -ErrorAction Stop
	}
	catch {
		Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered when importing ps12exe."
	}

	try {
		Remove-Variable -Name eventSB
	}
	catch { Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered before ShowDialog." }

	#endregion Other Actions Before ShowDialog

	# Show the form
	try { [void]$Script:refs['MainForm'].ShowDialog() } catch { Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered unexpectedly at ShowDialog." }

	<#
	#region Actions After Form Closed

	try {

	} catch {Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered after Form close."}

	#endregion Actions After Form Closed
	#>
}

#region Start Point of Execution

# Initialize STA Runspace
$rsGUI = [Management.Automation.Runspaces.RunspaceFactory]::CreateRunspace()
$rsGUI.ApartmentState = 'STA'
$rsGUI.ThreadOptions = 'ReuseThread'
$rsGUI.Open()

# Create the PSCommand, Load into Runspace, and BeginInvoke
$cmdGUI = [Management.Automation.PowerShell]::Create().AddScript($sbGUI).AddParameter('BaseDir', $PSScriptRoot)

foreach ($param in $PSBoundParameters.Keys) {
	$cmdGUI=$cmdGUI.AddParameter($param, $PSBoundParameters[$param])
}

$cmdGUI.RunSpace = $rsGUI
$handleGUI = $cmdGUI.BeginInvoke()

# Hide Console Window
Add-Type -Name Window -Namespace Console -MemberDefinition '
[DllImport("Kernel32.dll")]
public static extern IntPtr GetConsoleWindow();

[DllImport("user32.dll")]
public static extern bool ShowWindow(IntPtr hWnd, Int32 nCmdShow);
'

[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 0) | Out-Null

#Loop Until GUI Closure
while ( $handleGUI.IsCompleted -eq $false ) { Start-Sleep -Seconds 2 }

# Dispose of GUI Runspace/Command
$cmdGUI.EndInvoke($handleGUI)
$cmdGUI.Dispose()
$rsGUI.Dispose()

[Console.Window]::ShowWindow([Console.Window]::GetConsoleWindow(), 1) | Out-Null # Show Console Window

Exit

#endregion Start Point of Execution
