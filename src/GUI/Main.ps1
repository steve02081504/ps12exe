#Requires -Version 5.0

<#
.SYNOPSIS
ps12exeGUI 是 ps12exe 的 GUI 工具。
.DESCRIPTION
ps12exeGUI 是 ps12exe 的 GUI 工具。
.PARAMETER ConfigFile
配置文件的路径。
.PARAMETER PS1File
脚本文件的路径。
.PARAMETER Locale
要使用的语言代码。
.PARAMETER UIMode
要使用的 UI 模式。
.PARAMETER help
显示此帮助信息。
.EXAMPLE
ps12exeGUI -Locale 'en-UK' -UIMode 'Light'
.EXAMPLE
ps12exeGUI -ConfigFile 'proj.psccfg' -Locale 'en-UK' -UIMode 'Dark'
.EXAMPLE
ps12exeGUI -help
#>
[CmdletBinding(DefaultParameterSetName = 'ConfigOrPS1File')]
param(
	[Parameter(DontShow, ParameterSetName = 'ConfigOrPS1File', Position = 0)]
	[ValidatePattern('^.*\.(psccfg|xml|ps1)$')]
	[string]$ConfigOrPS1File,
	[Parameter(Mandatory, ParameterSetName = 'ConfigFile', Position = 0)]
	[ValidatePattern('^.*\.(psccfg|xml)$')]
	[string]$ConfigFile,
	[Parameter(ParameterSetName = 'ConfigFile')]
	[Parameter(Mandatory, ParameterSetName = 'Ps1File', Position = 0)]
	[ValidatePattern('^.*\.ps1$')]
	[string]$PS1File,
	#_if PSScript
		[ArgumentCompleter({
			Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
			. "$PSScriptRoot\..\LocaleArgCompleter.ps1" @PSBoundParameters
		})]
	#_endif
	[string]$Locale,
	[ValidateSet('Light', 'Dark', 'Auto')]
	[string]$UIMode = 'Auto',
	[switch]$help
)

#_if PSScript
	if ($help) {
		$LocalizeData = . $PSScriptRoot\..\LocaleLoader.ps1 -Locale $Locale
		$MyHelp = $LocalizeData.GUIHelpData
		. $PSScriptRoot\..\HelpShower.ps1 -HelpData $MyHelp | Write-Host
		return
	}

	if ($ConfigOrPS1File) {
		if ($ConfigOrPS1File -match '\.ps1$') {
			$PSBoundParameters.PS1File = $ConfigOrPS1File
		}
		else {
			$PSBoundParameters.ConfigFile = $ConfigOrPS1File
		}
		$PSBoundParameters.Remove('ConfigOrPS1File') | Out-Null
	}

	try {
		# 设置控制台窗口标题
		$BackUpTitle = $Host.UI.RawUI.WindowTitle
		$Host.UI.RawUI.WindowTitle = "ps12exe GUI Console Host"

		# 初始化 STA Runspace
		$Runspace = [RunspaceFactory]::CreateRunspace()
		$Runspace.ApartmentState = 'STA'
		$Runspace.ThreadOptions = 'ReuseThread'
		$Runspace.Open()

		# 执行
		$pwsh = [PowerShell]::Create().AddScript({
			param ($ScriptRoot, $ConfigFile, $Locale, $UIMode, $PS1File, $help)
			. "$ScriptRoot\GUIMainScript.ps1"
		}).AddParameter('ScriptRoot', $PSScriptRoot)

		foreach ($param in $PSBoundParameters.Keys) {
			$pwsh = $pwsh.AddParameter($param, $PSBoundParameters[$param])
		}

		$pwsh.RunSpace = $Runspace
		$pwsh.Invoke()
	}
	finally {
		# 释放
		$Runspace.Close()
		$Runspace.Dispose()
		$pwsh.Dispose()

		# 恢复控制台窗口标题
		$Host.UI.RawUI.WindowTitle = $BackUpTitle
	}
#_else
	#_require ps12exe
	#_pragma App.Windowed
	#_pragma Resources.iconFile $PSScriptRoot/../../img/icon.ico
	#_pragma Resources.title ps12exeGUI
	#_pragma Resources.description 'A super cool GUI for compile powershell scripts'
	#_!!if (!(Test-Path -LiteralPath "Registry::HKEY_CURRENT_USER\Software\Classes\ps12exeGUI.psccfg")){
	#_!!	Set-ps12exeContextMenu 1
	#_!!}
	#_!!ps12exeGUI @PSBoundParameters
#_endif
