function Get-UIData {
	@{
		inputFile        = $Script:refs.CompileFileTextBox.Text
		outputFile       = $Script:refs.OutputFileTextBox.Text
		CompilerOptions  = $Script:refs.CompileParamsTextBox.Text
		TempDir          = $Script:refs.TempDirTextBox.Text
		minifyer         = $Script:refs.MinifyScriptTextBox.Text
		prepareDebug     = $Script:refs.DebugInfoCheckBox.Checked
		architecture     = if ($Script:refs.x64CheckBox.Checked) { 'x64' } elseif ($Script:refs.x86CheckBox.Checked) { 'x86' } else { 'anycpu' }
		lcid             = $Script:refs.RegionIDTextBox.Text
		threadingModel   = if ($Script:refs.SingleThreadCheckBox.Checked) { 'STA' } else { 'MTA' }
		noConsole        = -not $Script:refs.ConsoleAppCheckBox.Checked
		UNICODEEncoding  = $Script:refs.UnicodeEncodingCheckBox.Enabled -and $Script:refs.UnicodeEncodingCheckBox.Checked
		credentialGUI    = $Script:refs.CredentialGUICheckBox.Enabled -and $Script:refs.CredentialGUICheckBox.Checked
		resourceParams   = @{
			iconFile    = $Script:refs.IconFileTextBox.Text
			title       = $Script:refs.TitleTextBox.Text
			description = $Script:refs.DescriptionTextBox.Text
			company     = $Script:refs.CompanyTextBox.Text
			product     = $Script:refs.ProductNameTextBox.Text
			copyright   = $Script:refs.CopyrightInfoTextBox.Text
			trademark   = $Script:refs.TrademarkInfoTextBox.Text
			version     = $Script:refs.VersionTextBox.Text
		}
		configFile       = $Script:refs.ConfigFileCheckBox.Checked
		noOutput         = $Script:refs.DisableOutputStreamCheckBox.Checked
		noError          = $Script:refs.DisableErrorStreamCheckBox.Checked
		noVisualStyles   = $Script:refs.IgnoreVisualStylesCheckBox.Enabled -and $Script:refs.IgnoreVisualStylesCheckBox.Checked
		exitOnCancel     = $Script:refs.ExitOnCancelCheckBox.Enabled -and $Script:refs.ExitOnCancelCheckBox.Checked
		DPIAware         = $Script:refs.DPIAwareCheckBox.Enabled -and $Script:refs.DPIAwareCheckBox.Checked
		winFormsDPIAware = $Script:refs.WinFormsDPIAwareCheckBox.Enabled -and $Script:refs.WinFormsDPIAwareCheckBox.Checked
		requireAdmin     = $Script:refs.RequestAdminCheckBox.Checked
		supportOS        = $Script:refs.MoreOSFeaturesCheckBox.Checked
		virtualize       = $Script:refs.EnableVirtualizationCheckBox.Checked
		longPaths        = $Script:refs.LongPathSupportCheckBox.Checked
	}
}
function Set-UIData {
	param (
		[Parameter(Mandatory = $true)]
		[hashtable]$UIData
	)
	$Script:refs.CompileFileTextBox.Text = $UIData.inputFile
	$Script:refs.OutputFileTextBox.Text = $UIData.outputFile
	$Script:refs.CompileParamsTextBox.Text = $UIData.CompilerOptions
	$Script:refs.TempDirTextBox.Text = $UIData.TempDir
	$Script:refs.MinifyScriptTextBox.Text = $UIData.minifyer
	$Script:refs.DebugInfoCheckBox.Checked = $UIData.prepareDebug
	$Script:refs.x64CheckBox.Checked = $UIData.architecture -eq 'x64'
	$Script:refs.x86CheckBox.Checked = $UIData.architecture -eq 'x86'
	$Script:refs.AnyCPUCheckBox.Checked = $UIData.architecture -eq 'anycpu'
	$Script:refs.RegionIDTextBox.Text = $UIData.lcid
	$Script:refs.SingleThreadCheckBox.Checked = $UIData.threadingModel -eq 'STA'
	$Script:refs.MultiThreadCheckBox.Checked = $UIData.threadingModel -eq 'MTA'
	$Script:refs.ConsoleAppCheckBox.Checked = -not $UIData.noConsole
	$Script:refs.UnicodeEncodingCheckBox.Checked = $UIData.UNICODEEncoding
	$Script:refs.CredentialGUICheckBox.Checked = $UIData.credentialGUI
	$Script:refs.IconFileTextBox.Text = $UIData.resourceParams.iconFile
	$Script:refs.TitleTextBox.Text = $UIData.resourceParams.title
	$Script:refs.DescriptionTextBox.Text = $UIData.resourceParams.description
	$Script:refs.CompanyTextBox.Text = $UIData.resourceParams.company
	$Script:refs.ProductNameTextBox.Text = $UIData.resourceParams.product
	$Script:refs.CopyrightInfoTextBox.Text = $UIData.resourceParams.copyright
	$Script:refs.TrademarkInfoTextBox.Text = $UIData.resourceParams.trademark
	$Script:refs.VersionTextBox.Text = $UIData.resourceParams.version
	$Script:refs.ConfigFileCheckBox.Checked = $UIData.configFile
	$Script:refs.DisableOutputStreamCheckBox.Checked = $UIData.noOutput
	$Script:refs.DisableErrorStreamCheckBox.Checked = $UIData.noError
	$Script:refs.IgnoreVisualStylesCheckBox.Checked = $UIData.noVisualStyles
	$Script:refs.ExitOnCancelCheckBox.Checked = $UIData.exitOnCancel
	$Script:refs.DPIAwareCheckBox.Checked = $UIData.DPIAware
	$Script:refs.WinFormsDPIAwareCheckBox.Checked = $UIData.winFormsDPIAware
	$Script:refs.RequestAdminCheckBox.Checked = $UIData.requireAdmin
	$Script:refs.MoreOSFeaturesCheckBox.Checked = $UIData.supportOS
	$Script:refs.EnableVirtualizationCheckBox.Checked = $UIData.virtualize
	$Script:refs.LongPathSupportCheckBox.Checked = $UIData.longPaths
}

