Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
Get-ChildItem $PSScriptRoot\Locale -Filter *.ps1 | Where-Object { $_.BaseName -match '^[A-Za-z]{2,3}(-[A-Za-z0-9]+)*$' } | ForEach-Object { $_.BaseName } | Where-Object {
	$_ -like "$($wordToComplete.Trim('"', "'"))*"
} | ForEach-Object {
	if ($wordToComplete.StartsWith('"')) { "`"$_`"" }
	elseif ($wordToComplete.StartsWith("'")) { "'$_'" }
	else { $_ }
}
