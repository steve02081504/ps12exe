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
	$action = 'on'
) {
	if ('reset' -eq $action -or (IsDisable $action)) {
		Disable-ps12exeContextMenu
	}
	if ('reset' -eq $action -or (IsEnable $action)) {
		Enable-ps12exeContextMenu
	}
}

# Export functions
Export-ModuleMember -Function @('ps12exeGUI', 'Set-ps12exeContextMenu')