function Get-ps12exeArgs {
	$UIData = Get-UIData
	$result = $UIData.Clone()
	$result.minifyer = [System.Management.Automation.Language.Parser]::ParseInput($UIData.minifyer, [ref]$null, [ref]$null).GetScriptBlock()
	if ($ConfigFile) {
		# 若icon、inputFile、outputFile、TempDir为相对路径，转换为绝对路径
		@('iconFile', 'inputFile', 'outputFile', 'TempDir') | ForEach-Object {
			if ($UIData.$_ -and -not [System.IO.Path]::IsPathRooted($UIData.$_)) {
				$UIData.$_ = [System.IO.Path]::GetFullPath((Join-Path -Path $ConfigFile -ChildPath $UIData.$_))
			}
			elseif ($UIData.resourceParams.$_ -and -not [System.IO.Path]::IsPathRooted($UIData.resourceParams.$_)) {
				$UIData.resourceParams.$_ = [System.IO.Path]::GetFullPath((Join-Path -Path $ConfigFile -ChildPath $UIData.resourceParams.$_))
			}
		}
	}
	$UIData.GetEnumerator() | Where-Object { $_.Value -eq '' } | ForEach-Object { $result.Remove($_.Key) }
	$result
}
function SetCfgFile([string]$ConfigFile) {
	$Script:refs.CfgFileLabel.Text = $Script:LocalizeData.CfgFileLabelHead + $ConfigFile
	$script:ConfigFile = $ConfigFile
}
function LoadCfgFile([string]$ConfigFile) {
	if (!$ConfigFile) {
		$OpenCfgFileDialog.ShowDialog() | Out-Null
		$ConfigFile = $OpenCfgFileDialog.FileName
	}
	if ($ConfigFile) {
		SetCfgFile $ConfigFile
		$UIData = Import-Clixml $ConfigFile
		Set-UIData -UIData $UIData
	}
}
function SaveCfgFileAs([string]$ConfigFile) {
	if (!$ConfigFile) {
		$SaveCfgFileDialog.ShowDialog() | Out-Null
		$ConfigFile = $SaveCfgFileDialog.FileName
	}
	if ($ConfigFile) {
		SetCfgFile $ConfigFile
		$UIData = Get-UIData
		$UIData | Export-Clixml $ConfigFile
	}
}
function SaveCfgFile([string]$ConfigFile) {
	if (!$ConfigFile) {
		$ConfigFile = $Script:ConfigFile
	}
	SaveCfgFileAs $ConfigFile
}

function AskSaveCfg {
	[System.Windows.Forms.MessageBox]::Show([string]$Script:LocalizeData.AskSaveCfg, [string]$Script:LocalizeData.AskSaveCfgTitle, [System.Windows.Forms.MessageBoxButtons]::YesNo, [System.Windows.Forms.MessageBoxIcon]::Question) -eq 'Yes'
}

function PauseMusic {
	[ps12exeGUI.Win32]::mciSendString("pause ps12exeGUIBGM", $null, 0, 0) | Out-Null
}
function ResumeMusic {
	[ps12exeGUI.Win32]::mciSendString("resume ps12exeGUIBGM", $null, 0, 0) | Out-Null
}
