function LoadFileAsFunction($File, $FunctionName) {
	([System.Management.Automation.Language.Parser]::ParseInput("
		function $FunctionName {
			$(Get-Content -Path $File -Raw)
		}
	", $File, [ref]$null, [ref]$null)).GetScriptBlock()
}

. $(LoadFileAsFunction $PSScriptRoot/ps12exe.ps1 ps12exe)
. $(LoadFileAsFunction $PSScriptRoot/src/GUI/Main.ps1 ps12exeGUI)
. $(LoadFileAsFunction $PSScriptRoot/src/GUI/ContextMenuAdder.ps1 Set-ps12exeContextMenu)
. $(LoadFileAsFunction $PSScriptRoot/src/WebServer/main.ps1 Start-ps12exeWebServer)

# Export functions
Export-ModuleMember -Function @('ps12exe', 'ps12exeGUI', 'Set-ps12exeContextMenu', 'Start-ps12exeWebServer')
