Get-ChildItem $PSScriptRoot -Directory | ForEach-Object {
	New-ExternalHelp "$PSScriptRoot/$($_.Name)" -OutputPath "$PSScriptRoot/$($_.Name)" -Force
}
