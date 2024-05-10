$XmlWriterSettings = New-Object System.Xml.XmlWriterSettings
$XmlWriterSettings.Indent = $true
$XmlWriterSettings.IndentChars = "`t"
$XmlWriterSettings.NewLineChars = "`n"
Get-ChildItem -Path $repoPath -Recurse -Filter '*.fbs' | ForEach-Object {
	$XmlDoc = [xml](Get-Content -Path $_.FullName)
	$XmlWriter = [System.XML.XmlWriter]::Create($_.FullName, $XmlWriterSettings)
	do {
		$res = $XmlDoc.Data.ChildNodes | Where-Object { $_.Name -notmatch '(Form|Dialog)$' } | ForEach-Object { $_.ParentNode.RemoveChild($_) }
	}while ($res)
	$XmlDoc.Save($XmlWriter)
	$XmlWriter.WriteRaw("`n")
	$XmlWriter.Flush()
	$XmlWriter.Close()
}
