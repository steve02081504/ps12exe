Get-ChildItem $PSScriptRoot -Directory | ForEach-Object {
	Update-MarkdownHelp "$PSScriptRoot/$($_.Name)" -Force
}
