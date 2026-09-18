<#
.SYNOPSIS
启用/禁用/重置 ps12exe 的右键菜单
.DESCRIPTION
启用/禁用/重置 ps12exe 的右键菜单
.PARAMETER action
enable、disable 或 reset
.PARAMETER Locale
用于服务器端日志记录的语言代码
.EXAMPLE
Set-ps12exeContextMenu
.EXAMPLE
Set-ps12exeContextMenu -action 'enable' -Locale 'en-UK'
#>
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
	[string]$Locale,
	[switch]$SkipEditorExtension,
	[switch]$help
)

$LocalizeData = . $PSScriptRoot\..\LocaleLoader.ps1 -Locale $Locale

if ($help) {
	$MyHelp = $LocalizeData.SetContextMenuHelpData
	. $PSScriptRoot\..\HelpShower.ps1 -HelpData $MyHelp | Write-Host
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

# 用 Get-Command 探测的基于 VS Code 的编辑器，以及要安装到其中的扩展。
$VSCodeBasedEditorNames = @(
	'code',				# Visual Studio Code
	'code-insiders',	# Visual Studio Code Insiders
	'codium',			# VSCodium
	'vscodium',			# VSCodium
	'cursor',			# Cursor
	'windsurf',			# Windsurf
	'trae',				# Trae
	'positron',			# Positron
	'void'				# Void
)
$VSCodeExtensionId = 'steve02081504.ps12exe'

# 用 Get-Command 探测上述编辑器，并对指向同一 CLI 的名称去重。
function Get-VSCodeBasedEditors {
	$seen = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
	foreach ($name in $VSCodeBasedEditorNames) {
		$command = Get-Command -Name $name -CommandType Application -ErrorAction Ignore | Select-Object -First 1
		if (-not $command) { continue }
		if (-not $seen.Add($command.Source)) { continue }
		[PSCustomObject]@{
			Name = $name
			Path = $command.Source
		}
	}
}

# 通过 CLI 将 ps12exe VS Code 扩展安装到每个检测到的编辑器中。该扩展尚未发布到应用市场，因此失败会被报告并忽略。
function Install-ps12exeVSCodeExtension {
	$InstallingMessage = if ($LocalizeData.VSCodeExtensionInstalling) { $LocalizeData.VSCodeExtensionInstalling }
	else { 'Installing the ps12exe extension for {0} ...' }
	$FailedMessage = if ($LocalizeData.VSCodeExtensionInstallFailed) { $LocalizeData.VSCodeExtensionInstallFailed }
	else { 'Failed to install the ps12exe extension for {0} (it may not be published yet): {1}' }

	$editors = try { @(Get-VSCodeBasedEditors) } catch { @() }
	foreach ($editor in $editors) {
		try {
			$installed = & $editor.Path --list-extensions 2>$null
			if ($installed | Where-Object { $_ -and ($_.Trim() -ieq $VSCodeExtensionId) }) {
				continue
			}
			Write-Host ($InstallingMessage -f $editor.Name) -ForegroundColor Gray
			$output = & $editor.Path --install-extension $VSCodeExtensionId --force 2>&1
			if ($LASTEXITCODE) {
				Write-Warning ($FailedMessage -f @($editor.Name, (($output | Out-String).Trim())))
			}
		}
		catch {
			Write-Warning ($FailedMessage -f @($editor.Name, $_.Exception.Message))
		}
	}
}

# 从每个检测到的编辑器中卸载 ps12exe VS Code 扩展（仅卸载确实已安装的）。
function Uninstall-ps12exeVSCodeExtension {
	$UninstallingMessage = if ($LocalizeData.VSCodeExtensionUninstalling) { $LocalizeData.VSCodeExtensionUninstalling }
	else { 'Uninstalling the ps12exe extension for {0} ...' }
	$FailedMessage = if ($LocalizeData.VSCodeExtensionUninstallFailed) { $LocalizeData.VSCodeExtensionUninstallFailed }
	else { 'Failed to uninstall the ps12exe extension for {0}: {1}' }

	$editors = try { @(Get-VSCodeBasedEditors) } catch { @() }
	foreach ($editor in $editors) {
		try {
			$installed = & $editor.Path --list-extensions 2>$null
			if (-not ($installed | Where-Object { $_ -and ($_.Trim() -ieq $VSCodeExtensionId) })) {
				continue
			}
			Write-Host ($UninstallingMessage -f $editor.Name) -ForegroundColor Gray
			$output = & $editor.Path --uninstall-extension $VSCodeExtensionId 2>&1
			if ($LASTEXITCODE) {
				Write-Warning ($FailedMessage -f @($editor.Name, (($output | Out-String).Trim())))
			}
		}
		catch {
			Write-Warning ($FailedMessage -f @($editor.Name, $_.Exception.Message))
		}
	}
}

. $PSScriptRoot\..\predicate.ps1
if ('reset' -eq $action -or (IsDisable $action)) {
	RemoveCommandsFromContextMenu "ps12exeCompile"
	RemoveCommandsFromContextMenu "ps12exeGUIOpen"
	RemoveFileHandlerProgram "ps12exeGUI.psccfg"
	RemoveFileType ".psccfg"
	if ((IsDisable $action) -and -not $SkipEditorExtension) {
		Uninstall-ps12exeVSCodeExtension
	}
}
if ('reset' -eq $action -or (IsEnable $action)) {
	AddCommandToContextMenu "ps12exeCompile" "ps1" $LocalizeData.CompileTitle (PwshCodeAsCommand "ps12exe '%1';pause")
	AddCommandToContextMenu "ps12exeGUIOpen" "ps1" $LocalizeData.OpenInGUI (PwshCodeAsCommand "ps12exeGUI -PS1File '%1'")
	AddFileHandlerProgram "ps12exeGUI.psccfg" (PwshCodeAsCommand "ps12exeGUI '%1'") $LocalizeData.GUICfgFileDesc
	AddFileType ".psccfg" "ps12exeGUI.psccfg"
	if (-not $SkipEditorExtension) {
		Install-ps12exeVSCodeExtension
	}
}
[ExplorerRefresher]::RefreshSettings()
[ExplorerRefresher]::RefreshDesktop()
