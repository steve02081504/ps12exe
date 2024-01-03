$Script:dialogInfo = @{}

."$BaseDir/../LocaleLoader.ps1" -Localize $Localize -LoadLocaleData {
	param (
		[string]$Localize
	)
	$Xml = [xml](Get-Content "$LocalizeDir\$Localize.fbs")
	$Script:MainForm = $Xml.Data.Form.OuterXml
	$Xml.Data.ChildNodes | Select-Object -Skip 2 | ForEach-Object {
		$Script:dialogInfo.Add($_.Name, $_.OuterXml)
	}
	$Script:LocalizeData = &"$LocalizeDir\$Localize.ps1"
} -CheckLocaleData {
	$null -ne $Script:MainForm -and $Script:dialogInfo.Count -gt 0 -and $null -ne $Script:LocalizeData
} -FaildLoadLocaleData {
	param (
		[string]$Localize
	)
	[System.Windows.Forms.MessageBox]::Show("Failed to load locale data locale/$Localize`nSee $LocalizeDir/README.md for how to add custom locale.", "ps12exe GUI locale Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
}

try {
	ConvertFrom-WinFormsXML -Reference refs -Suppress -Xml $Script:MainForm

	foreach ($key in $Script:dialogInfo.Keys) {
		ConvertFrom-WinFormsXML -Xml $Script:dialoginfo[$key] | Set-Variable -Name $key -Scope Script
	}
}
catch { Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered during Form Initialization." }
