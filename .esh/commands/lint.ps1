# Lint：为 .ps1 追加 UTF-8 BOM + 规范化 .fbs（移除 Data 下非 Form/Dialog 节点、去掉 ImeMode、统一缩进）。
param(
	[switch]$BomOnly,   # 仅执行 BOM
	[switch]$FbsOnly    # 仅执行 .fbs 规范化
)
$ErrorActionPreference = 'Stop'
$repoRoot = (Resolve-Path (Join-Path $PSScriptRoot '../..')).Path
$repoRoot = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($repoRoot)

# ——— 1. 为无 BOM 的 .ps1 追加 UTF-8 BOM ———
if (-not $FbsOnly) {
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
}

# ——— 2. .fbs 规范化：仅保留 Form/Dialog、去掉 ImeMode、统一缩进 ———
if (-not $BomOnly) {
	$XmlWriterSettings = New-Object System.Xml.XmlWriterSettings
	$XmlWriterSettings.Indent = $true
	$XmlWriterSettings.IndentChars = "`t"
	$XmlWriterSettings.NewLineChars = "`n"
	$fbsCount = 0
	Get-ChildItem -LiteralPath $repoRoot -Recurse -Filter '*.fbs' -File | ForEach-Object {
		$XmlDoc = [xml](Get-Content -Path $_.FullName)
		$XmlWriter = [System.XML.XmlWriter]::Create($_.FullName, $XmlWriterSettings)
		do {
			$res = $XmlDoc.Data.ChildNodes | Where-Object { $_.Name -notmatch '(Form|Dialog)$' } | ForEach-Object { $_.ParentNode.RemoveChild($_) }
		} while ($res)
		$XmlDoc.SelectNodes('//*[@ImeMode]') | ForEach-Object {
			$_.RemoveAttribute('ImeMode')
		}
		$XmlDoc.Save($XmlWriter)
		$XmlWriter.WriteRaw("`n")
		$XmlWriter.Flush()
		$XmlWriter.Close()
		$fbsCount++
		Write-Output "FBS normalized: $($_.FullName)"
	}
	Write-Output "FBS done. Files modified: $fbsCount"
}
