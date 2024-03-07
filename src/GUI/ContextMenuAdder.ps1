<#
.SYNOPSIS
enable/disable/reset ps12exe's context menu
.DESCRIPTION
enable/disable/reset ps12exe's context menu
.PARAMETER action
enable or disable or reset
.PARAMETER Localize
The language code to be used for server-side logging
.EXAMPLE
Set-ps12exeContextMenu
.EXAMPLE
Set-ps12exeContextMenu -action 'enable' -Localize 'en-UK'
#>
[CmdletBinding()]
param (
	[ValidateScript({
		. $PSScriptRoot\..\predicate.ps1
		IsEnable $_ -or IsDisable $_ -or $_ -eq 'reset'
	})]
	[ArgumentCompleter({
		param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
		. $PSScriptRoot\..\predicate.ps1
		if (-not $WordToComplete) {
			@('enable', 'disable', 'reset')
		}
		else {
			@($DisablePredicates; $EnablePredicates; 'reset') | Where-Object { $_ -like "$WordToComplete*" }
		}
	})]
	$action = 'on',
	[ArgumentCompleter({
		Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
		. "$PSScriptRoot\..\LocaleArgCompleter.ps1" @PSBoundParameters
	})]
	[string]$Localize,
	[switch]$help
)

$LocalizeData = . $PSScriptRoot\..\LocaleLoader.ps1 -Localize $Localize

if ($help) {
	$MyHelp = $LocalizeData.SetContextMenuHelpData
	. $PSScriptRoot\..\HelpShower.ps1 -HelpData $MyHelp | Out-Host
	return
}

Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;

public class ExplorerRefresher {
	[DllImport("user32.dll", SetLastError = true)]
	private static extern IntPtr SendMessageTimeout(IntPtr hWnd, int Msg, IntPtr wParam, string lParam, uint fuFlags, uint uTimeout, IntPtr lpdwResult);

	private static readonly IntPtr HWND_BROADCAST = new IntPtr(0xffff);
	private const int WM_SETTINGCHANGE = 0x1a;
	private const int SMTO_ABORTIFHUNG = 0x0002;
	public static void RefreshSettings() {
		SendMessageTimeout(HWND_BROADCAST, WM_SETTINGCHANGE, IntPtr.Zero, null, SMTO_ABORTIFHUNG, 100, IntPtr.Zero);
	}
	[DllImport("shell32.dll")]
	private static extern int SHChangeNotify(int eventId, int flags, IntPtr item1, IntPtr item2);
	public static void RefreshDesktop() {
		SHChangeNotify(0x8000000, 0x1000, IntPtr.Zero, IntPtr.Zero);
	}
}
'@

function PwshCodeAsCommand($command) {
	"powershell.exe -Command `"if(-Not (Get-Module -ListAvailable -Name ps12exe)){ Install-Module ps12exe -Force -Scope CurrentUser -ErrorAction Ignore }; Import-Module ps12exe -ErrorAction Stop; $command`""
}

function AddCommandToContextMenu {
	param (
		$className,
		$fileType,
		$title,
		$command,
		$Icon = "$PSScriptRoot\..\..\img\icon.ico"
	)
	$key = "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\$className"

	if (-not (Test-Path -LiteralPath $key)) {
		New-Item -Path $key -Force | Out-Null
	}

	Set-ItemProperty -LiteralPath $key -Name "(Default)" -Value $title
	New-ItemProperty -LiteralPath $key -Name "AppliesTo" -Value "System.ItemName:$fileType" -PropertyType String -Force | Out-Null

	if ($Icon) {
		New-ItemProperty -LiteralPath $key -Name "Icon" -Value $Icon -PropertyType String -Force | Out-Null
	}

	New-Item -Path "$key\Command" -Force | Out-Null
	Set-ItemProperty -LiteralPath "$key\Command" -Name "(Default)" -Value $command
}

function RemoveCommandsFromContextMenu($className) {
	Remove-Item -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\$className" -Recurse
}

function AddFileType($fileType, $DefaultProgram) {
	$key = "Registry::HKEY_CURRENT_USER\Software\Classes\$fileType"
	New-Item -Path $key -Force | Out-Null
	if ($DefaultProgram) {
		New-Item -Path "$key\OpenWithProgids" -Force | Out-Null
		New-ItemProperty -LiteralPath "$key\OpenWithProgids" -Name $DefaultProgram -Value "" -PropertyType String -Force | Out-Null
	}
}

function RemoveFileType($fileType) {
	Remove-Item -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Classes\$fileType" -Recurse
}

function AddFileHandlerProgram {
	param (
		$className,
		$command,
		$FileDescription,
		$Icon = "$PSScriptRoot\..\..\img\icon.ico"
	)
	$key = "Registry::HKEY_CURRENT_USER\Software\Classes\$className"

	if (-not (Test-Path -LiteralPath $key)) {
		New-Item -Path $key -Force | Out-Null
	}

	if ($Icon) {
		New-Item -Path $key -Name "DefaultIcon" -Force | Out-Null
		New-ItemProperty -LiteralPath "$key\DefaultIcon" -Name "(Default)" -Value $Icon -PropertyType String -Force | Out-Null
	}
	New-ItemProperty -LiteralPath $key -Name "FriendlyTypeName" -Value $FileDescription -PropertyType String -Force | Out-Null

	New-Item -Path "$key\shell\open\command" -Force | Out-Null
	Set-ItemProperty -LiteralPath "$key\shell\open\command" -Name "(Default)" -Value $command
}

function RemoveFileHandlerProgram($className) {
	Remove-Item -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Classes\$className" -Recurse
}

if ('reset' -eq $action -or (IsDisable $action)) {
	AddCommandToContextMenu "ps12exeCompile" "ps1" $LocalizeData.CompileTitle (PwshCodeAsCommand "ps12exe '%1';pause")
	AddCommandToContextMenu "ps12exeGUIOpen" "ps1" $LocalizeData.OpenInGUI (PwshCodeAsCommand "ps12exeGUI -PS1File '%1'")
	AddFileHandlerProgram "ps12exeGUI.psccfg" (PwshCodeAsCommand "ps12exeGUI '%1'") $LocalizeData.GUICfgFileDesc 
	AddFileType ".psccfg" "ps12exeGUI.psccfg"
}
if ('reset' -eq $action -or (IsEnable $action)) {
	RemoveCommandsFromContextMenu "ps12exeCompile"
	RemoveCommandsFromContextMenu "ps12exeGUIOpen"
	RemoveFileHandlerProgram "ps12exeGUI.psccfg"
	RemoveFileType ".psccfg"
}
[ExplorerRefresher]::RefreshSettings()
[ExplorerRefresher]::RefreshDesktop()
