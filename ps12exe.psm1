function LoadFileAsFunction($File, $FunctionName) {
	$errors = $null
	$result = [System.Management.Automation.Language.Parser]::ParseInput("
		function $FunctionName {
			$(Get-Content -Path $File -Raw)
		}
	", $File, [ref]$null, [ref]$errors)
	$errors | ForEach-Object {
		Write-Warning $_
	}
	$result.GetScriptBlock()
}

. $(LoadFileAsFunction $PSScriptRoot/ps12exe.ps1 ps12exe)
. $(LoadFileAsFunction $PSScriptRoot/src/GUI/Main.ps1 ps12exeGUI)
. $(LoadFileAsFunction $PSScriptRoot/src/GUI/ContextMenuAdder.ps1 Set-ps12exeContextMenu)
. $(LoadFileAsFunction $PSScriptRoot/src/WebServer/main.ps1 Start-ps12exeWebServer)
. $(LoadFileAsFunction "$PSScriptRoot/src/Interact/main.ps1" Enter-ps12exeInteract)

# Export functions
Export-ModuleMember -Function @('ps12exe', 'ps12exeGUI', 'Set-ps12exeContextMenu', 'Start-ps12exeWebServer', 'Enter-ps12exeInteract')
