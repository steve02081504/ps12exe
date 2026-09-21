# 向检测到的 VS Code 系编辑器安装或卸载 ps12exe 扩展。
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
function Install-VSCodeExtension {
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
function Uninstall-VSCodeExtension {
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
	Uninstall-VSCodeExtension
}
if ('reset' -eq $action -or (IsEnable $action)) {
	Install-VSCodeExtension
}
