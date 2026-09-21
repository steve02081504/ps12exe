# 启用/禁用/重置 ps12exe 的右键菜单与 .psccfg 文件关联。
# 独立脚本，不导出为命令：由 Set-ps12exeIntegration 直接调用。
[CmdletBinding()]
param (
	[ValidateScript({
		. $PSScriptRoot\..\predicate.ps1
		(IsEnable $_) -or (IsDisable $_) -or ($_ -eq 'reset')
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
	[string]$Locale
)

$LocalizeData = . $PSScriptRoot\..\LocaleLoader.ps1 -Locale $Locale

# Windows 外壳集成：通知资源管理器刷新设置与桌面。
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

# 右键菜单命令通过 powershell.exe 调用：缺模块时先安装再导入。
function PwshCodeAsCommand($command) {
	"powershell.exe -NoProfile -Command `"if(-Not (Get-Module -ListAvailable -Name ps12exe)){ Install-Module ps12exe -Force -Scope CurrentUser -ErrorAction Ignore }; Import-Module ps12exe -ErrorAction Stop; $command`""
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
	$key = "Registry::HKEY_CURRENT_USER\Software\Classes\*\shell\$className"
	if (Test-Path -LiteralPath $key) {
		Remove-Item -LiteralPath $key -Recurse
	}
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
	$key = "Registry::HKEY_CURRENT_USER\Software\Classes\$fileType"
	if (Test-Path -LiteralPath $key) {
		Remove-Item -LiteralPath $key -Recurse
	}
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
	$key = "Registry::HKEY_CURRENT_USER\Software\Classes\$className"
	if (Test-Path -LiteralPath $key) {
		Remove-Item -LiteralPath $key -Recurse
	}
}

. $PSScriptRoot\..\predicate.ps1
if ('reset' -eq $action -or (IsDisable $action)) {
	RemoveCommandsFromContextMenu "ps12exeCompile"
	RemoveCommandsFromContextMenu "ps12exeGUIOpen"
	RemoveFileHandlerProgram "ps12exeGUI.psccfg"
	RemoveFileType ".psccfg"
}
if ('reset' -eq $action -or (IsEnable $action)) {
	AddCommandToContextMenu "ps12exeCompile" "ps1" $LocalizeData.CompileTitle (PwshCodeAsCommand "ps12exe '%1';pause")
	AddCommandToContextMenu "ps12exeGUIOpen" "ps1" $LocalizeData.OpenInGUI (PwshCodeAsCommand "ps12exeGUI -PS1File '%1'")
	AddFileHandlerProgram "ps12exeGUI.psccfg" (PwshCodeAsCommand "ps12exeGUI '%1'") $LocalizeData.GUICfgFileDesc
	AddFileType ".psccfg" "ps12exeGUI.psccfg"
}
[ExplorerRefresher]::RefreshSettings()
[ExplorerRefresher]::RefreshDesktop()
