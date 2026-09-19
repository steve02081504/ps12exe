param ($SyntaxErrors, $CodeContent)
$CodeLines = if ($CodeContent) { $CodeContent -split "\r?\n" }
$SyntaxErrors | ForEach-Object {
	$Extent = $_.Extent
	if ($Extent.StartLineNumber) {
		$LineStr = $Extent.StartLineNumber.ToString()
	}
	if ($Extent.StartLineNumber -ne $Extent.EndLineNumber) {
		$LineStr += "-$($Extent.EndLineNumber)"
	}
	if ($Extent.StartColumnNumber) {
		$ColumnStr = $Extent.StartColumnNumber.ToString()
	}
	if ($Extent.StartColumnNumber -ne $Extent.EndColumnNumber) {
		$ColumnStr += "-$($Extent.EndColumnNumber)"
	}
	$SpoceText = $Extent.StartLineNumber, $Extent.StartColumnNumber
	# 只显示出错的那一行；没有代码内容或行号越界时退回完整脚本
	$ScriptLine = if ($CodeLines -and $Extent.StartLineNumber -ge 1 -and $Extent.StartLineNumber -le $CodeLines.Count) {
		$CodeLines[$Extent.StartLineNumber - 1]
	}
	elseif ($Extent.StartScriptPosition) {
		$Extent.StartScriptPosition.GetFullScript()
	}
	@{
		Text      = $ScriptLine
		Message   = $_.Message
		Spoce     = @{
			Line      = $Extent.StartLineNumber
			Column    = $Extent.StartColumnNumber
			LineEnd   = $Extent.EndLineNumber
			ColumnEnd = $Extent.EndColumnNumber
		}
		SpoceText = $SpoceText
		ErrorId   = $_.ErrorId
	}
}
