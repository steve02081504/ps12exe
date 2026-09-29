# Lint：为 .ps1 追加 UTF-8 BOM。
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$repoRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($repoRoot)

$utf8Bom = New-Object System.Text.UTF8Encoding $true
$bomCount = 0
Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter '*.ps1' -File -Force | Where-Object {
	$_.FullName -notmatch '\.git[/\\]'
} | ForEach-Object {
	$path = $_.FullName
	$bytes = [System.IO.File]::ReadAllBytes($path)
	$hasBom = ($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)
	if ($hasBom) { return }
	$content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
	[System.IO.File]::WriteAllText($path, $content, $utf8Bom)
	$bomCount++
	Write-Output "BOM added: $path"
}
Write-Output "Add-BOM done. Files modified: $bomCount"
