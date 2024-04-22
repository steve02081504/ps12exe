$XmlWriterSettings = New-Object System.Xml.XmlWriterSettings
$XmlWriterSettings.Indent = $true
$XmlWriterSettings.IndentChars = "`t"
$XmlWriterSettings.NewLineChars = "`n"
Get-ChildItem -Path $repoPath -Recurse -Filter '*.fbs' | ForEach-Object {
	$XmlDoc = [xml](Get-Content -Path $_.FullName)
	$XmlWriter = [System.XML.XmlWriter]::Create($_.FullName, $XmlWriterSettings)
	$XmlDoc.Save($XmlWriter)
	$XmlWriter.WriteRaw("`n")
	$XmlWriter.Flush()
	$XmlWriter.Close()
}
