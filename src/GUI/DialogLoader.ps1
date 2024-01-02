$Script:dialogInfo = @{}

# read '$BaseDir/../locale/$Localize.fbs' file as xml
$LocalizeDir = Join-Path $(Split-Path $BaseDir) 'locale'
function LoadLocaleData {
	param (
		[string]$Localize
	)
	$Xml = [xml](Get-Content "$LocalizeDir\$Localize.fbs")
	$Script:MainForm = $Xml.Data.Form.OuterXml
	$Xml.Data.ChildNodes | Select-Object -Skip 2 | ForEach-Object {
		$Script:dialogInfo.Add($_.Name, $_.OuterXml)
	}
	$Script:LocalizeData = Import-PowerShellDataFile -Path "$LocalizeDir\$Localize.psd1"
}
function CheckLocaleData {
	$null -ne $Script:MainForm -and $Script:dialogInfo.Count -gt 0 -and $null -ne $Script:LocalizeData
}

LoadLocaleData $Localize
if(!(CheckLocaleData)) {
	[System.Windows.Forms.MessageBox]::Show("Failed to load locale data locale/$Localize`nSee $LocalizeDir/README.md for how to add custom locale.", "ps12exe GUI locale Error", [System.Windows.Forms.MessageBoxButtons]::OK, [System.Windows.Forms.MessageBoxIcon]::Warning)
	LoadLocaleData 'en-UK'
	if(!(CheckLocaleData)) { LoadLocaleData 'en-US' }
}
if(!(CheckLocaleData)) {
	$LocalizeList = Get-ChildItem $LocalizeDir | Where-Object { $_.Name -like '*.fbs' } | ForEach-Object { $_.BaseName }
	foreach ($Localize in $LocalizeList) {
		LoadLocaleData $Localize
		if(CheckLocaleData) {
			break
		}
	}
}

try {
	ConvertFrom-WinFormsXML -Reference refs -Suppress -Xml $Script:MainForm

	$OpenCfgFileDialog = ConvertFrom-WinFormsXML -Xml $Script:dialoginfo['OpenCfgFileDialog']
	$SaveCfgFileDialog = ConvertFrom-WinFormsXML -Xml $Script:dialoginfo['SaveCfgFileDialog']
	$OpenCompileFileDialog = ConvertFrom-WinFormsXML -Xml $Script:dialoginfo['OpenCompileFileDialog']
	$OpenOutputFileDialog = ConvertFrom-WinFormsXML -Xml $Script:dialoginfo['OpenOutputFileDialog']
	$OpenIconFileDialog = ConvertFrom-WinFormsXML -Xml $Script:dialoginfo['OpenIconFileDialog']
}
catch { Update-ErrorLog -ErrorRecord $_ -Message "Exception encountered during Form Initialization." }
