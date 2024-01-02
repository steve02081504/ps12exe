# load GUI.ps1 as a function
.([System.Management.Automation.Language.Parser]::ParseInput("
	function ps12exeGUI {
		$(Get-Content -Path $PSScriptRoot\GUI.ps1 -Raw)
	}
", "$PSScriptRoot\GUI.ps1", [ref]$null, [ref]$null)).GetScriptBlock()

# Export functions
Export-ModuleMember -Function @('ps12exeGUI')
