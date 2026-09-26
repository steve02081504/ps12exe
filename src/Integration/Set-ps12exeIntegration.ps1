<#
.SYNOPSIS
一次性设置/撤销 ps12exe 的全部集成
.DESCRIPTION
依次调用 Set-ps12exeContextMenu、Set-ps12exeAgentSkill 与 Set-ps12exeVSCodeExtension，
启用/禁用/重置 ps12exe 的右键菜单、Agent Skill 与 VS Code 扩展。
.PARAMETER action
enable、disable 或 reset
.PARAMETER Locale
要使用的语言代码
.PARAMETER Skip
要跳过的集成项，可包含 ContextMenu、AgentSkill、VSCodeExtension 中的任意个。
.EXAMPLE
Set-ps12exeIntegration
.EXAMPLE
Set-ps12exeIntegration -action 'disable'
.EXAMPLE
Set-ps12exeIntegration -Skip ContextMenu,VSCodeExtension
#>
[CmdletBinding()]
param (
	[ValidateScript({ . "$PSScriptRoot\ActionValidator.ps1" $_ })]
	[ArgumentCompleter({
		Param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
		. "$PSScriptRoot\ActionArgCompleter.ps1" @PSBoundParameters
	})]
	$action = 'on',
	[ArgumentCompleter({
		Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
		. "$PSScriptRoot\..\LocaleArgCompleter.ps1" @PSBoundParameters
	})]
	[string]$Locale,
	[ValidateSet('ContextMenu', 'AgentSkill', 'VSCodeExtension')]
	[ArgumentCompleter({
		Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
		@('ContextMenu', 'AgentSkill', 'VSCodeExtension') | Where-Object { $_ -like "$wordToComplete*" }
	})]
	[string[]]$Skip = @(),
	[switch]$help
)

$LocalizeData = . $PSScriptRoot\..\LocaleLoader.ps1 -Locale $Locale

if ($help) {
	. $PSScriptRoot\..\HelpShower.ps1 -HelpData $LocalizeData.IntegrationHelpData | Write-Host
	return
}

$LocaleCode = $LocalizeData.LangID
if ('ContextMenu' -notin $Skip) {
	& "$PSScriptRoot/Set-ps12exeContextMenu.ps1" -action $action -Locale $LocaleCode
}
if ('AgentSkill' -notin $Skip) {
	& "$PSScriptRoot/Set-ps12exeAgentSkill.ps1" -action $action -Locale $LocaleCode
}
if ('VSCodeExtension' -notin $Skip) {
	& "$PSScriptRoot/Set-ps12exeVSCodeExtension.ps1" -action $action -Locale $LocaleCode
}
