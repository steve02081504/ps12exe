# load ps12exe.ps1 as a function
.([System.Management.Automation.Language.Parser]::ParseInput("
	function ps12exe {
		$(Get-Content -Path $PSScriptRoot\ps12exe.ps1 -Raw)
	}
", "$PSScriptRoot\ps12exe.ps1", [ref]$null, [ref]$null)).GetScriptBlock()

Import-Module "$PSScriptRoot/GUI" -Force -ErrorAction Stop

# Export functions
Export-ModuleMember -Function @('ps12exe','ps12exeGUI')
