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

function AddCommandsToContextMenu {
	param (
		$className,
		$fileType,
		$title,
		$command,
		$Icon = "$PSScriptRoot\..\img\icon.ico"
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
	Set-ItemProperty -LiteralPath "$key\Command" -Name "(Default)" -Value "powershell.exe -Command `"if(-Not (Get-Module -ListAvailable -Name ps12exe)){ Install-Module ps12exe -Force -Scope CurrentUser -ErrorAction Ignore }; Import-Module ps12exe -ErrorAction Stop; $command`""
}

function RemoveCommandsFromContextMenu {
	param (
		$className
	)
	Remove-Item -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\$className" -Recurse
}

function AddFileType {
	param (
		$fileType,
		$DefaultProgram
	)
	$key = "Registry::HKEY_CURRENT_USER\Software\Classes\$fileType"
	New-Item -Path $key -Force | Out-Null
	if ($DefaultProgram){
		New-Item -Path "$key\OpenWithProgids" -Force | Out-Null
		New-ItemProperty -LiteralPath "$key\OpenWithProgids" -Name $DefaultProgram -Value "" -PropertyType String -Force | Out-Null
	}
}

function RemoveFileType {
	param (
		$fileType
	)
	Remove-Item -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Classes\$fileType" -Recurse
}

function AddFileHandlerProgram {
	param (
		$className,
		$command,
		$FileDescription,
		$Icon = "$PSScriptRoot\..\img\icon.ico"
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
	Set-ItemProperty -LiteralPath "$key\shell\open\command" -Name "(Default)" -Value "powershell.exe -Command `"if(-Not (Get-Module -ListAvailable -Name ps12exe)){ Install-Module ps12exe -Force -Scope CurrentUser -ErrorAction Ignore }; Import-Module ps12exe -ErrorAction Stop; $command`""
}

function RemoveFileHandlerProgram {
	param (
		$className
	)
	Remove-Item -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Classes\$className" -Recurse
}

$LocalizeData = . $PSScriptRoot\LocaleLoader.ps1
function Enable-ps12exeContextMenu {
	AddCommandsToContextMenu "ps12exeCompile" "ps1" $LocalizeData.CompileTitle "ps12exe '%1'"
	AddCommandsToContextMenu "ps12exeGUIOpen" "ps1" $LocalizeData.OpenInGUI "ps12exeGUI -PS1File '%1'"
	AddFileHandlerProgram "ps12exeGUI.psccfg" "ps12exeGUI '%1'" $LocalizeData.GUICfgFileDesc 
	AddFileType ".psccfg" "ps12exeGUI.psccfg"
	# restart explorer to apply the changes
	[ExplorerRefresher]::RefreshSettings()
	[ExplorerRefresher]::RefreshDesktop()
}
function Disable-ps12exeContextMenu {
	RemoveCommandsFromContextMenu "ps12exeCompile"
	RemoveCommandsFromContextMenu "ps12exeGUIOpen"
	RemoveFileHandlerProgram "ps12exeGUI.psccfg"
	RemoveFileType ".psccfg"
	# restart explorer to apply the changes
	[ExplorerRefresher]::RefreshSettings()
	[ExplorerRefresher]::RefreshDesktop()
}
