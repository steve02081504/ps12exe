# load GUI.ps1 as a function
.([System.Management.Automation.Language.Parser]::ParseInput("
	function ps12exeGUI {
		$(Get-Content -Path $PSScriptRoot\GUI.ps1 -Raw)
	}
", "$PSScriptRoot\GUI.ps1", [ref]$null, [ref]$null)).GetScriptBlock()

. $PSScriptRoot\src\ContextMenuAdder.ps1
. $PSScriptRoot\src\predicate.ps1
function Set-ps12exeContextMenu(
	[ValidateScript({ IsEnable $_ -or IsDisable $_ -or $_ -eq 'reset' })]
	[ArgumentCompleter({
		param($Command, $Parameter, $WordToComplete, $CommandAst, $FakeBoundParams)
		. $PSScriptRoot\src\predicate.ps1 # 重新导入变量
		if (-not $WordToComplete) {
			@('enable', 'disable', 'reset')
		}
		else {
			@($DisablePredicates; $EnablePredicates; 'reset') | Where-Object { $_ -like "$WordToComplete*" }
		}
	})]
	$action = 'on',
	[string]$Localize
) {
	if ('reset' -eq $action -or (IsDisable $action)) {
		Disable-ps12exeContextMenu -Localize $Localize
	}
	if ('reset' -eq $action -or (IsEnable $action)) {
		Enable-ps12exeContextMenu -Localize $Localize
	}
}

# Export functions
Export-ModuleMember -Function @('ps12exeGUI', 'Set-ps12exeContextMenu')
