param(
	[scriptblock]$CheckLocaleData= {
		$null -ne $Script:LocalizeData
	},
	[scriptblock]$FaildLoadLocaleData= {
		Write-Warning "Failed to load locale data locale/$Localize`nSee $LocalizeDir/README.md for how to add custom locale."
	},
	[scriptblock]$LoadLocaleData= {
		param (
			[string]$Localize
		)
		$Script:LocalizeData = &"$LocalizeDir\$Localize.ps1"
	},
	[string]$Localize
)

if (!$Localize) {
	# 本机语言
	$Localize = (Get-Culture).Name
}

$LocalizeDir = "$PSScriptRoot/locale"

&$LoadLocaleData $Localize
if(!($CheckLocaleData)) {
	&$FaildLoadLocaleData $Localize
	&$LoadLocaleData 'en-UK'
	if(!(&$CheckLocaleData)) { &$LoadLocaleData 'en-US' }
}
if(!(&$CheckLocaleData)) {
	$LocalizeList = Get-ChildItem $LocalizeDir | Where-Object { $_.Name -like '*.fbs' } | ForEach-Object { $_.BaseName }
	foreach ($Localize in $LocalizeList) {
		&$LoadLocaleData $Localize
		if(&$CheckLocaleData) {
			break
		}
	}
}
$Script:LocalizeData
