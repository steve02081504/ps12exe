$Content | Set-Content $TempDir\main.ps1 -Encoding UTF8 -NoNewline
if ($iconFile -match "^(https?|ftp)://") {
	Invoke-WebRequest -Uri $iconFile -OutFile $TempDir\icon.ico
	if (!(Test-Path $TempDir\icon.ico -PathType Leaf)) {
		Write-Error "Icon file $iconFile failed to download!"
		return
	}
	$iconFile = "$TempDir\icon.ico"
}
elseif ($iconFile) {
	# retrieve absolute path independent if path is given relative oder absolute
	$iconFile = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($iconFile)

	if (!(Test-Path $iconFile -PathType Leaf)) {
		Write-Error "Icon file $iconFile not found!"
		return
	}
}
