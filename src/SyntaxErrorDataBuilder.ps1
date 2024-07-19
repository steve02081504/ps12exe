param ($SyntaxErrors)
foreach ($_ in $SyntaxErrors) {
	$Extent = $_.Extent
	$LineStr = $Extent.StartLineNumber.ToString()
	if ($Extent.StartLineNumber -ne $Extent.EndLineNumber) {
		$LineStr += "-$($Extent.EndLineNumber)"
	}
	$ColumnStr = $Extent.StartColumnNumber.ToString()
	if ($Extent.StartColumnNumber -ne $Extent.EndColumnNumber) {
		$ColumnStr += "-$($Extent.EndColumnNumber)"
	}
	$SpoceText = $Extent.StartLineNumber, $Extent.StartColumnNumber
	@{
		Text = $Extent.StartScriptPosition.GetFullScript()
		Message = $_.Message
		Spoce = @{
			Line = $Extent.StartLineNumber
			Column = $Extent.StartColumnNumber
			LineEnd = $Extent.EndLineNumber
			ColumnEnd = $Extent.EndColumnNumber
		}
		SpoceText = $SpoceText
		ErrorId = $_.ErrorId
	}
}
