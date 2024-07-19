param ($SyntaxErrors,$CodeContent,$Localize)
$result = & $PSScriptRoot/SyntaxErrorDataBuilder.ps1 $SyntaxErrors

if (
#_if PSScript
	$PSEdition -eq 'Core' -or
#_endif
[cultureinfo]::CurrentUICulture -ne [cultureinfo]$Localize) {
	$I18NResult = powershell -OutputFormat xml -File $PSScriptRoot/SyntaxErrorI18nDataGetter.ps1 -Content $CodeContent -Localize $Localize
	foreach ($errinfo in $result) {
		$Cross = $I18NResult | Where-Object { $_.ErrorId -eq $errinfo.ErrorId -and ($_.SpoceText -join ';') -eq ($errinfo.SpoceText -join ';') }
		if ($Cross) {
			$errinfo.Message = $Cross.Message
		}
	}
}
$result
