param (
	[hashtable]$HelpData
)
function ShowParamsHelp($ParamsHelpData) {
	# 对于所有的键
	$MaxKeyLength = $ParamsHelpData.Keys.Length | Measure-Object -Maximum | Select-Object -ExpandProperty Maximum

	$ParamsHelpData.Keys | ForEach-Object {
		$Key = $_
		$Value = $ParamsHelpData[$Key]

		$Spaces = ' ' * ($MaxKeyLength - $Key.Length)
		"$Key$Spaces : $Value"
	}
}
$HelpData.title
ShowParamsHelp $HelpData.PrarmsData
