# 为仓库内所有无 UTF-8 BOM 的 .ps1 文件追加 BOM（不修改已有 BOM 的文件）。
# 可本地运行后提交，或在 CI 中与「先追加 BOM 再全量测试」联用。
$ErrorActionPreference = 'Stop'
$root = $env:REPO_ROOT
if (-not $root) { $root = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path }
$root = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($root)
$utf8Bom = New-Object System.Text.UTF8Encoding $true
$bomBytes = [byte[]]@(0xEF, 0xBB, 0xBF)
$count = 0
Get-ChildItem -LiteralPath $root -Recurse -Filter '*.ps1' -File | Where-Object {
	$_.FullName -notmatch '\.git[/\\]'
} | ForEach-Object {
	$path = $_.FullName
	$bytes = [System.IO.File]::ReadAllBytes($path)
	$hasBom = ($bytes.Length -ge 3) -and ($bytes[0] -eq 0xEF) -and ($bytes[1] -eq 0xBB) -and ($bytes[2] -eq 0xBF)
	if ($hasBom) { return }
	$content = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
	[System.IO.File]::WriteAllText($path, $content, $utf8Bom)
	$count++
	Write-Output "BOM added: $path"
}
Write-Output "Add-BOM done. Files modified: $count"
