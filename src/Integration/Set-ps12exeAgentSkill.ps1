# 把 ps12exe 的 Agent Skill 写入或移出用户级通用技能目录（~/.agents/skills），
# 供 opencode、Codex、Cursor、Copilot 等支持 Agent Skills 的 agent 读取。
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

$AgentSkillName = 'ps12exe'
$AgentSkillSource = "$PSScriptRoot\..\AgentSkill\SKILL.md"

function Get-AgentSkillDir {
	Join-Path $HOME ".agents\skills\$AgentSkillName"
}

# 将 ps12exe 的 Agent Skill 复制到用户级通用技能目录。
function Install-AgentSkill {
	$InstallingMessage = if ($LocalizeData.AgentSkillInstalling) { $LocalizeData.AgentSkillInstalling }
	else { 'Installing the ps12exe agent skill to {0} ...' }
	$FailedMessage = if ($LocalizeData.AgentSkillInstallFailed) { $LocalizeData.AgentSkillInstallFailed }
	else { 'Failed to install the ps12exe agent skill to {0}: {1}' }

	$skillDir = Get-AgentSkillDir
	$skillFile = Join-Path $skillDir 'SKILL.md'
	try {
		$content = [System.IO.File]::ReadAllText($AgentSkillSource, [System.Text.Encoding]::UTF8)
		New-Item -Path $skillDir -ItemType Directory -Force | Out-Null
		Write-Host ($InstallingMessage -f $skillFile) -ForegroundColor Gray
		[System.IO.File]::WriteAllText($skillFile, $content, [System.Text.UTF8Encoding]::new($false))
	}
	catch {
		Write-Warning ($FailedMessage -f @($skillFile, $_.Exception.Message))
	}
}

# 从用户级通用技能目录移除 ps12exe 的 Agent Skill。
function Uninstall-AgentSkill {
	$UninstallingMessage = if ($LocalizeData.AgentSkillUninstalling) { $LocalizeData.AgentSkillUninstalling }
	else { 'Removing the ps12exe agent skill from {0} ...' }
	$FailedMessage = if ($LocalizeData.AgentSkillUninstallFailed) { $LocalizeData.AgentSkillUninstallFailed }
	else { 'Failed to remove the ps12exe agent skill from {0}: {1}' }

	$skillDir = Get-AgentSkillDir
	try {
		if (Test-Path -LiteralPath $skillDir) {
			Write-Host ($UninstallingMessage -f $skillDir) -ForegroundColor Gray
			Remove-Item -LiteralPath $skillDir -Recurse -Force
		}
	}
	catch {
		Write-Warning ($FailedMessage -f @($skillDir, $_.Exception.Message))
	}
}

. $PSScriptRoot\..\predicate.ps1
if ('reset' -eq $action -or (IsDisable $action)) {
	Uninstall-AgentSkill
}
if ('reset' -eq $action -or (IsEnable $action)) {
	Install-AgentSkill
}
